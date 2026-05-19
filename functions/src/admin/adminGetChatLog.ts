import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {requireAdmin} from "./_utils";

const SIGNED_URL_TTL_MS = 15 * 60 * 1000; // 15 minutes

/**
 * Returns a short-lived signed URL for the chat log stored in Cloud Storage.
 * @param {{ reportId: string }} data
 * @return {{ signedUrl: string, expiresAt: string } | { success: false, reason: string }}
 */
export const adminGetChatLog = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    await requireAdmin(request);

    const {reportId} = request.data as {reportId: unknown};
    if (!reportId || typeof reportId !== "string") {
      throw new HttpsError("invalid-argument", "reportId is required.");
    }

    const db = admin.firestore();
    const reportSnap = await db.collection("reports").doc(reportId).get();
    if (!reportSnap.exists) {
      return {success: false, reason: "not_found"};
    }

    const chatLogStoragePath = reportSnap.data()?.chatLogStoragePath as
      | string
      | null
      | undefined;
    if (!chatLogStoragePath) {
      return {success: false, reason: "no_chat_log"};
    }

    const expiresAt = new Date(Date.now() + SIGNED_URL_TTL_MS);

    // When running under the Firebase emulator, getSignedUrl() requires a real
    // service account key which is not available. Return a direct download URL
    // from the storage emulator instead.
    if (process.env.FUNCTIONS_EMULATOR && process.env.STORAGE_EMULATOR_HOST) {
      const bucket = admin.storage().bucket();
      const emulatorUrl = `http://${process.env.STORAGE_EMULATOR_HOST}/v0/b/${bucket.name}/o/${encodeURIComponent(chatLogStoragePath)}?alt=media`;
      return {signedUrl: emulatorUrl, expiresAt: expiresAt.toISOString()};
    }

    const bucket = admin.storage().bucket();
    const file = bucket.file(chatLogStoragePath);
    const [signedUrl] = await file.getSignedUrl({
      action: "read",
      expires: expiresAt,
    });

    logger.info("adminGetChatLog signed URL issued", {
      reportId,
      chatLogStoragePath,
    });
    return {signedUrl, expiresAt: expiresAt.toISOString()};
  },
);
