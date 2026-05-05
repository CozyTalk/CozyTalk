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

  // Delete real-time data — clients lose live visibility immediately.
  await Promise.all([
    rtdb.ref(`typing/${sessionId}`).remove(),
    rtdb.ref(`presence/${sessionId}`).remove(),
  ]);

  // Deleting active_sessions revokes participant access to the key and to
  // chat_rooms messages (Firestore rules gate on active_sessions existence).
  await db.collection("active_sessions").doc(sessionId).delete();

  logger.info("Session ended", {sessionId, initiatedBy: uid});
  return {success: true};
});
