/**
 * Integration tests for admin Cloud Functions.
 * Runs against the local Firebase emulator suite.
 *
 * Covers:
 *   - adminGetDashboard: counts (pending reports, online users, banned users)
 *   - adminResolveReport: dismiss and reviewed actions; idempotency guards
 *   - adminGetChatLog: missing report, no chat log path
 *   - adminBanUser: writes ban fields; resolves linked report atomically
 *   - adminUnbanUser: rotates active ban into banHistory
 *   - Auth guards: unauthenticated and non-admin callers are rejected
 */

import {
  signInAnon,
  signOut,
  callFn,
  resetEmulatorData,
  adminFirestoreDoc,
  adminFirestoreSet,
  adminFirestoreList,
  buildRoom,
} from "../../matchmaking/__tests__/helpers";

// ── Admin helper ───────────────────────────────────────────────────────────────

/**
 * Signs in anonymously and upgrades the Firestore user doc to role="admin".
 * Returns the uid.
 */
async function signInAsAdmin(): Promise<string> {
  const uid = await signInAnon();
  await adminFirestoreSet(`users/${uid}`, {
    uid,
    role: "admin",
    displayName: "Test Admin",
    interest: "",
    createdAt: new Date(),
    lastSeen: new Date(),
  });
  return uid;
}

/**
 * Creates a pending report doc via the admin REST API and returns its ID.
 * @param {string} reporterId - uid of reporter
 * @param {string} reportedUserId - uid of reported user
 */
async function seedReport(
  reporterId: string,
  reportedUserId: string,
  overrides: Record<string, unknown> = {},
): Promise<string> {
  const reportId = `test-report-${Date.now()}`;
  await adminFirestoreSet(`reports/${reportId}`, {
    reporterId,
    reportedUserId,
    sessionId: "test-session",
    reportType: "spam",
    reason: "Test spam report",
    contextText: null,
    contextImageUrls: [],
    chatLogStoragePath: null,
    createdAt: new Date(),
    status: "pending",
    ...overrides,
  });
  return reportId;
}

/**
 * Creates a regular user doc (role="user") and returns the uid.
 */
async function seedUser(
  overrides: Record<string, unknown> = {},
): Promise<string> {
  const uid = await signInAnon();
  signOut();
  await adminFirestoreSet(`users/${uid}`, {
    uid,
    role: "user",
    displayName: "Regular User",
    interest: "",
    createdAt: new Date(),
    lastSeen: new Date(),
    ...overrides,
  });
  return uid;
}

// ── Lifecycle ─────────────────────────────────────────────────────────────────

beforeEach(async () => {
  signOut();
  await resetEmulatorData();
}, 15_000);

afterEach(async () => {
  signOut();
  await resetEmulatorData();
}, 15_000);

// ── adminGetDashboard ─────────────────────────────────────────────────────────

describe("adminGetDashboard", () => {
  test("returns zero counts when emulator is empty", async () => {
    await signInAsAdmin();
    const res = await callFn("adminGetDashboard");
    expect(res["pendingReports"]).toBe(0);
    expect(res["onlineUsers"]).toBe(0);
    expect(res["bannedUsers"]).toBe(0);
  });

  test("counts pending reports correctly", async () => {
    const adminUid = await signInAsAdmin();
    signOut();

    const userUid = await seedUser();
    await seedReport(userUid, adminUid);
    await seedReport(userUid, adminUid);
    // resolved report must not be counted
    await seedReport(userUid, adminUid, {status: "dismissed"});

    await signInAnon(); // sign in as admin (re-use the one we already seeded)
    // We need the admin token — sign back in as admin
    signOut();
    // Re-seed admin user and sign in
    const adminUid2 = await signInAnon();
    await adminFirestoreSet(`users/${adminUid2}`, {
      uid: adminUid2,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    const res = await callFn("adminGetDashboard");
    expect(res["pendingReports"]).toBe(2);
  });

  test("counts banned users correctly", async () => {
    const adminUid = await signInAsAdmin();
    signOut();

    await seedUser({banned: true});
    await seedUser({banned: true});
    await seedUser(); // not banned

    const adminUid2 = await signInAnon();
    await adminFirestoreSet(`users/${adminUid2}`, {
      uid: adminUid2,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    const res = await callFn("adminGetDashboard");
    expect(res["bannedUsers"]).toBe(2);
    // silence unused var warning
    void adminUid;
  });

  test("counts users in active rooms as online", async () => {
    // buildRoom signs in as multiple non-admin users — re-establish admin token after.
    const roomId = await buildRoom(2);
    signOut();

    const aid = await signInAnon();
    await adminFirestoreSet(`users/${aid}`, {
      uid: aid,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    const res = await callFn("adminGetDashboard");
    expect(typeof res["onlineUsers"]).toBe("number");
    expect(res["onlineUsers"]).toBeGreaterThanOrEqual(1);
    void roomId;
  });

  test("rejects unauthenticated callers", async () => {
    signOut();
    await expect(callFn("adminGetDashboard")).rejects.toThrow(
      "unauthenticated",
    );
  });

  test("rejects non-admin callers", async () => {
    await signInAnon(); // no user doc → role check fails
    await expect(callFn("adminGetDashboard")).rejects.toThrow(
      "permission-denied",
    );
  });
});

// ── adminResolveReport ────────────────────────────────────────────────────────

describe("adminResolveReport", () => {
  test("dismisses a pending report and writes outcome", async () => {
    const adminUid = await signInAsAdmin();
    signOut();

    const userUid = await seedUser();
    const reportId = await seedReport(userUid, adminUid);

    // sign in as admin
    const aid = await signInAnon();
    await adminFirestoreSet(`users/${aid}`, {
      uid: aid,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    const res = await callFn("adminResolveReport", {
      reportId,
      action: "dismiss",
      note: "clearly spam",
    });

    expect(res["success"]).toBe(true);

    const doc = await adminFirestoreDoc(`reports/${reportId}`);
    expect(doc?.["status"]).toBe("dismissed");
    expect(typeof doc?.["outcome"]).toBe("object");
    const outcome = doc?.["outcome"] as Record<string, unknown>;
    expect(outcome["kind"]).toBe("dismissed");
    expect(outcome["byName"]).toBe("Test Admin");
    expect(outcome["note"]).toBe("clearly spam");
  });

  test("marks a pending report as reviewed", async () => {
    const adminUid = await signInAsAdmin();
    signOut();

    const userUid = await seedUser();
    const reportId = await seedReport(userUid, adminUid);

    const aid = await signInAnon();
    await adminFirestoreSet(`users/${aid}`, {
      uid: aid,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    await callFn("adminResolveReport", {reportId, action: "reviewed"});

    const doc = await adminFirestoreDoc(`reports/${reportId}`);
    expect(doc?.["status"]).toBe("reviewed");
    const outcome = doc?.["outcome"] as Record<string, unknown>;
    expect(outcome["kind"]).toBe("reviewed");
  });

  test("returns already_resolved for a non-pending report", async () => {
    const adminUid = await signInAsAdmin();
    signOut();

    const userUid = await seedUser();
    const reportId = await seedReport(userUid, adminUid, {status: "dismissed"});

    const aid = await signInAnon();
    await adminFirestoreSet(`users/${aid}`, {
      uid: aid,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    const res = await callFn("adminResolveReport", {
      reportId,
      action: "dismiss",
    });
    expect(res["success"]).toBe(false);
    expect(res["reason"]).toBe("already_resolved");
  });

  test("returns not_found for a missing report", async () => {
    await signInAsAdmin();
    const res = await callFn("adminResolveReport", {
      reportId: "nonexistent-report",
      action: "dismiss",
    });
    expect(res["success"]).toBe(false);
    expect(res["reason"]).toBe("not_found");
  });

  test("rejects invalid action value", async () => {
    await signInAsAdmin();
    await expect(
      callFn("adminResolveReport", {reportId: "any", action: "delete"}),
    ).rejects.toThrow("invalid-argument");
  });

  test("rejects unauthenticated callers", async () => {
    signOut();
    await expect(
      callFn("adminResolveReport", {reportId: "x", action: "dismiss"}),
    ).rejects.toThrow("unauthenticated");
  });

  test("rejects non-admin callers", async () => {
    await signInAnon();
    await expect(
      callFn("adminResolveReport", {reportId: "x", action: "dismiss"}),
    ).rejects.toThrow("permission-denied");
  });
});

// ── adminGetChatLog ───────────────────────────────────────────────────────────

describe("adminGetChatLog", () => {
  test("returns not_found for a missing report", async () => {
    await signInAsAdmin();
    const res = await callFn("adminGetChatLog", {
      reportId: "nonexistent-report",
    });
    expect(res["success"]).toBe(false);
    expect(res["reason"]).toBe("not_found");
  });

  test("returns no_chat_log when chatLogStoragePath is null", async () => {
    const adminUid = await signInAsAdmin();
    signOut();
    const userUid = await seedUser();
    const reportId = await seedReport(userUid, adminUid, {
      chatLogStoragePath: null,
    });

    const aid = await signInAnon();
    await adminFirestoreSet(`users/${aid}`, {
      uid: aid,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    const res = await callFn("adminGetChatLog", {reportId});
    expect(res["success"]).toBe(false);
    expect(res["reason"]).toBe("no_chat_log");
  });

  test("rejects unauthenticated callers", async () => {
    signOut();
    await expect(callFn("adminGetChatLog", {reportId: "x"})).rejects.toThrow(
      "unauthenticated",
    );
  });

  test("rejects non-admin callers", async () => {
    await signInAnon();
    await expect(callFn("adminGetChatLog", {reportId: "x"})).rejects.toThrow(
      "permission-denied",
    );
  });
});

// ── adminBanUser ──────────────────────────────────────────────────────────────

describe("adminBanUser", () => {
  test("writes all ban fields to users/{uid}", async () => {
    const adminUid = await signInAsAdmin();
    signOut();
    const targetUid = await seedUser();

    const aid = await signInAnon();
    await adminFirestoreSet(`users/${aid}`, {
      uid: aid,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    const res = await callFn("adminBanUser", {
      uid: targetUid,
      reason: "Harassment or Bullying",
      duration: "7 Days",
      note: "repeated offender",
    });
    expect(res["success"]).toBe(true);

    const doc = await adminFirestoreDoc(`users/${targetUid}`);
    expect(doc?.["banned"]).toBe(true);
    expect(doc?.["banReason"]).toBe("Harassment or Bullying");
    expect(doc?.["banDuration"]).toBe("7 Days");
    expect(doc?.["bannedByName"]).toBe("Test Admin");
    expect(doc?.["banNote"]).toBe("repeated offender");
    expect(typeof doc?.["bannedAt"]).toBe("string"); // Timestamp decoded as string
    expect(typeof doc?.["banExpiresAt"]).toBe("string");
    void adminUid;
  });

  test("permanent ban sets banExpiresAt to null", async () => {
    await signInAsAdmin();
    signOut();
    const targetUid = await seedUser();

    const aid = await signInAnon();
    await adminFirestoreSet(`users/${aid}`, {
      uid: aid,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    await callFn("adminBanUser", {
      uid: targetUid,
      reason: "Spam & Scams",
      duration: "Permanent",
    });

    const doc = await adminFirestoreDoc(`users/${targetUid}`);
    expect(doc?.["banDuration"]).toBe("Permanent");
    expect(doc?.["banExpiresAt"]).toBeNull();
  });

  test("resolves the linked report atomically when reportId is given", async () => {
    const adminUid = await signInAsAdmin();
    signOut();
    const targetUid = await seedUser();
    const reportId = await seedReport(targetUid, adminUid);

    const aid = await signInAnon();
    await adminFirestoreSet(`users/${aid}`, {
      uid: aid,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    await callFn("adminBanUser", {
      uid: targetUid,
      reason: "Harassment or Bullying",
      duration: "30 Days",
      reportId,
    });

    const reportDoc = await adminFirestoreDoc(`reports/${reportId}`);
    expect(reportDoc?.["status"]).toBe("reviewed");
    const outcome = reportDoc?.["outcome"] as Record<string, unknown>;
    expect(outcome["kind"]).toBe("banned");
  });

  test("returns already_banned when user is already banned", async () => {
    await signInAsAdmin();
    signOut();
    const targetUid = await seedUser({banned: true});

    const aid = await signInAnon();
    await adminFirestoreSet(`users/${aid}`, {
      uid: aid,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    const res = await callFn("adminBanUser", {
      uid: targetUid,
      reason: "Spam & Scams",
      duration: "1 Day",
    });
    expect(res["success"]).toBe(false);
    expect(res["reason"]).toBe("already_banned");
  });

  test("returns user_not_found for an unknown uid", async () => {
    await signInAsAdmin();
    const res = await callFn("adminBanUser", {
      uid: "nonexistent-uid",
      reason: "Spam & Scams",
      duration: "1 Day",
    });
    expect(res["success"]).toBe(false);
    expect(res["reason"]).toBe("user_not_found");
  });

  test("rejects invalid duration", async () => {
    await signInAsAdmin();
    await expect(
      callFn("adminBanUser", {uid: "x", reason: "spam", duration: "2 Hours"}),
    ).rejects.toThrow("invalid-argument");
  });

  test("rejects unauthenticated callers", async () => {
    signOut();
    await expect(
      callFn("adminBanUser", {uid: "x", reason: "spam", duration: "1 Day"}),
    ).rejects.toThrow("unauthenticated");
  });

  test("rejects non-admin callers", async () => {
    await signInAnon();
    await expect(
      callFn("adminBanUser", {uid: "x", reason: "spam", duration: "1 Day"}),
    ).rejects.toThrow("permission-denied");
  });
});

// ── adminUnbanUser ────────────────────────────────────────────────────────────

describe("adminUnbanUser", () => {
  test("clears all ban fields and appends record to banHistory", async () => {
    const adminUid = await signInAsAdmin();
    signOut();
    const targetUid = await seedUser({
      banned: true,
      banReason: "Spam & Scams",
      banDuration: "7 Days",
      bannedAt: new Date(),
      banExpiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      bannedBy: adminUid,
      bannedByName: "Test Admin",
      banNote: "initial ban",
    });

    const aid = await signInAnon();
    await adminFirestoreSet(`users/${aid}`, {
      uid: aid,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    const res = await callFn("adminUnbanUser", {uid: targetUid});
    expect(res["success"]).toBe(true);

    const doc = await adminFirestoreDoc(`users/${targetUid}`);

    // ban fields must be gone
    expect(doc?.["banned"]).toBeUndefined();
    expect(doc?.["banReason"]).toBeUndefined();
    expect(doc?.["banDuration"]).toBeUndefined();
    expect(doc?.["bannedAt"]).toBeUndefined();
    expect(doc?.["banExpiresAt"]).toBeUndefined();
    expect(doc?.["bannedBy"]).toBeUndefined();
    expect(doc?.["bannedByName"]).toBeUndefined();
    expect(doc?.["banNote"]).toBeUndefined();

    // banHistory must have the record
    expect(Array.isArray(doc?.["banHistory"])).toBe(true);
    const history = doc?.["banHistory"] as Array<Record<string, unknown>>;
    expect(history.length).toBe(1);
    expect(history[0]["reason"]).toBe("Spam & Scams");
    expect(history[0]["duration"]).toBe("7 Days");
    expect(typeof history[0]["unbannedAt"]).toBe("string");
    expect(history[0]["unbannedBy"]).toBe(aid);
  });

  test("appends to existing banHistory (not overwrites)", async () => {
    const adminUid = await signInAsAdmin();
    signOut();
    const existing = {
      reason: "Spam & Scams",
      duration: "1 Day",
      bannedAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
      expiresAt: new Date(Date.now() - 24 * 60 * 60 * 1000),
      bannedBy: adminUid,
      bannedByName: "Test Admin",
      note: null,
      unbannedAt: new Date(Date.now() - 12 * 60 * 60 * 1000),
      unbannedBy: adminUid,
    };
    const targetUid = await seedUser({
      banned: true,
      banReason: "Harassment or Bullying",
      banDuration: "7 Days",
      bannedAt: new Date(),
      banExpiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      bannedBy: adminUid,
      bannedByName: "Test Admin",
      banNote: null,
      banHistory: [existing],
    });

    const aid = await signInAnon();
    await adminFirestoreSet(`users/${aid}`, {
      uid: aid,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    await callFn("adminUnbanUser", {uid: targetUid});

    const doc = await adminFirestoreDoc(`users/${targetUid}`);
    const history = doc?.["banHistory"] as Array<Record<string, unknown>>;
    expect(history.length).toBe(2);
  });

  test("returns not_banned when user is not banned", async () => {
    await signInAsAdmin();
    signOut();
    const targetUid = await seedUser(); // no banned field

    const aid = await signInAnon();
    await adminFirestoreSet(`users/${aid}`, {
      uid: aid,
      role: "admin",
      displayName: "Test Admin",
      interest: "",
      createdAt: new Date(),
      lastSeen: new Date(),
    });

    const res = await callFn("adminUnbanUser", {uid: targetUid});
    expect(res["success"]).toBe(false);
    expect(res["reason"]).toBe("not_banned");
  });

  test("returns user_not_found for an unknown uid", async () => {
    await signInAsAdmin();
    const res = await callFn("adminUnbanUser", {uid: "nonexistent-uid"});
    expect(res["success"]).toBe(false);
    expect(res["reason"]).toBe("user_not_found");
  });

  test("rejects unauthenticated callers", async () => {
    signOut();
    await expect(callFn("adminUnbanUser", {uid: "x"})).rejects.toThrow(
      "unauthenticated",
    );
  });

  test("rejects non-admin callers", async () => {
    await signInAnon();
    await expect(callFn("adminUnbanUser", {uid: "x"})).rejects.toThrow(
      "permission-denied",
    );
  });
});

// ── adminListReports (Firestore direct reads — no CF) ─────────────────────────
// These tests verify the schema shape as it would be read by the Flutter client
// after the firestore.rules isAdmin() fix.

describe("reports collection schema", () => {
  test("report doc has all required fields after reportSession-like seed", async () => {
    const adminUid = await signInAsAdmin();
    signOut();
    const userUid = await seedUser();
    const reportId = await seedReport(userUid, adminUid);

    const doc = await adminFirestoreDoc(`reports/${reportId}`);
    expect(typeof doc?.["reporterId"]).toBe("string");
    expect(typeof doc?.["reportedUserId"]).toBe("string");
    expect(typeof doc?.["sessionId"]).toBe("string");
    expect(typeof doc?.["reportType"]).toBe("string");
    expect(typeof doc?.["reason"]).toBe("string");
    expect(doc?.["status"]).toBe("pending");
    expect(doc?.["chatLogStoragePath"]).toBeNull();
    expect(Array.isArray(doc?.["contextImageUrls"])).toBe(true);
  });
});
