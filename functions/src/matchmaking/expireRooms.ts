import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {deleteSubcollection} from "./_utils";

const STALE_MATCHING_SECONDS = 60;

export const expireRooms = onSchedule(
  {schedule: "*/2 * * * *", timeZone: "UTC", region: "us-central1"},
  async () => {
    const db = admin.firestore();
    const rtdb = admin.database();
    const now = Timestamp.now();

    await Promise.all([
      _expirePaddingRooms(db, rtdb, now),
      _resetStaleMatchingDocs(db, now),
      _healGhostRooms(db, rtdb),
    ]);
  },
);

/**
 * Finds rooms in the padding period whose timeout has elapsed and expires them.
 * @param {admin.firestore.Firestore} db - Firestore instance.
 * @param {admin.database.Database} rtdb - RTDB instance.
 * @param {admin.firestore.Timestamp} now - Current server timestamp.
 * @return {Promise<void>}
 */
async function _expirePaddingRooms(
  db: admin.firestore.Firestore,
  rtdb: admin.database.Database,
  now: admin.firestore.Timestamp,
): Promise<void> {
  const snap = await db
    .collection("rooms")
    .where("status", "==", "padding")
    .where("paddingUntil", "<=", now)
    .limit(50)
    .get();

  if (snap.empty) return;

  const expirations = snap.docs.map((doc) => _expireOneRoom(db, rtdb, doc.id));
  const results = await Promise.allSettled(expirations);

  results.forEach((r, i) => {
    if (r.status === "rejected") {
      logger.error("Failed to expire room", {
        roomId: snap.docs[i].id,
        reason: r.reason,
      });
    }
  });
}

/**
 * Atomically expires a single room, then cleans up subcollection and RTDB data.
 * Skips rooms that have been rejoined (memberCount > 0).
 * @param {admin.firestore.Firestore} db - Firestore instance.
 * @param {admin.database.Database} rtdb - RTDB instance.
 * @param {string} roomId - The room to expire.
 * @return {Promise<void>}
 */
async function _expireOneRoom(
  db: admin.firestore.Firestore,
  rtdb: admin.database.Database,
  roomId: string,
): Promise<void> {
  const roomRef = db.collection("rooms").doc(roomId);

  let shouldDelete = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    if (!snap.exists) return;

    const d = snap.data()!;
    if (d.status !== "padding") return;

    // If cleanupMember never fired (CF crash / emulator region mismatch), the
    // room can be stuck in padding with memberCount > 0 and no RTDB members.
    // Verify against RTDB before aborting — only skip if members are genuinely
    // still connected (someone rejoined during the padding window).
    if ((d.memberCount as number) > 0) {
      const rtdbSnap = await rtdb.ref(`rooms/${roomId}/members`).get();
      if (rtdbSnap.exists()) return; // real members present — skip
      // No RTDB members: cleanupMember was lost. Fall through and expire.
    }

    // Write the tombstone inside the transaction so the room atomically
    // transitions from padding → expired with no intermediate state.
    tx.set(
      roomRef,
      {status: "expired", expiredAt: FieldValue.serverTimestamp(), users: []},
      {merge: false},
    );
    shouldDelete = true;
  });

  if (!shouldDelete) return;

  // Clean up all associated data outside the transaction.
  await Promise.all([
    deleteSubcollection(
      db,
      db.collection("chat_rooms").doc(roomId).collection("messages"),
    ),
    rtdb.ref(`rooms/${roomId}`).remove(),
    rtdb.ref(`typing/${roomId}`).remove(),
    rtdb.ref(`presence/${roomId}`).remove(),
  ]);

  logger.info("Room expired and cleaned up", {roomId});
}

/**
 * Resets waiting_pool docs stuck in 'matching' state (trigger crash recovery).
 * @param {admin.firestore.Firestore} db - Firestore instance.
 * @param {admin.firestore.Timestamp} now - Current server timestamp.
 * @return {Promise<void>}
 */
async function _resetStaleMatchingDocs(
  db: admin.firestore.Firestore,
  now: admin.firestore.Timestamp,
): Promise<void> {
  const cutoff = Timestamp.fromMillis(
    now.toMillis() - STALE_MATCHING_SECONDS * 1000,
  );

  const snap = await db
    .collection("waiting_pool")
    .where("status", "==", "matching")
    .where("createdAt", "<=", cutoff)
    .limit(20)
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  snap.docs.forEach((doc) => batch.update(doc.ref, {status: "waiting"}));
  await batch.commit();

  logger.info("Reset stale matching docs", {count: snap.size});
}

/**
 * Reconciles Firestore room documents against RTDB membership.
 * Any active room whose Firestore memberCount > 0 but has no RTDB members is
 * a ghost room (all members disconnected without triggering cleanupMember).
 * Forces them into a short padding period so the next expireRooms run removes them.
 * @param {admin.firestore.Firestore} db - Firestore instance.
 * @param {admin.database.Database} rtdb - RTDB instance.
 * @return {Promise<void>}
 */
async function _healGhostRooms(
  db: admin.firestore.Firestore,
  rtdb: admin.database.Database,
): Promise<void> {
  const snap = await db
    .collection("rooms")
    .where("status", "==", "active")
    .limit(50)
    .get();

  if (snap.empty) return;

  const heals = snap.docs.map(async (doc) => {
    if ((doc.data().memberCount as number) <= 0) return;
    const rtdbSnap = await rtdb.ref(`rooms/${doc.id}/members`).get();
    if (rtdbSnap.exists()) return;
    const roomRef = db.collection("rooms").doc(doc.id);
    await db.runTransaction(async (tx) => {
      const current = await tx.get(roomRef);
      if (!current.exists) return;
      const d = current.data()!;
      if (d.status !== "active" || (d.memberCount as number) <= 0) return;
      tx.update(roomRef, {
        memberCount: 0,
        status: "padding",
        paddingUntil: Timestamp.fromMillis(Date.now() + 60 * 1000),
      });
    });
    logger.info("Healed ghost room", {roomId: doc.id});
  });

  await Promise.allSettled(heals);
}
