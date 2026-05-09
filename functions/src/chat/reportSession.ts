import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const MAX_REASON_LENGTH = 500;
const MAX_DESC_LENGTH = 2000;

export const reportSession = onCall({invoker: "public"}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const {sessionId, reportedUserId, reason, description} = request.data;

  if (!sessionId || typeof sessionId !== "string") {
    throw new HttpsError("invalid-argument", "sessionId is required.");
  }
  if (sessionId.includes("/")) {
    throw new HttpsError("invalid-argument", "Invalid sessionId.");
  }
  if (!reportedUserId || typeof reportedUserId !== "string") {
    throw new HttpsError("invalid-argument", "reportedUserId is required.");
  }
  if (!reason || typeof reason !== "string" || reason.trim() === "") {
    throw new HttpsError("invalid-argument", "reason is required.");
  }
  if (reason.trim().length > MAX_REASON_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `Reason cannot exceed ${MAX_REASON_LENGTH} characters.`
    );
  }
  if (description !== undefined && description !== null) {
    if (typeof description !== "string") {
      throw new HttpsError("invalid-argument", "description must be a string.");
    }
    if (description.length > MAX_DESC_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        `Description cannot exceed ${MAX_DESC_LENGTH} characters.`
      );
    }
  }

  const reporterId = request.auth.uid;
  if (reporterId === reportedUserId) {
    throw new HttpsError("invalid-argument", "Cannot report yourself.");
  }

  const db = admin.firestore();

  // Find the encryption key — session may be active or already ended.
  let encryptionKey: string | null = null;

  const activeSnap = await db
    .collection("active_sessions").doc(sessionId).get();
  if (activeSnap.exists) {
    const data = activeSnap.data();
    if (!data) {
      throw new HttpsError("internal", "Session data missing.");
    }
    if (!(data.users as string[]).includes(reporterId)) {
      throw new HttpsError("permission-denied", "Not a session participant.");
    }
    encryptionKey = (data.encryptionKey as string | undefined) ?? null;
  } else {
    const keySnap = await db
      .collection("session_keys").doc(sessionId).get();
    if (!keySnap.exists) {
      throw new HttpsError(
        "not-found",
        "Session not found or retention window has expired."
      );
    }
    const keyData = keySnap.data();
    if (!keyData) {
      throw new HttpsError("internal", "Session key data missing.");
    }
    if (!(keyData.users as string[]).includes(reporterId)) {
      throw new HttpsError("permission-denied", "Not a session participant.");
    }
    encryptionKey = (keyData.encryptionKey as string | undefined) ?? null;
    // Preserve the key indefinitely for the investigation.
    await db.collection("session_keys").doc(sessionId).update({
      expiresAt: null,
      flagged: true,
    });
  }

  // Mark all messages as flagged and remove their TTL — they must persist
  // for the moderation investigation.
  const msgsSnap = await db
    .collection("chat_rooms").doc(sessionId).collection("messages").get();

  if (!msgsSnap.empty) {
    const batch = db.batch();
    msgsSnap.docs.forEach((doc) => {
      batch.update(doc.ref, {flagged: true, expiresAt: null});
    });
    await batch.commit();
  }

  const reportRef = db.collection("reports").doc();
  await reportRef.set({
    reporterId,
    reportedUserId,
    sessionId,
    encryptionKey,
    reason: reason.trim(),
    description: typeof description === "string" ?
      description.trim() : null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: "pending",
  });

  logger.info("Session reported", {
    sessionId,
    reporterId,
    reportedUserId,
    reportId: reportRef.id,
  });
  return {reportId: reportRef.id};
});
