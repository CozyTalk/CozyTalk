/**
 * Seed the Firebase emulator with admin-dashboard test data.
 *
 * Run (emulators must be up first):
 *   node tools/seed-admin-data.js
 *
 * Creates:
 *   - 1 admin user
 *   - 6 regular users (2 active-banned, 1 with ban history, 3 clean)
 *   - 6 reports (4 pending, 1 dismissed, 1 reviewed/banned)
 *   - RTDB pool_presence for 2 users (shows as "online" in dashboard)
 *
 * Requires: Auth 9099, Firestore 8080, RTDB 9000, Functions 5001 all running.
 */

const AUTH = "http://127.0.0.1:9099";
const FIRESTORE = "http://127.0.0.1:8080";
const RTDB = "http://127.0.0.1:9000";
const PROJECT = "cozytalk-5d984";
const DB = "(default)";
const RTDB_NS = `${PROJECT}-default-rtdb`;

// ── Emulator helpers ──────────────────────────────────────────────────────────

async function signInAnon() {
  const res = await fetch(
    `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({returnSecureToken: true}),
    },
  );
  if (!res.ok) throw new Error(`Auth signIn failed (${res.status})`);
  const body = await res.json();
  return body.localId;
}

function toFsValue(val) {
  if (val === null || val === undefined) return {nullValue: null};
  if (typeof val === "boolean") return {booleanValue: val};
  if (typeof val === "number") {
    return Number.isInteger(val)
      ? {integerValue: String(val)}
      : {doubleValue: val};
  }
  if (val instanceof Date) return {timestampValue: val.toISOString()};
  if (typeof val === "string") return {stringValue: val};
  if (Array.isArray(val))
    return {arrayValue: {values: val.map(toFsValue)}};
  if (typeof val === "object") {
    const fields = {};
    for (const [k, v] of Object.entries(val)) fields[k] = toFsValue(v);
    return {mapValue: {fields}};
  }
  return {stringValue: String(val)};
}

async function fsSet(path, data) {
  const fields = {};
  for (const [k, v] of Object.entries(data)) fields[k] = toFsValue(v);
  const res = await fetch(
    `${FIRESTORE}/v1/projects/${PROJECT}/databases/${DB}/documents/${path}`,
    {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer owner",
      },
      body: JSON.stringify({fields}),
    },
  );
  if (!res.ok) throw new Error(`fsSet(${path}) failed (${res.status}): ${await res.text()}`);
}

async function rtdbSet(path, data) {
  const res = await fetch(
    `${RTDB}/${path}.json?ns=${RTDB_NS}`,
    {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer owner",
      },
      body: JSON.stringify(data),
    },
  );
  if (!res.ok) throw new Error(`rtdbSet(${path}) failed (${res.status}): ${await res.text()}`);
}

// ── Seed ──────────────────────────────────────────────────────────────────────

const now = new Date();
const DAY = 24 * 60 * 60 * 1000;
const ago = (days) => new Date(now.getTime() - days * DAY);
const from = (days) => new Date(now.getTime() + days * DAY);
let seq = Date.now();
const nextId = (prefix) => `${prefix}-${seq++}`;

async function seed() {
  console.log("Seeding admin dashboard data against emulator...\n");

  // ── Admin user ──────────────────────────────────────────────────────────────
  const adminUid = await signInAnon();
  await fsSet(`users/${adminUid}`, {
    uid: adminUid,
    role: "admin",
    displayName: "Moderator",
    interest: "Keeping the community safe",
    createdAt: ago(90),
    lastSeen: now,
  });
  console.log(`Admin:   ${adminUid} (Moderator)`);

  // ── Regular users ───────────────────────────────────────────────────────────

  // userA — 2 pending reports against them; online via pool_presence
  const userA = await signInAnon();
  await fsSet(`users/${userA}`, {
    uid: userA,
    role: "user",
    displayName: "QuietOwl3411",
    interest:
      "I love technology and programming. Always looking to learn something new from strangers.",
    createdAt: ago(30),
    lastSeen: ago(0.1),
  });

  // userB — 1 pending report against; also a reporter
  const userB = await signInAnon();
  await fsSet(`users/${userB}`, {
    uid: userB,
    role: "user",
    displayName: "SilentFox7823",
    interest:
      "Cooking enthusiast. Love talking about recipes, food culture, and culinary traditions.",
    createdAt: ago(60),
    lastSeen: ago(1),
  });

  // userC — reporter only; online via pool_presence
  const userC = await signInAnon();
  await fsSet(`users/${userC}`, {
    uid: userC,
    role: "user",
    displayName: "WildEagle9012",
    interest: "Nature and wildlife photography. Hiking, camping, outdoor adventures.",
    createdAt: ago(14),
    lastSeen: ago(0.5),
  });

  // userD — currently banned (7 days) for harassment
  const userD = await signInAnon();
  await fsSet(`users/${userD}`, {
    uid: userD,
    role: "user",
    displayName: "GoldenBear5521",
    interest: "Gaming and competitive esports.",
    createdAt: ago(45),
    lastSeen: ago(1),
    banned: true,
    banReason: "Harassment or Bullying",
    banDuration: "7 Days",
    bannedAt: ago(1),
    banExpiresAt: from(6),
    bannedBy: adminUid,
    bannedByName: "Moderator",
    banNote: "Sent threatening messages to multiple users.",
    banHistory: [],
  });

  // userE — permanently banned; prior 1-day ban in history
  const userE = await signInAnon();
  await fsSet(`users/${userE}`, {
    uid: userE,
    role: "user",
    displayName: "CalmWolf2314",
    interest: "Finance and crypto.",
    createdAt: ago(120),
    lastSeen: ago(3),
    banned: true,
    banReason: "Spam & Scams",
    banDuration: "Permanent",
    bannedAt: ago(3),
    banExpiresAt: null,
    bannedBy: adminUid,
    bannedByName: "Moderator",
    banNote: "Repeated crypto scam attempts after prior 1-day ban.",
    banHistory: [
      {
        reason: "Spam & Scams",
        duration: "1 Day",
        bannedAt: ago(10),
        expiresAt: ago(9),
        bannedBy: adminUid,
        bannedByName: "Moderator",
        note: "First warning — crypto giveaway spam.",
        unbannedAt: ago(9),
        unbannedBy: adminUid,
      },
    ],
  });

  // userF — previously banned 30 days (history only), currently active
  const userF = await signInAnon();
  await fsSet(`users/${userF}`, {
    uid: userF,
    role: "user",
    displayName: "LazyCat8807",
    interest: "Music production and electronic beats.",
    createdAt: ago(75),
    lastSeen: ago(0.2),
    banHistory: [
      {
        reason: "Inappropriate Content",
        duration: "30 Days",
        bannedAt: ago(50),
        expiresAt: ago(20),
        bannedBy: adminUid,
        bannedByName: "Moderator",
        note: null,
        unbannedAt: ago(20),
        unbannedBy: adminUid,
      },
    ],
  });

  console.log(`Users:   ${userA} (QuietOwl3411)`);
  console.log(`         ${userB} (SilentFox7823)`);
  console.log(`         ${userC} (WildEagle9012)`);
  console.log(`         ${userD} (GoldenBear5521) — banned 7 Days`);
  console.log(`         ${userE} (CalmWolf2314)   — banned Permanent`);
  console.log(`         ${userF} (LazyCat8807)    — ban history only`);

  // ── Pool presence (online users) ────────────────────────────────────────────
  await rtdbSet(`pool_presence/${userA}`, {status: "searching", createdAt: now.getTime()});
  await rtdbSet(`pool_presence/${userC}`, {status: "searching", createdAt: now.getTime()});
  console.log(`Online:  ${userA} + ${userC} (pool_presence)`);

  // ── Reports ─────────────────────────────────────────────────────────────────

  // Pending #1 — spam against userA, from userC; has chat log path
  const r1 = nextId("report");
  await fsSet(`reports/${r1}`, {
    reporterId: userC,
    reporterName: "WildEagle9012",
    reportedUserId: userA,
    reportedName: "QuietOwl3411",
    reportedInterest: "I love technology and programming.",
    sessionId: "room-abc12",
    reportType: "spam",
    reason: "Kept sending crypto links and asking me to invest.",
    contextText: "Hey invest in this token, 100x guaranteed — don't miss out!",
    contextImageUrls: [],
    chatLogStoragePath: "chat_logs/room-abc12.json",
    createdAt: ago(0.5),
    status: "pending",
  });

  // Pending #2 — harassment against userA, from userB
  const r2 = nextId("report");
  await fsSet(`reports/${r2}`, {
    reporterId: userB,
    reporterName: "SilentFox7823",
    reportedUserId: userA,
    reportedName: "QuietOwl3411",
    reportedInterest: "I love technology and programming.",
    sessionId: "room-def34",
    reportType: "harassment",
    reason: "Insulted me when I refused to give personal information.",
    contextText: "You're so stupid, just tell me where you live",
    contextImageUrls: [],
    chatLogStoragePath: null,
    createdAt: ago(1),
    status: "pending",
  });

  // Pending #3 — inappropriate_content against userB, from userA
  const r3 = nextId("report");
  await fsSet(`reports/${r3}`, {
    reporterId: userA,
    reporterName: "QuietOwl3411",
    reportedUserId: userB,
    reportedName: "SilentFox7823",
    reportedInterest: "Cooking enthusiast.",
    sessionId: "room-ghi56",
    reportType: "inappropriate_content",
    reason: "Shared graphic content without any warning.",
    contextText: null,
    contextImageUrls: [],
    chatLogStoragePath: null,
    createdAt: ago(2),
    status: "pending",
  });

  // Pending #4 — harassment against userB, from userC
  const r4 = nextId("report");
  await fsSet(`reports/${r4}`, {
    reporterId: userC,
    reporterName: "WildEagle9012",
    reportedUserId: userB,
    reportedName: "SilentFox7823",
    reportedInterest: "Cooking enthusiast.",
    sessionId: "room-jkl78",
    reportType: "harassment",
    reason: "Made fun of my hobby repeatedly and called me names.",
    contextText: null,
    contextImageUrls: [],
    chatLogStoragePath: null,
    createdAt: ago(3),
    status: "pending",
  });

  // Dismissed #5 — spam against userC (resolved, no action needed)
  const r5 = nextId("report");
  await fsSet(`reports/${r5}`, {
    reporterId: userA,
    reporterName: "QuietOwl3411",
    reportedUserId: userC,
    reportedName: "WildEagle9012",
    reportedInterest: "Nature and wildlife photography.",
    sessionId: "room-mno90",
    reportType: "spam",
    reason: "Seemed suspicious but actually just enthusiastic.",
    contextText: null,
    contextImageUrls: [],
    chatLogStoragePath: null,
    createdAt: ago(5),
    status: "dismissed",
    outcome: {
      kind: "dismissed",
      by: adminUid,
      byName: "Moderator",
      note: "No violation found after review.",
      at: ago(4),
    },
  });

  // Reviewed/banned #6 — harassment against userD (linked to their active ban)
  const r6 = nextId("report");
  await fsSet(`reports/${r6}`, {
    reporterId: userB,
    reporterName: "SilentFox7823",
    reportedUserId: userD,
    reportedName: "GoldenBear5521",
    reportedInterest: "Gaming and competitive esports.",
    sessionId: "room-pqr12",
    reportType: "harassment",
    reason: "Threatened to find me in real life after I beat them.",
    contextText: "I will find you. I know where you live.",
    contextImageUrls: [],
    chatLogStoragePath: null,
    createdAt: ago(1.5),
    status: "reviewed",
    outcome: {
      kind: "banned",
      by: adminUid,
      byName: "Moderator",
      note: "Credible threat — 7-day ban issued.",
      at: ago(1),
    },
  });

  console.log(`Reports: ${r1} (pending  · spam · userA)`);
  console.log(`         ${r2} (pending  · harassment · userA)`);
  console.log(`         ${r3} (pending  · inappropriate_content · userB)`);
  console.log(`         ${r4} (pending  · harassment · userB)`);
  console.log(`         ${r5} (dismissed · spam · userC)`);
  console.log(`         ${r6} (reviewed · banned · userD)`);

  console.log(`\nDone.\n`);
  console.log(`Dashboard should show:  4 pending · 2 online · 2 banned`);
  console.log(`Open the Flutter app → Admin Console to verify.`);
}

seed().catch((err) => {
  console.error("\nSeed failed:", err.message);
  process.exit(1);
});
