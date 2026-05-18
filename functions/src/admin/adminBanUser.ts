import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {requireAdmin, isValidDuration, DURATION_MS} from "./_utils";

/**
 * Bans a user and optionally resolves a linked report atomically.
 * @param {{ uid: string, reason: string, duration: BanDuration, note?: string, reportId?: string }} data
 * @return {{ success: true } | { success: false, reason: string }}
 */
export const adminBanUser = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    const caller = await requireAdmin(request);

    const {uid, reason, duration, note, reportId} = request.data as {
      uid: unknown;
      reason: unknown;
      duration: unknown;
      note: unknown;
      reportId: unknown;
    };

    if (!uid || typeof uid !== "string") {
      throw new HttpsError("invalid-argument", "uid is required.");
    }
    if (!reason || typeof reason !== "string" || !reason.trim()) {
      throw new HttpsError("invalid-argument", "reason is required.");
    }
    if (!isValidDuration(duration)) {
      throw new HttpsError(
        "invalid-argument",
        "duration must be '1 Day', '7 Days', '30 Days', or 'Permanent'.",
      );
    }
    if (note !== undefined && note !== null && typeof note !== "string") {
      throw new HttpsError("invalid-argument", "note must be a string.");
    }
    if (typeof note === "string" && note.length > 500) {
      throw new HttpsError("invalid-argument", "note must be ≤ 500 characters.");
    }
    if (reportId !== undefined && reportId !== null && typeof reportId !== "string") {
      throw new HttpsError("invalid-argument", "reportId must be a string.");
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      return {success: false, reason: "user_not_found"};
    }
    if (userSnap.data()?.banned === true) {
      return {success: false, reason: "already_banned"};
    }

    const durationMs = DURATION_MS[duration];
    const banExpiresAt =
      durationMs !== null
        ? Timestamp.fromMillis(Date.now() + durationMs)
        : null;

    const batch = db.batch();

    batch.update(userRef, {
      banned: true,
      banReason: reason.trim(),
      banDuration: duration,
      bannedAt: FieldValue.serverTimestamp(),
      banExpiresAt,
      bannedBy: caller.uid,
      bannedByName: caller.displayName,
      banNote: typeof note === "string" ? note.trim() : null,
    });

    if (reportId && typeof reportId === "string") {
      const reportRef = db.collection("reports").doc(reportId);
      batch.update(reportRef, {
        status: "reviewed",
        outcome: {
          kind: "banned",
          by: caller.uid,
          byName: caller.displayName,
          at: FieldValue.serverTimestamp(),
          note: typeof note === "string" ? note.trim() : null,
        },
      });
    }

    await batch.commit();

    logger.info("adminBanUser", {
      uid,
      duration,
      bannedBy: caller.uid,
      reportId: reportId ?? null,
    });
    return {success: true};
  },
);
