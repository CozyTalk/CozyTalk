import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {embedText} from "./embeddingService";

export const join1v1Pool = onCall(
  {invoker: "public", cors: true, memory: "512MiB"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();
    const poolRef = db.collection("waiting_pool").doc(uid);

    const data = request.data as {
      interestText?: unknown;
      backgroundTheme?: unknown;
    };
    const rawInterest =
      typeof data?.interestText === "string" ? data.interestText.trim() : null;
    const backgroundTheme =
      typeof data?.backgroundTheme === "string" && data.backgroundTheme.trim()
        ? data.backgroundTheme.trim()
        : null;

    // Embed interest text if provided; null means no interest or embedding failed.
    const interestVector = rawInterest ? await embedText(rawInterest) : null;

    // Delete any stale entry first (idempotent re-queue).
    await poolRef.delete().catch(() => null);

    await poolRef.set({
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      status: "waiting",
      mode: "1v1",
      roomId: null,
      interestText: rawInterest,
      interestVector: interestVector,
      backgroundTheme: backgroundTheme,
    });

    logger.info("User joined 1v1 pool", {
      uid,
      hasInterest: !!interestVector,
      backgroundTheme,
    });
    // Client listens to this doc for status == 'matched' to get the roomId.
    return {success: true};
  },
);
