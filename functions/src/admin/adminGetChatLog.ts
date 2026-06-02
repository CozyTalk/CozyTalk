import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {requireAdmin} from "./_utils";

/**
 * Returns the decrypted chat log content for moderation.
 * Uses Admin SDK to read from Storage directly — no signed URL or IAM needed.
 * @param {{ reportId: string }} data
 * @return {{ chatLogContent: string } | { success: false, reason: string }}
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

    const bucket = admin.storage().bucket("cozytalk-5d984.firebasestorage.app");
    const file = bucket.file(chatLogStoragePath);

    let content: string;
    try {
      const [buffer] = await file.download();
      content = buffer.toString("utf8");
    } catch (e) {
      logger.warn("adminGetChatLog failed to read file", {
        reportId,
        chatLogStoragePath,
        error: String(e),
      });
      return {success: false, reason: "storage_read_failed"};
    }

    logger.info("adminGetChatLog content served", {
      reportId,
      chatLogStoragePath,
    });
    return {chatLogContent: content};
  },
);
