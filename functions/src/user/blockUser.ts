import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

const MAX_BLOCKED_USERS = 5;

/**
 * Blocks a target user. Enforces a maximum of 5 blocked users per caller.
 * Writing when the target is already blocked is idempotent (updates displayName).
 * @param {{ targetUid: string, displayName?: string }} data
 * @return {{ success: true } | { success: false, reason: "max_blocked_reached" | "already_blocked" }}
 */
export const blockUser = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const callerUid = request.auth.uid;
    const {targetUid, displayName} = request.data as {
      targetUid: unknown;
      displayName?: unknown;
    };

    if (!targetUid || typeof targetUid !== "string") {
      throw new HttpsError("invalid-argument", "targetUid is required.");
    }
    if (callerUid === targetUid) {
      throw new HttpsError("invalid-argument", "Cannot block yourself.");
    }
    if (
      displayName !== undefined &&
      displayName !== null &&
      typeof displayName !== "string"
    ) {
      throw new HttpsError("invalid-argument", "displayName must be a string.");
    }

    const db = admin.firestore();
    const blockedCollRef = db
      .collection("users")
      .doc(callerUid)
      .collection("blocked");
    const targetRef = blockedCollRef.doc(targetUid);

    const [existingSnap, countSnap] = await Promise.all([
      targetRef.get(),
      blockedCollRef.get(),
    ]);

    if (existingSnap.exists) {
      // Idempotent — update displayName if provided, then confirm success.
      if (typeof displayName === "string") {
        await targetRef.update({displayName});
      }
      logger.info("blockUser: already blocked, idempotent update", {
        callerUid,
        targetUid,
      });
      return {success: true};
    }

    if (countSnap.size >= MAX_BLOCKED_USERS) {
      return {success: false, reason: "max_blocked_reached"};
    }

    await targetRef.set({
      blockedUid: targetUid,
      displayName: typeof displayName === "string" ? displayName : null,
      blockedAt: FieldValue.serverTimestamp(),
    });

    logger.info("blockUser: user blocked", {callerUid, targetUid});
    return {success: true};
  },
);
