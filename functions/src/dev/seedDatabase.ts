import * as admin from "firebase-admin";
import {Timestamp} from "firebase-admin/firestore";
import {getDatabase} from "firebase-admin/database";
import * as crypto from "crypto";
import * as readline from "readline";

const USE_EMULATORS = !process.argv.includes("--prod");
const PROJECT_ID = "cozytalk-5d984";
const RTDB_URL =
  "https://cozytalk-5d984-default-rtdb.asia-southeast1.firebasedatabase.app";

if (USE_EMULATORS) {
  process.env["FIRESTORE_EMULATOR_HOST"] = "localhost:8080";
  process.env["FIREBASE_DATABASE_EMULATOR_HOST"] = "localhost:9000";
  process.env["FIREBASE_AUTH_EMULATOR_HOST"] = "localhost:9099";
}

admin.initializeApp({projectId: PROJECT_ID, databaseURL: RTDB_URL});

const db = admin.firestore();
const rtdb = getDatabase();

// ── helpers ───────────────────────────────────────────────────────────────────

function generateKey(): string {
  return crypto.randomBytes(32).toString("hex");
}

function encryptMessage(
  plaintext: string,
  keyHex: string,
): {encryptedText: string; iv: string; authTag: string} {
  const key = Buffer.from(keyHex, "hex");
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([
    cipher.update(plaintext, "utf8"),
    cipher.final(),
  ]);
  return {
    encryptedText: encrypted.toString("base64"),
    iv: iv.toString("base64"),
    authTag: cipher.getAuthTag().toString("base64"),
  };
}

function ts(offsetMs = 0): Timestamp {
  return Timestamp.fromMillis(Date.now() + offsetMs);
}

function randomNormalizedVector(): number[] {
  const v = Array.from({length: 256}, () => Math.random() * 2 - 1);
  const norm = Math.sqrt(v.reduce((s, x) => s + x * x, 0));
  return v.map((x) => x / norm);
}

async function confirm(prompt: string): Promise<string> {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) =>
    rl.question(prompt, (answer) => {
      rl.close();
      resolve(answer);
    }),
  );
}

// ── constants ─────────────────────────────────────────────────────────────────

const ROOM_IDS = {
  oneOnOne: "ROOM1",
  group: "GRP01",
  expired: "OLD01",
  proto: "proto-ALICE001",
};

const USER_IDS = {
  admin: "user_admin_001",
  alice: "user_alice_002",
  bob: "user_bob_003",
  carol: "user_carol_004",
  anon1: "user_anon_005",
  anon2: "user_anon_006",
};

// Generated once so encryption keys stay consistent across all collections.
const KEYS = {
  oneOnOne: generateKey(),
  group: generateKey(),
  proto: generateKey(),
};

// ── seeders ───────────────────────────────────────────────────────────────────

async function seedUsers(): Promise<void> {
  console.log("  users…");
  const batch = db.batch();

  const users: Array<{id: string; data: Record<string, unknown>}> = [
    {
      id: USER_IDS.admin,
      data: {
        uid: USER_IDS.admin,
        email: "admin@cozytalk.app",
        displayName: "Admin User",
        photoUrl: null,
        role: "admin",
        createdAt: ts(-30 * 24 * 60 * 60_000),
        lastSeen: ts(-5 * 60_000),
        hatKey: "Crown",
        moodKey: "Thrilled",
        interest: "platform administration and user safety",
        thoughts: "Keeping things cozy",
      },
    },
    {
      id: USER_IDS.alice,
      data: {
        uid: USER_IDS.alice,
        email: "alice@example.com",
        displayName: "Cozy Alice",
        photoUrl: "https://api.dicebear.com/7.x/avataaars/png?seed=alice",
        role: "user",
        createdAt: ts(-14 * 24 * 60 * 60_000),
        lastSeen: ts(-2 * 60_000),
        hatKey: "Cat Headband",
        moodKey: "Happy",
        interest: "anime, lo-fi music, and creative writing",
        thoughts: "Always looking to chat!",
      },
    },
    {
      id: USER_IDS.bob,
      data: {
        uid: USER_IDS.bob,
        email: "bob@example.com",
        displayName: "Sunny Bob",
        photoUrl: "https://api.dicebear.com/7.x/avataaars/png?seed=bob",
        role: "user",
        createdAt: ts(-7 * 24 * 60 * 60_000),
        lastSeen: ts(-60_000),
        hatKey: "Beanie",
        moodKey: "Silly",
        interest: "indie games and pixel art",
        thoughts: "GGs only",
      },
    },
    {
      id: USER_IDS.carol,
      data: {
        uid: USER_IDS.carol,
        email: "carol@example.com",
        displayName: "Wandering Carol",
        photoUrl: null,
        role: "user",
        createdAt: ts(-3 * 24 * 60 * 60_000),
        lastSeen: ts(-30 * 60_000),
        hatKey: "Witch",
        moodKey: "Lonely",
        interest: "hiking, nature photography, and books",
        thoughts: "Looking for a vibe",
      },
    },
    {
      id: USER_IDS.anon1,
      data: {
        uid: USER_IDS.anon1,
        role: "user",
        createdAt: ts(-24 * 60 * 60_000),
        lastSeen: ts(-60 * 60_000),
        interest: "",
      },
    },
    {
      id: USER_IDS.anon2,
      data: {
        uid: USER_IDS.anon2,
        role: "user",
        createdAt: ts(-2 * 60 * 60_000),
        lastSeen: ts(-5 * 60_000),
        interest: "music and tech",
      },
    },
  ];

  for (const {id, data} of users) {
    batch.set(db.collection("users").doc(id), data);
  }
  await batch.commit();
  console.log(`    ✓ ${users.length} docs`);
}

async function seedWaitingPool(): Promise<void> {
  console.log("  waiting_pool…");
  const batch = db.batch();

  const entries: Array<{id: string; data: Record<string, unknown>}> = [
    {
      id: USER_IDS.carol,
      data: {
        createdAt: ts(-10 * 60_000),
        updatedAt: ts(-10 * 60_000),
        status: "waiting",
        mode: "1v1",
        roomId: null,
        interestText: "hiking, nature photography, and books",
        interestVector: randomNormalizedVector(),
      },
    },
    {
      id: USER_IDS.anon2,
      data: {
        createdAt: ts(-5 * 60_000),
        updatedAt: ts(-5 * 60_000),
        status: "waiting",
        mode: "group",
        roomId: null,
        interestText: "music and tech",
        interestVector: randomNormalizedVector(),
      },
    },
    {
      id: USER_IDS.bob,
      data: {
        createdAt: ts(-15 * 60_000),
        updatedAt: ts(-2 * 60_000),
        status: "matching",
        mode: "1v1",
        roomId: null,
        interestText: "indie games and pixel art",
        interestVector: randomNormalizedVector(),
      },
    },
  ];

  for (const {id, data} of entries) {
    batch.set(db.collection("waiting_pool").doc(id), data);
  }
  await batch.commit();
  console.log(`    ✓ ${entries.length} docs`);
}

async function seedRooms(): Promise<void> {
  console.log("  rooms…");
  const batch = db.batch();

  const aliceVec = randomNormalizedVector();
  const bobVec = randomNormalizedVector();
  const carolVec = randomNormalizedVector();
  const mean1v1 = aliceVec.map((v, i) => (v + bobVec[i]) / 2);
  const meanGroup = aliceVec.map((v, i) => (v + bobVec[i] + carolVec[i]) / 3);

  const rooms: Array<{id: string; data: Record<string, unknown>}> = [
    {
      id: ROOM_IDS.oneOnOne,
      data: {
        roomId: ROOM_IDS.oneOnOne,
        roomType: "public",
        mode: "1v1",
        status: "active",
        maxUsers: 2,
        memberCount: 2,
        users: [USER_IDS.alice, USER_IDS.bob],
        isLocked: false,
        createdAt: ts(-20 * 60_000),
        paddingUntil: null,
        encryptionKey: KEYS.oneOnOne,
        roomInterestVector: mean1v1,
        memberInterests: {
          [USER_IDS.alice]: aliceVec,
          [USER_IDS.bob]: bobVec,
        },
      },
    },
    {
      id: ROOM_IDS.group,
      data: {
        roomId: ROOM_IDS.group,
        roomType: "custom",
        mode: "group",
        status: "active",
        maxUsers: 5,
        memberCount: 3,
        users: [USER_IDS.alice, USER_IDS.bob, USER_IDS.carol],
        isLocked: false,
        createdAt: ts(-45 * 60_000),
        paddingUntil: null,
        encryptionKey: KEYS.group,
        roomInterestVector: meanGroup,
        memberInterests: {
          [USER_IDS.alice]: aliceVec,
          [USER_IDS.bob]: bobVec,
          [USER_IDS.carol]: carolVec,
        },
      },
    },
    {
      id: ROOM_IDS.expired,
      data: {
        roomId: ROOM_IDS.expired,
        roomType: "public",
        mode: "1v1",
        status: "expired",
        maxUsers: 2,
        memberCount: 0,
        users: [],
        isLocked: false,
        createdAt: ts(-2 * 24 * 60 * 60_000),
        paddingUntil: null,
        encryptionKey: generateKey(),
      },
    },
  ];

  for (const {id, data} of rooms) {
    batch.set(db.collection("rooms").doc(id), data);
  }
  await batch.commit();
  console.log(`    ✓ ${rooms.length} docs`);
}

async function seedActiveSessions(): Promise<void> {
  console.log("  active_sessions (legacy)…");
  await db
    .collection("active_sessions")
    .doc(ROOM_IDS.proto)
    .set({
      users: [USER_IDS.alice, USER_IDS.anon1],
      roomId: ROOM_IDS.proto,
      createdAt: ts(-60 * 60_000),
      endedAt: null,
      status: "active",
      encryptionKey: KEYS.proto,
    });
  console.log("    ✓ 1 doc");
}

async function seedChatMessages(): Promise<void> {
  console.log("  chat_rooms/*/messages…");

  const sessions: Array<{
    sessionId: string;
    key: string;
    messages: Array<{senderId: string; displayName: string; text: string}>;
  }> = [
    {
      sessionId: ROOM_IDS.oneOnOne,
      key: KEYS.oneOnOne,
      messages: [
        {
          senderId: USER_IDS.alice,
          displayName: "Cozy Alice",
          text: "Hey! How's it going?",
        },
        {
          senderId: USER_IDS.bob,
          displayName: "Sunny Bob",
          text: "Pretty good, just chilling. You?",
        },
        {
          senderId: USER_IDS.alice,
          displayName: "Cozy Alice",
          text: "Same — loving the vibes here :)",
        },
      ],
    },
    {
      sessionId: ROOM_IDS.group,
      key: KEYS.group,
      messages: [
        {
          senderId: USER_IDS.alice,
          displayName: "Cozy Alice",
          text: "Welcome everyone!",
        },
        {
          senderId: USER_IDS.bob,
          displayName: "Sunny Bob",
          text: "Thanks for having us!",
        },
        {
          senderId: USER_IDS.carol,
          displayName: "Wandering Carol",
          text: "Happy to be here. What are we chatting about?",
        },
        {
          senderId: USER_IDS.alice,
          displayName: "Cozy Alice",
          text: "Music! I have a playlist queued up.",
        },
      ],
    },
    {
      sessionId: ROOM_IDS.proto,
      key: KEYS.proto,
      messages: [
        {
          senderId: USER_IDS.alice,
          displayName: "Cozy Alice",
          text: "Proto session test message.",
        },
        {
          senderId: USER_IDS.anon1,
          displayName: "Brave Bear",
          text: "Received loud and clear!",
        },
      ],
    },
  ];

  const expiresAt = ts(3 * 24 * 60 * 60_000);
  let total = 0;

  for (const {sessionId, key, messages} of sessions) {
    const batch = db.batch();
    const baseMs = Date.now() - messages.length * 60_000;

    for (let i = 0; i < messages.length; i++) {
      const {senderId, displayName, text} = messages[i];
      const {encryptedText, iv, authTag} = encryptMessage(text, key);
      const ref = db
        .collection("chat_rooms")
        .doc(sessionId)
        .collection("messages")
        .doc();
      batch.set(ref, {
        senderId,
        displayName,
        encryptedText,
        iv,
        authTag,
        timestamp: Timestamp.fromMillis(baseMs + i * 60_000),
        expiresAt,
        flagged: false,
      });
    }

    await batch.commit();
    total += messages.length;
  }

  console.log(`    ✓ ${total} messages across ${sessions.length} sessions`);
}

async function seedSessionKeys(): Promise<void> {
  console.log("  session_keys…");
  const batch = db.batch();
  const expiresAt = ts(3 * 24 * 60 * 60_000);

  const keys: Array<{id: string; data: Record<string, unknown>}> = [
    {
      id: ROOM_IDS.oneOnOne,
      data: {
        sessionId: ROOM_IDS.oneOnOne,
        encryptionKey: KEYS.oneOnOne,
        users: [USER_IDS.alice, USER_IDS.bob],
        createdAt: ts(-20 * 60_000),
        expiresAt,
        flagged: false,
      },
    },
    {
      id: ROOM_IDS.group,
      data: {
        sessionId: ROOM_IDS.group,
        encryptionKey: KEYS.group,
        users: [USER_IDS.alice, USER_IDS.bob, USER_IDS.carol],
        createdAt: ts(-45 * 60_000),
        expiresAt,
        flagged: false,
      },
    },
    {
      id: ROOM_IDS.proto,
      data: {
        sessionId: ROOM_IDS.proto,
        encryptionKey: KEYS.proto,
        users: [USER_IDS.alice, USER_IDS.anon1],
        createdAt: ts(-60 * 60_000),
        expiresAt,
        flagged: false,
      },
    },
  ];

  for (const {id, data} of keys) {
    batch.set(db.collection("session_keys").doc(id), data);
  }
  await batch.commit();
  console.log(`    ✓ ${keys.length} docs`);
}

async function seedReports(): Promise<void> {
  console.log("  reports…");
  const batch = db.batch();

  const reports: Record<string, unknown>[] = [
    {
      reporterId: USER_IDS.carol,
      reportedUserId: USER_IDS.bob,
      sessionId: ROOM_IDS.oneOnOne,
      reportType: "harassment",
      reason: "Kept sending unwanted messages after being asked to stop.",
      contextText: "Persisted after multiple warnings.",
      contextImageUrls: [],
      chatLogStoragePath: null,
      createdAt: ts(-30 * 60_000),
      status: "pending",
    },
    {
      reporterId: USER_IDS.alice,
      reportedUserId: USER_IDS.anon1,
      sessionId: ROOM_IDS.proto,
      reportType: "spam",
      reason: "Repeated unsolicited advertisement links.",
      contextText: null,
      contextImageUrls: [],
      chatLogStoragePath: "reports/reviewed_001/chat_log.json",
      createdAt: ts(-2 * 24 * 60 * 60_000),
      status: "reviewed",
    },
  ];

  for (const data of reports) {
    batch.set(db.collection("reports").doc(), data);
  }
  await batch.commit();
  console.log(`    ✓ ${reports.length} docs`);
}

async function seedRTDB(): Promise<void> {
  console.log("  RTDB…");

  const nowMs = Date.now();
  // streamingUrlTimeout is Unix seconds; set 1 hour from now so seed tracks are "valid"
  const streamingUrlTimeout = Math.floor(nowMs / 1000) + 3600;

  const jukeboxQueue = [
    {
      id: "5034788",
      audiomackUrl: "https://audiomack.com/chillhop/song/lo-fi-study-beats",
      embedUrl: "https://audiomack.com/embed/chillhop/song/lo-fi-study-beats",
      streamingUrl: "https://example.com/stream/lo-fi-study-beats.mp3",
      streamingUrlTimeout,
      title: "Lo-Fi Study Beats",
      artist: "ChillHop Music",
      artworkUrl: "https://example.com/art/lofi.jpg",
      addedBy: USER_IDS.alice,
      addedByName: "Cozy Alice",
    },
    {
      id: "5034789",
      audiomackUrl: "https://audiomack.com/smoothrecords/song/midnight-jazz",
      embedUrl: "https://audiomack.com/embed/smoothrecords/song/midnight-jazz",
      streamingUrl: "https://example.com/stream/midnight-jazz.mp3",
      streamingUrlTimeout,
      title: "Midnight Jazz",
      artist: "Smooth Records",
      artworkUrl: "https://example.com/art/jazz.jpg",
      addedBy: USER_IDS.bob,
      addedByName: "Sunny Bob",
    },
    {
      id: "5034790",
      audiomackUrl: "https://audiomack.com/naturesounds/song/rain-ambience",
      embedUrl: "https://audiomack.com/embed/naturesounds/song/rain-ambience",
      streamingUrl: "https://example.com/stream/rain-ambience.mp3",
      streamingUrlTimeout,
      title: "Rain Ambience",
      artist: "Nature Sounds",
      artworkUrl: "https://example.com/art/rain.jpg",
      addedBy: USER_IDS.carol,
      addedByName: "Wandering Carol",
    },
  ];

  await rtdb.ref("/").update({
    // Room member presence (CF-written in production; needed for RTDB rules)
    [`rooms/${ROOM_IDS.oneOnOne}/members/${USER_IDS.alice}`]: true,
    [`rooms/${ROOM_IDS.oneOnOne}/members/${USER_IDS.bob}`]: true,
    [`rooms/${ROOM_IDS.group}/members/${USER_IDS.alice}`]: true,
    [`rooms/${ROOM_IDS.group}/members/${USER_IDS.bob}`]: true,
    [`rooms/${ROOM_IDS.group}/members/${USER_IDS.carol}`]: true,

    // Typing indicators
    [`typing/${ROOM_IDS.oneOnOne}/${USER_IDS.alice}`]: {
      isTyping: true,
      displayName: "Cozy Alice",
    },
    [`typing/${ROOM_IDS.oneOnOne}/${USER_IDS.bob}`]: {
      isTyping: false,
      displayName: "Sunny Bob",
    },
    [`typing/${ROOM_IDS.group}/${USER_IDS.carol}`]: {
      isTyping: true,
      displayName: "Wandering Carol",
    },

    // Presence (display name strings)
    [`presence/${ROOM_IDS.oneOnOne}/${USER_IDS.alice}`]: "Cozy Alice",
    [`presence/${ROOM_IDS.oneOnOne}/${USER_IDS.bob}`]: "Sunny Bob",
    [`presence/${ROOM_IDS.group}/${USER_IDS.alice}`]: "Cozy Alice",
    [`presence/${ROOM_IDS.group}/${USER_IDS.bob}`]: "Sunny Bob",
    [`presence/${ROOM_IDS.group}/${USER_IDS.carol}`]: "Wandering Carol",

    // User global status
    [`user_status/${USER_IDS.alice}`]: {
      status: "in_room",
      roomId: ROOM_IDS.oneOnOne,
      roomMode: "1v1",
    },
    [`user_status/${USER_IDS.bob}`]: {
      status: "in_room",
      roomId: ROOM_IDS.oneOnOne,
      roomMode: "1v1",
    },
    [`user_status/${USER_IDS.carol}`]: {status: "online"},
    [`user_status/${USER_IDS.anon2}`]: {status: "online"},

    // Pool presence (users currently in the waiting queue)
    [`pool_presence/${USER_IDS.carol}`]: true,
    [`pool_presence/${USER_IDS.anon2}`]: true,

    // Jukebox state for the group room (currentIndex=1 → Midnight Jazz is playing)
    [`jukebox/${ROOM_IDS.group}`]: {
      isPlaying: true,
      currentIndex: 1,
      startedAt: nowMs - 3 * 60_000,
      queue: jukeboxQueue,
    },
  });

  console.log(
    "    ✓ members · typing · presence · user_status · pool_presence · jukebox",
  );
}

// ── entry point ───────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  const target = USE_EMULATORS ? "EMULATORS" : "PRODUCTION";
  console.log(`\nCozyTalk seed — target: ${target}\n`);

  if (!USE_EMULATORS) {
    const answer = await confirm(
      "You are seeding PRODUCTION. Type 'seed-prod' to confirm: ",
    );
    if (answer.trim() !== "seed-prod") {
      console.log("Aborted.");
      process.exit(0);
    }
  }

  await seedUsers();
  await seedWaitingPool();
  await seedRooms();
  await seedActiveSessions();
  await seedChatMessages();
  await seedSessionKeys();
  await seedReports();
  await seedRTDB();

  console.log("\nDone.\n");
  process.exit(0);
}

void main();
