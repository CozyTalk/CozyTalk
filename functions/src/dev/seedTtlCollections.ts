/**
 * ONE-TIME SETUP FUNCTION — remove this export after running once.
 *
 * Purpose: write placeholder documents into chat_rooms and session_keys so
 * the expiresAt field is visible in the Firebase console when configuring
 * the Firestore TTL policy.
 *
 * Trigger: GET https://<region>-<project>.cloudfunctions.net/seedTtlCollections
 *
 * After running:
 *  1. Firebase console → Firestore → Data
 *  2. chat_rooms/_ttl_setup_/messages → TTL policy → field: expiresAt
 *  3. session_keys → TTL policy → field: expiresAt
 *  4. Remove this export from index.ts and redeploy.
 */

import {onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

export const seedTtlCollections = onRequest(async (_req, res) => {
  const db = admin.firestore();

  // 7-day window — long enough to configure the TTL policy before
  // Firestore auto-deletes these placeholder documents.
  const expiresAt = Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000);

  const chatRoomRef = db
    .collection("chat_rooms")
    .doc("_ttl_setup_")
    .collection("messages")
    .doc("_placeholder_");

  const sessionKeyRef = db.collection("session_keys").doc("_ttl_setup_");

  await Promise.all([
    chatRoomRef.set({
      senderId: "_setup_",
      displayName: "Setup",
      encryptedText: "",
      iv: "",
      authTag: "",
      timestamp: FieldValue.serverTimestamp(),
      expiresAt,
      flagged: false,
    }),
    sessionKeyRef.set({
      sessionId: "_ttl_setup_",
      encryptionKey: "",
      users: [],
      createdAt: FieldValue.serverTimestamp(),
      expiresAt,
      flagged: false,
    }),
  ]);

  const paths = [
    "chat_rooms/_ttl_setup_/messages/_placeholder_",
    "session_keys/_ttl_setup_",
  ];

  logger.info("TTL seed documents written", {paths});

  const msg =
    "Placeholder documents written. Configure TTL policy " +
    "in the Firebase console, then remove this function.";

  res.json({
    success: true,
    message: msg,
    documents: paths,
    ttlField: "expiresAt",
  });
});
