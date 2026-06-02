import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";
import type {CallableRequest} from "firebase-functions/v2/https";

export interface AdminCaller {
  uid: string;
  displayName: string;
}

const VALID_DURATIONS = ["1 Day", "7 Days", "30 Days", "Permanent"] as const;
export type BanDuration = (typeof VALID_DURATIONS)[number];

export const DURATION_MS: Record<BanDuration, number | null> = {
  "1 Day": 1 * 24 * 60 * 60 * 1000,
  "7 Days": 7 * 24 * 60 * 60 * 1000,
  "30 Days": 30 * 24 * 60 * 60 * 1000,
  Permanent: null,
};

/**
 * Verifies the caller is an authenticated admin.
 * Throws HttpsError("unauthenticated") if not signed in.
 * Throws HttpsError("permission-denied") if role != "admin".
 * @param {CallableRequest} request - Incoming callable request.
 * @return {Promise<AdminCaller>} Verified admin uid and displayName.
 */
export async function requireAdmin(
  request: CallableRequest,
): Promise<AdminCaller> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const {uid} = request.auth;
  const email = (request.auth.token.email as string | undefined) ?? "";
  const snap = await admin.firestore().collection("users").doc(uid).get();
  const isCozytalkEmail = email.toLowerCase().endsWith("@cozytalk.com");
  const hasAdminRole = snap.exists && snap.data()?.role === "admin";
  if (!isCozytalkEmail && !hasAdminRole) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }
  const displayName =
    (snap.data()?.displayName as string | undefined) ?? "Admin";
  return {uid, displayName};
}

/**
 * Returns true when the value is a valid BanDuration string.
 * @param {unknown} val - Value to check.
 * @return {boolean}
 */
export function isValidDuration(val: unknown): val is BanDuration {
  return VALID_DURATIONS.includes(val as BanDuration);
}
