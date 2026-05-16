import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {createRoomWithRetry, generateKey} from "./_utils";

export const joinGroupRoom = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();
    const rtdb = admin.database();

    // Remove any stale waiting_pool entry to keep the pool clean.
    await db
      .collection("waiting_pool")
      .doc(uid)
      .delete()
      .catch(() => null);

    /**
     * Shuffles candidates and attempts to join each one atomically.
     * Returns the joined roomId on success, or null if all candidates fail.
     * @param {FirebaseFirestore.QueryDocumentSnapshot[]} docs - Candidate room docs.
     * @return {Promise<string | null>} The joined roomId, or null.
     */
    async function _tryJoinCandidates(
      docs: FirebaseFirestore.QueryDocumentSnapshot[],
    ): Promise<string | null> {
      const shuffled = [...docs].sort(() => Math.random() - 0.5);
      for (const doc of shuffled) {
        // Ground-truth check: RTDB is the source of live membership.
        // If RTDB has no members for this room, Firestore count has drifted —
        // it's a ghost room. Skip it rather than routing a real user there.
        const rtdbMembersSnap = await rtdb.ref(`rooms/${doc.id}/members`).get();
        if (!rtdbMembersSnap.exists()) {
          logger.debug("Skipping ghost room (no RTDB members)", {
            roomId: doc.id,
          });
          continue;
        }

        const roomRef = db.collection("rooms").doc(doc.id);
        let joined = false;

        try {
          await db.runTransaction(async (tx) => {
            const roomSnap = await tx.get(roomRef);
            if (!roomSnap.exists) return;

            const data = roomSnap.data()!;
            if (
              data.status === "expired" ||
              data.status === "padding" ||
              data.isLocked ||
              data.memberCount >= data.maxUsers ||
              (data.users as string[]).includes(uid)
            ) {
              return;
            }

            tx.update(roomRef, {
              users: FieldValue.arrayUnion(uid),
              memberCount: FieldValue.increment(1),
              status: "active",
              paddingUntil: null,
            });
            joined = true;
          });
        } catch (err) {
          logger.warn(
            "Transaction failed joining room, trying next candidate",
            {
              roomId: doc.id,
              err,
            },
          );
          continue;
        }

        if (joined) {
          await rtdb.ref(`rooms/${doc.id}/members/${uid}`).set(true);
          logger.info("User joined existing group room", {uid, roomId: doc.id});
          return doc.id;
        }
      }
      return null;
    }

    // Phase 1 — Priority: join a room with exactly 1 member so that lone users
    // find a partner as quickly as possible. Multiple candidates are shuffled for
    // random selection among equal-priority rooms.
    const prioritySnap = await db
      .collection("rooms")
      .where("mode", "==", "group")
      .where("status", "==", "active")
      .where("isLocked", "==", false)
      .where("memberCount", "==", 1)
      .limit(10)
      .get();

    const priorityRoomId = await _tryJoinCandidates(prioritySnap.docs);
    if (priorityRoomId) {
      return {roomId: priorityRoomId, isNewRoom: false};
    }

    // Phase 2 — Random: no lone-user rooms found; join any available room with
    // 2–4 members, chosen at random so users don't predictably rejoin the same room.
    const otherSnap = await db
      .collection("rooms")
      .where("mode", "==", "group")
      .where("status", "==", "active")
      .where("isLocked", "==", false)
      .where("memberCount", ">", 1)
      .where("memberCount", "<", 5)
      .limit(10)
      .get();

    const otherRoomId = await _tryJoinCandidates(otherSnap.docs);
    if (otherRoomId) {
      return {roomId: otherRoomId, isNewRoom: false};
    }

    // No available room found — create one and become the first member.
    const roomId = await createRoomWithRetry(db, {
      roomType: "public",
      mode: "group",
      status: "active",
      maxUsers: 5,
      memberCount: 1,
      users: [uid],
      isLocked: false,
      createdAt: FieldValue.serverTimestamp(),
      paddingUntil: null,
      encryptionKey: generateKey(),
    });

    await rtdb.ref(`rooms/${roomId}/members/${uid}`).set(true);
    logger.info("Created new group room", {uid, roomId});

    // Race-condition mitigation: if another user created a 1-member room at the
    // same time (both saw an empty DB), merge into theirs and discard ours.
    const soloRooms = await db
      .collection("rooms")
      .where("mode", "==", "group")
      .where("status", "==", "active")
      .where("isLocked", "==", false)
      .where("memberCount", "==", 1)
      .limit(5)
      .get();

    const mergeTarget = soloRooms.docs.find((d) => d.id !== roomId);
    if (mergeTarget) {
      const targetRef = db.collection("rooms").doc(mergeTarget.id);
      const myRoomRef = db.collection("rooms").doc(roomId);
      let merged = false;

      try {
        await db.runTransaction(async (tx) => {
          const [targetSnap, mySnap] = await Promise.all([
            tx.get(targetRef),
            tx.get(myRoomRef),
          ]);
          if (!targetSnap.exists || !mySnap.exists) return;
          const td = targetSnap.data()!;
          if (
            td.status === "expired" ||
            td.isLocked ||
            (td.memberCount as number) >= (td.maxUsers as number) ||
            (td.users as string[]).includes(uid)
          ) {
            return;
          }
          tx.update(targetRef, {
            users: FieldValue.arrayUnion(uid),
            memberCount: FieldValue.increment(1),
          });
          tx.delete(myRoomRef);
          merged = true;
        });
      } catch (err) {
        logger.warn("Group room merge failed, staying in created room", {
          roomId,
          err,
        });
      }

      if (merged) {
        await Promise.all([
          rtdb.ref(`rooms/${roomId}/members/${uid}`).remove(),
          rtdb.ref(`rooms/${mergeTarget.id}/members/${uid}`).set(true),
        ]);
        logger.info("Merged into existing group room after creation", {
          uid,
          roomId: mergeTarget.id,
          abandonedRoomId: roomId,
        });
        return {roomId: mergeTarget.id, isNewRoom: false};
      }
    }

    return {roomId, isNewRoom: true};
  },
);
