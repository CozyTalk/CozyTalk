import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {requireAdmin} from "./_utils";

/**
 * Lifts a ban and rotates the current ban record into banHistory.
 * @param {{ uid: string, note?: string }} data
 * @return {{ success: true } | { success: false, reason: string }}
 */
export const adminUnbanUser = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    const caller = await requireAdmin(request);

    const {uid, note} = request.data as {uid: unknown; note: unknown};

    if (!uid || typeof uid !== "string") {
      throw new HttpsError("invalid-argument", "uid is required.");
    }
    if (note !== undefined && note !== null && typeof note !== "string") {
      throw new HttpsError("invalid-argument", "note must be a string.");
    }
    if (typeof note === "string" && note.length > 500) {
      throw new HttpsError(
        "invalid-argument",
        "note must be ≤ 500 characters.",
      );
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      return {success: false, reason: "user_not_found"};
    }

    const userData = userSnap.data()!;
    if (userData.banned !== true) {
      return {success: false, reason: "not_banned"};
    }

    // Build a history record from the current ban fields.
    // FieldValue.serverTimestamp() cannot be nested in arrayUnion map values,
    // so use Timestamp.now() for unbannedAt (client-side is fine for audit logs).
    const historyRecord = {
      reason: userData.banReason as string,
      duration: userData.banDuration as string,
      bannedAt: userData.bannedAt as Timestamp,
      expiresAt: (userData.banExpiresAt as Timestamp | null) ?? null,
      bannedBy: userData.bannedBy as string,
      bannedByName: userData.bannedByName as string,
      note: (userData.banNote as string | null) ?? null,
      unbannedAt: Timestamp.now(),
      unbannedBy: caller.uid,
    };

    await userRef.update({
      banned: FieldValue.delete(),
      banReason: FieldValue.delete(),
      banDuration: FieldValue.delete(),
      bannedAt: FieldValue.delete(),
      banExpiresAt: FieldValue.delete(),
      bannedBy: FieldValue.delete(),
      bannedByName: FieldValue.delete(),
      banNote: FieldValue.delete(),
      banHistory: FieldValue.arrayUnion(historyRecord),
    });

    logger.info("adminUnbanUser", {uid, unbannedBy: caller.uid});
    return {success: true};
  },
);
