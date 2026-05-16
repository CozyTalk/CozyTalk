import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

export const cancel1v1Pool = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();
    const poolRef = db.collection("waiting_pool").doc(uid);

    const snap = await poolRef.get();
    if (!snap.exists) {
      return {success: true};
    }

    // If the matching trigger already claimed this user, do not cancel —
    // the match is in progress and will complete shortly.
    if (snap.data()?.status === "matching") {
      return {success: false, reason: "matching_in_progress"};
    }

    await poolRef.delete();
    logger.info("User cancelled 1v1 pool", {uid});
    return {success: true};
  },
);
