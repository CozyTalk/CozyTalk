import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const RETENTION_MS = 3 * 24 * 60 * 60 * 1000;

export const endSession = onCall({invoker: "public"}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const {sessionId} = request.data;
  if (!sessionId || typeof sessionId !== "string") {
    throw new HttpsError("invalid-argument", "sessionId is required.");
  }
  if (sessionId.includes("/")) {
    throw new HttpsError("invalid-argument", "Invalid sessionId.");
  }

  const uid = request.auth.uid;
  const db = admin.firestore();
  const rtdb = admin.database();

  const sessionDoc = await db
    .collection("active_sessions").doc(sessionId).get();
  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Session not found.");
  }

  const sessionData = sessionDoc.data();
  if (!sessionData) {
    throw new HttpsError("internal", "Session data missing.");
  }
  if (!(sessionData.users as string[]).includes(uid)) {
    throw new HttpsError("permission-denied", "Not a session participant.");
  }

  // Archive the encryption key with a 3-day TTL so moderators can decrypt
  // flagged messages within the retention window.
  const encryptionKey = sessionData.encryptionKey as string | undefined;
  if (encryptionKey) {
    await db.collection("session_keys").doc(sessionId).set({
      sessionId,
      encryptionKey,
      users: sessionData.users,
      createdAt: sessionData.createdAt ?? null,
      expiresAt: admin.firestore.Timestamp.fromMillis(
        Date.now() + RETENTION_MS
      ),
      flagged: false,
    });
  }

  // Remove real-time presence data — clients lose live visibility immediately.
  await Promise.all([
    rtdb.ref(`typing/${sessionId}`).remove(),
    rtdb.ref(`presence/${sessionId}`).remove(),
  ]);

  // Delete active_sessions first — this revokes client read access to
  // chat_rooms via Firestore rules before we begin the message wipe.
  await db.collection("active_sessions").doc(sessionId).delete();

  // Privacy by Design: destroy all chat messages now that the session key has
  // been archived and access has been revoked.
  await _deleteMessages(db, sessionId);

  logger.info("Session ended", {sessionId, initiatedBy: uid});
  return {success: true};
});

/**
 * Recursively deletes all messages in a chat room in batches.
 * @param {admin.firestore.Firestore} db - Firestore instance.
 * @param {string} sessionId - The room whose messages to delete.
 * @param {number} batchSize - Documents to delete per batch.
 * @return {Promise<void>}
 */
async function _deleteMessages(
  db: admin.firestore.Firestore,
  sessionId: string,
  batchSize = 100,
): Promise<void> {
  const snap = await db
    .collection("chat_rooms")
    .doc(sessionId)
    .collection("messages")
    .limit(batchSize)
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();

  if (snap.size >= batchSize) await _deleteMessages(db, sessionId, batchSize);
}
