import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {deleteSubcollection} from "../matchmaking/_utils";

const RETENTION_MS = 3 * 24 * 60 * 60 * 1000;

export const endSession = onCall(
  {invoker: "public", cors: true},
  async (request) => {
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

    // Check rooms collection first (new matchmaking system), then fall back
    // to active_sessions (proto-session backward compat) — mirrors sendMessage.
    const roomSnap = await db.collection("rooms").doc(sessionId).get();
    const isNewStyleRoom = roomSnap.exists;
    const sessionRef = isNewStyleRoom
      ? db.collection("rooms").doc(sessionId)
      : db.collection("active_sessions").doc(sessionId);

    const sessionDoc = isNewStyleRoom
      ? roomSnap
      : await db.collection("active_sessions").doc(sessionId).get();

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
      await db
        .collection("session_keys")
        .doc(sessionId)
        .set({
          sessionId,
          encryptionKey,
          users: sessionData.users,
          createdAt: sessionData.createdAt ?? null,
          expiresAt: Timestamp.fromMillis(Date.now() + RETENTION_MS),
          flagged: false,
        });
    }

    // Remove real-time presence data and shared jukebox state.
    await Promise.all([
      rtdb.ref(`typing/${sessionId}`).remove(),
      rtdb.ref(`presence/${sessionId}`).remove(),
      rtdb.ref(`jukebox/${sessionId}`).remove(),
    ]);

    if (isNewStyleRoom) {
      // Tombstone the room so the expireRooms cleanup skips it and clients
      // can detect the session ended. Revokes participant read access via rules.
      await sessionRef.set(
        {status: "expired", expiredAt: FieldValue.serverTimestamp(), users: []},
        {merge: false},
      );
      // Also remove RTDB room membership so cleanupMember doesn't double-fire.
      await rtdb.ref(`rooms/${sessionId}`).remove();
    } else {
      // Delete active_sessions first — this revokes client read access to
      // chat_rooms via Firestore rules before we begin the message wipe.
      await db.collection("active_sessions").doc(sessionId).delete();
    }

    // Privacy by Design: destroy all chat messages now that the session key has
    // been archived and access has been revoked.
    await deleteSubcollection(
      db,
      db.collection("chat_rooms").doc(sessionId).collection("messages"),
    );

    logger.info("Session ended", {sessionId, initiatedBy: uid, isNewStyleRoom});
    return {success: true};
  },
);
