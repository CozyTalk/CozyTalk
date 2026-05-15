import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

export const join1v1Pool = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();
    const poolRef = db.collection("waiting_pool").doc(uid);

    // Delete any stale entry first (idempotent re-queue).
    await poolRef.delete().catch(() => null);

    await poolRef.set({
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      status: "waiting",
      mode: "1v1",
      roomId: null,
    });

    logger.info("User joined 1v1 pool", {uid});
    // Client listens to this doc for status == 'matched' to get the roomId.
    return {success: true};
  },
);
