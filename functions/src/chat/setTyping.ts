import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

export const setTyping = onCall({invoker: "public"}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const {sessionId, isTyping} = request.data;
  if (!sessionId || typeof sessionId !== "string") {
    throw new HttpsError("invalid-argument", "sessionId is required.");
  }
  if (sessionId.includes("/")) {
    throw new HttpsError("invalid-argument", "Invalid sessionId.");
  }
  if (typeof isTyping !== "boolean") {
    throw new HttpsError("invalid-argument", "isTyping must be a boolean.");
  }

  const uid = request.auth.uid;

  const sessionDoc = await admin
    .firestore()
    .collection("active_sessions")
    .doc(sessionId)
    .get();

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

  await admin.database().ref(`typing/${sessionId}/${uid}`).set({isTyping});
  return {success: true};
});
