import * as crypto from "crypto";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const RETENTION_MS = 3 * 24 * 60 * 60 * 1000;
const MAX_TEXT_LENGTH = 2000;

/**
 * Generates a random 256-bit AES key.
 * @return {string} Hex-encoded 256-bit key.
 */
function generateKey(): string {
  return crypto.randomBytes(32).toString("hex");
}

/**
 * Encrypts plain text with AES-256-GCM.
 * @param {string} text - Plain text to encrypt.
 * @param {string} keyHex - Hex-encoded 256-bit AES key.
 * @return {object} Base64-encoded ciphertext, IV, and auth tag.
 */
function encryptText(
  text: string,
  keyHex: string
): {encryptedText: string; iv: string; authTag: string} {
  const key = Buffer.from(keyHex, "hex");
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([
    cipher.update(text, "utf8"), cipher.final(),
  ]);
  return {
    encryptedText: encrypted.toString("base64"),
    iv: iv.toString("base64"),
    authTag: cipher.getAuthTag().toString("base64"),
  };
}

export const sendMessage = onCall({invoker: "public"}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const {sessionId, text} = request.data;
  if (!sessionId || typeof sessionId !== "string") {
    throw new HttpsError("invalid-argument", "sessionId is required.");
  }
  if (sessionId.includes("/")) {
    throw new HttpsError("invalid-argument", "Invalid sessionId.");
  }
  if (!text || typeof text !== "string" || text.trim() === "") {
    throw new HttpsError(
      "invalid-argument",
      "text must be a non-empty string."
    );
  }
  if (text.trim().length > MAX_TEXT_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `Message cannot exceed ${MAX_TEXT_LENGTH} characters.`
    );
  }

  const uid = request.auth.uid;
  const db = admin.firestore();
  const sessionRef = db.collection("active_sessions").doc(sessionId);

  // Ensure session key exists atomically — first message generates it.
  let encryptionKey = "";
  await db.runTransaction(async (tx) => {
    const doc = await tx.get(sessionRef);
    if (!doc.exists) {
      throw new HttpsError("not-found", "Session not found.");
    }
    const data = doc.data();
    if (!data) {
      throw new HttpsError("internal", "Session data missing.");
    }
    if (!(data.users as string[]).includes(uid)) {
      throw new HttpsError("permission-denied", "Not a participant.");
    }
    if (data.encryptionKey) {
      encryptionKey = data.encryptionKey as string;
    } else {
      encryptionKey = generateKey();
      tx.update(sessionRef, {encryptionKey});
    }
  });

  // Resolve display name server-side — never trust client-supplied name.
  const userSnap = await db.collection("users").doc(uid).get();
  let displayName = "Anonymous";
  if (userSnap.exists) {
    const d = userSnap.data()?.displayName as string | null;
    displayName = d ?? "Anonymous";
  }

  const {encryptedText, iv, authTag} = encryptText(
    text.trim(), encryptionKey
  );
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    Date.now() + RETENTION_MS
  );

  const msgRef = db
    .collection("chat_rooms")
    .doc(sessionId)
    .collection("messages")
    .doc();

  await msgRef.set({
    senderId: uid,
    displayName,
    encryptedText,
    iv,
    authTag,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt,
    flagged: false,
  });

  logger.info("Message sent", {
    sessionId, senderId: uid, messageId: msgRef.id,
  });
  return {messageId: msgRef.id};
});
