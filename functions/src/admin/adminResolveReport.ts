import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {requireAdmin} from "./_utils";

const VALID_ACTIONS = ["dismiss", "reviewed"] as const;
type ResolveAction = (typeof VALID_ACTIONS)[number];

/**
 * Marks a report as dismissed or reviewed without banning the user.
 * @param {{ reportId: string, action: "dismiss" | "reviewed", note?: string }} data
 * @return {{ success: true } | { success: false, reason: string }}
 */
export const adminResolveReport = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    const caller = await requireAdmin(request);

    const {reportId, action, note} = request.data as {
      reportId: unknown;
      action: unknown;
      note: unknown;
    };

    if (!reportId || typeof reportId !== "string") {
      throw new HttpsError("invalid-argument", "reportId is required.");
    }
    if (!VALID_ACTIONS.includes(action as ResolveAction)) {
      throw new HttpsError(
        "invalid-argument",
        "action must be 'dismiss' or 'reviewed'.",
      );
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
    const reportRef = db.collection("reports").doc(reportId);
    const reportSnap = await reportRef.get();

    if (!reportSnap.exists) {
      return {success: false, reason: "not_found"};
    }

    const reportData = reportSnap.data()!;
    if (reportData.status !== "pending") {
      return {success: false, reason: "already_resolved"};
    }

    const newStatus = action === "dismiss" ? "dismissed" : "reviewed";
    const outcomeKind = action === "dismiss" ? "dismissed" : "reviewed";

    await reportRef.update({
      status: newStatus,
      outcome: {
        kind: outcomeKind,
        by: caller.uid,
        byName: caller.displayName,
        at: FieldValue.serverTimestamp(),
        note: typeof note === "string" ? note.trim() : null,
      },
    });

    logger.info("adminResolveReport", {
      reportId,
      action,
      resolvedBy: caller.uid,
    });
    return {success: true};
  },
);
