import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {createDecipheriv, createHash} from "crypto";
import * as logger from "firebase-functions/logger";

const MAX_REASON_LENGTH = 500;
const MAX_CONTEXT_LENGTH = 2000;
const MAX_IMAGES = 5;
const VALID_REPORT_TYPES = [
  "spam",
  "harassment",
  "inappropriate_content",
  "other",
] as const;
type ReportType = (typeof VALID_REPORT_TYPES)[number];

/**
 * Decrypts an AES-256-GCM ciphertext using base64-encoded components.
 * @param encryptedText base64-encoded ciphertext
 * @param iv base64-encoded 12-byte IV
 * @param authTag base64-encoded 16-byte auth tag
 * @param key hex-encoded 32-byte AES-256 key
 * @return decrypted UTF-8 plaintext, or null if decryption fails
 */
function _decryptMessage(
  encryptedText: string,
  iv: string,
  authTag: string,
  key: string,
): string | null {
  try {
    const decipher = createDecipheriv(
      "aes-256-gcm",
      Buffer.from(key, "hex"),
      Buffer.from(iv, "base64"),
    );
    decipher.setAuthTag(Buffer.from(authTag, "base64"));
    const decrypted = Buffer.concat([
      decipher.update(Buffer.from(encryptedText, "base64")),
      decipher.final(),
    ]);
    return decrypted.toString("utf8");
  } catch {
    return null;
  }
}

/**
 * Derives a proto-session AES-256 key from the sessionId via SHA-256,
 * matching the derivation in ChatDatasourceImpl.fetchSessionKey().
 * @param sessionId the proto-session document ID
 * @return hex-encoded 32-byte derived key
 */
function _deriveProtoKey(sessionId: string): string {
  return createHash("sha256").update(sessionId).digest("hex");
}

export const reportSession = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const {
      sessionId,
      reportedUserId,
      reportType,
      reason,
      contextText,
      contextImageUrls,
    } = request.data;

    if (!sessionId || typeof sessionId !== "string") {
      throw new HttpsError("invalid-argument", "sessionId is required.");
    }
    if (sessionId.includes("/")) {
      throw new HttpsError("invalid-argument", "Invalid sessionId.");
    }
    if (!reportedUserId || typeof reportedUserId !== "string") {
      throw new HttpsError("invalid-argument", "reportedUserId is required.");
    }
    if (!reportType || !VALID_REPORT_TYPES.includes(reportType as ReportType)) {
      throw new HttpsError(
        "invalid-argument",
        `reportType must be one of: ${VALID_REPORT_TYPES.join(", ")}.`,
      );
    }
    if (!reason || typeof reason !== "string" || reason.trim() === "") {
      throw new HttpsError("invalid-argument", "reason is required.");
    }
    if (reason.trim().length > MAX_REASON_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        `Reason cannot exceed ${MAX_REASON_LENGTH} characters.`,
      );
    }
    if (contextText !== undefined && contextText !== null) {
      if (typeof contextText !== "string") {
        throw new HttpsError(
          "invalid-argument",
          "contextText must be a string.",
        );
      }
      if (contextText.length > MAX_CONTEXT_LENGTH) {
        throw new HttpsError(
          "invalid-argument",
          `Context text cannot exceed ${MAX_CONTEXT_LENGTH} characters.`,
        );
      }
    }
    if (contextImageUrls !== undefined && contextImageUrls !== null) {
      if (!Array.isArray(contextImageUrls)) {
        throw new HttpsError(
          "invalid-argument",
          "contextImageUrls must be an array.",
        );
      }
      if (contextImageUrls.length > MAX_IMAGES) {
        throw new HttpsError(
          "invalid-argument",
          `Cannot attach more than ${MAX_IMAGES} images.`,
        );
      }
      const STORAGE_BASE = "https://firebasestorage.googleapis.com/";
      for (const url of contextImageUrls) {
        if (typeof url !== "string" || !url.startsWith(STORAGE_BASE)) {
          throw new HttpsError(
            "invalid-argument",
            "Each image URL must be a Firebase Storage URL.",
          );
        }
      }
    }

    const reporterId = request.auth.uid;
    if (reporterId === reportedUserId) {
      throw new HttpsError("invalid-argument", "Cannot report yourself.");
    }

    const db = admin.firestore();
    let encryptionKey: string | null = null;

    const roomSnap = await db.collection("rooms").doc(sessionId).get();
    if (roomSnap.exists) {
      const data = roomSnap.data()!;
      const users = data.users as string[];
      if (!users.includes(reporterId)) {
        throw new HttpsError("permission-denied", "Not a session participant.");
      }
      if (!users.includes(reportedUserId)) {
        throw new HttpsError(
          "invalid-argument",
          "Reported user is not a participant in this session.",
        );
      }
      encryptionKey = (data.encryptionKey as string | undefined) ?? null;
      if (encryptionKey) {
        await db
          .collection("session_keys")
          .doc(sessionId)
          .set(
            {
              sessionId,
              encryptionKey,
              users: data.users,
              createdAt: data.createdAt ?? null,
              expiresAt: null,
              flagged: true,
            },
            {merge: true},
          );
      }
    } else {
      const activeSnap = await db
        .collection("active_sessions")
        .doc(sessionId)
        .get();
      if (activeSnap.exists) {
        const data = activeSnap.data()!;
        const users = data.users as string[];
        if (!users.includes(reporterId)) {
          throw new HttpsError(
            "permission-denied",
            "Not a session participant.",
          );
        }
        if (!users.includes(reportedUserId)) {
          throw new HttpsError(
            "invalid-argument",
            "Reported user is not a participant in this session.",
          );
        }
        encryptionKey = (data.encryptionKey as string | undefined) ?? null;
        // Proto-sessions store no key in Firestore; derive it from the session ID.
        if (!encryptionKey) {
          encryptionKey = _deriveProtoKey(sessionId);
        }
      } else {
        const keySnap = await db
          .collection("session_keys")
          .doc(sessionId)
          .get();
        if (!keySnap.exists) {
          throw new HttpsError(
            "not-found",
            "Session not found or retention window has expired.",
          );
        }
        const keyData = keySnap.data()!;
        const users = keyData.users as string[];
        if (!users.includes(reporterId)) {
          throw new HttpsError(
            "permission-denied",
            "Not a session participant.",
          );
        }
        if (!users.includes(reportedUserId)) {
          throw new HttpsError(
            "invalid-argument",
            "Reported user is not a participant in this session.",
          );
        }
        encryptionKey = (keyData.encryptionKey as string | undefined) ?? null;
        await db.collection("session_keys").doc(sessionId).update({
          expiresAt: null,
          flagged: true,
        });
      }
    }

    // Fetch all messages, decrypt them, and flag each for indefinite retention.
    const msgsSnap = await db
      .collection("chat_rooms")
      .doc(sessionId)
      .collection("messages")
      .get();

    type ChatEntry = {
      id: string;
      senderId: string;
      displayName: string;
      text: string | null;
      timestamp: string | null;
    };
    const chatEntries: ChatEntry[] = [];

    if (!msgsSnap.empty) {
      const batch = db.batch();
      for (const doc of msgsSnap.docs) {
        batch.update(doc.ref, {flagged: true, expiresAt: null});
        const d = doc.data();
        const text =
          encryptionKey && d.encryptedText && d.iv && d.authTag
            ? _decryptMessage(
                d.encryptedText as string,
                d.iv as string,
                d.authTag as string,
                encryptionKey,
              )
            : null;
        chatEntries.push({
          id: doc.id,
          senderId: d.senderId as string,
          displayName: d.displayName as string,
          text,
          timestamp: d.timestamp?.toDate?.()?.toISOString() ?? null,
        });
      }
      chatEntries.sort((a, b) =>
        (a.timestamp ?? "").localeCompare(b.timestamp ?? ""),
      );
      await batch.commit();
    }

    const reportRef = db.collection("reports").doc();
    const reportId = reportRef.id;

    // Save decrypted chat log to Cloud Storage for moderator access.
    // Failures are non-fatal — the report is still created.
    let chatLogStoragePath: string | null = null;
    try {
      const storagePath = `reports/${reportId}/chat_log.json`;
      await getStorage()
        .bucket()
        .file(storagePath)
        .save(
          JSON.stringify(
            {
              reportId,
              sessionId,
              exportedAt: new Date().toISOString(),
              messages: chatEntries,
            },
            null,
            2,
          ),
          {contentType: "application/json"},
        );
      chatLogStoragePath = storagePath;
    } catch (e) {
      logger.warn("Failed to save chat log to Cloud Storage", {
        error: String(e),
        sessionId,
      });
    }

    await reportRef.set({
      reporterId,
      reportedUserId,
      sessionId,
      reportType,
      reason: reason.trim(),
      contextText: typeof contextText === "string" ? contextText.trim() : null,
      contextImageUrls: Array.isArray(contextImageUrls) ? contextImageUrls : [],
      chatLogStoragePath,
      createdAt: FieldValue.serverTimestamp(),
      status: "pending",
    });

    logger.info("Session reported", {
      sessionId,
      reporterId,
      reportedUserId,
      reportId,
    });
    return {reportId};
  },
);
