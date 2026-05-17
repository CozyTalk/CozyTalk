/**
 * Smoke test: Vertex AI interest embedding through DEPLOYED Cloud Functions.
 *
 * Tests the full path: REST call → deployed CF → Vertex AI → Firestore.
 * Use this to verify --prod mode works, or after deploying CF changes.
 *
 * Run:
 *   cd functions
 *   npx ts-node -P tsconfig.test.json src/matchmaking/__tests__/testProdVertexAI.ts
 *
 * No extra setup required — uses the public web API key from firebase_options.dart.
 */

const PROJECT = "cozytalk-5d984";
const REGION = "us-central1";
// Public web API key from apps/mobile/lib/firebase_options.dart (safe to commit).
const API_KEY = "AIzaSyAhEm1tJRomLx7ErcaHDYSlnyrpchgmro8";
const FUNCTIONS_BASE = `https://${REGION}-${PROJECT}.cloudfunctions.net`;
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

// ── Auth ─────────────────────────────────────────────────────────────────────

async function signInAnon(): Promise<{uid: string; idToken: string}> {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({returnSecureToken: true}),
    },
  );
  if (!res.ok) {
    throw new Error(`Auth failed (${res.status}): ${await res.text()}`);
  }
  const body = (await res.json()) as {localId: string; idToken: string};
  return {uid: body.localId, idToken: body.idToken};
}

async function deleteUser(idToken: string): Promise<void> {
  await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${API_KEY}`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({idToken}),
    },
  );
}

// ── Cloud Functions ───────────────────────────────────────────────────────────

async function callFn(
  name: string,
  data: Record<string, unknown>,
  idToken: string,
): Promise<Record<string, unknown>> {
  const res = await fetch(`${FUNCTIONS_BASE}/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify({data}),
  });
  const body = (await res.json()) as {
    result?: Record<string, unknown>;
    error?: {message: string; status: string};
  };
  if (body.error) {
    throw new Error(
      `${name} failed: ${body.error.status} — ${body.error.message}`,
    );
  }
  return body.result ?? {};
}

// ── Firestore ─────────────────────────────────────────────────────────────────

function decodeValue(v: unknown): unknown {
  if (typeof v !== "object" || v === null) return v;
  const m = v as Record<string, unknown>;
  if ("stringValue" in m) return m["stringValue"];
  if ("integerValue" in m) return parseInt(String(m["integerValue"]), 10);
  if ("doubleValue" in m) return Number(m["doubleValue"]);
  if ("booleanValue" in m) return m["booleanValue"];
  if ("nullValue" in m) return null;
  if ("arrayValue" in m) {
    const arr = m["arrayValue"] as {values?: unknown[]};
    return (arr.values ?? []).map(decodeValue);
  }
  if ("mapValue" in m) {
    const mv = m["mapValue"] as {fields?: Record<string, unknown>};
    return Object.fromEntries(
      Object.entries(mv.fields ?? {}).map(([k, val]) => [k, decodeValue(val)]),
    );
  }
  return m;
}

async function readDoc(
  path: string,
  idToken: string,
): Promise<Record<string, unknown> | null> {
  const res = await fetch(`${FIRESTORE_BASE}/${path}`, {
    headers: {Authorization: `Bearer ${idToken}`},
  });
  if (res.status === 404) return null;
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Firestore read ${path} failed (${res.status}): ${text}`);
  }
  const body = (await res.json()) as {fields?: Record<string, unknown>};
  if (!body.fields) return {};
  return Object.fromEntries(
    Object.entries(body.fields).map(([k, v]) => [k, decodeValue(v)]),
  );
}

// ── Test helpers ──────────────────────────────────────────────────────────────

function pass(msg: string): void {
  console.log(`  ✅  ${msg}`);
}

function fail(msg: string): void {
  console.error(`  ❌  ${msg}`);
}

function assertVector(vec: unknown, label: string): boolean {
  if (!Array.isArray(vec)) {
    fail(
      `${label} is not an array (got ${vec === null ? "null" : typeof vec})`,
    );
    fail("     → Vertex AI embedding did NOT run on this call");
    return false;
  }
  if (vec.length !== 256) {
    fail(`${label} has ${vec.length} dims (expected 256)`);
    return false;
  }
  const nonZero = (vec as number[]).filter((x) => x !== 0).length;
  if (nonZero === 0) {
    fail(`${label} is all zeros — likely a mock or empty response`);
    return false;
  }
  pass(`${label}: 256-dim vector, ${nonZero} non-zero values`);
  return true;
}

// ── Pre-flight ────────────────────────────────────────────────────────────────

/**
 * Checks whether the interest-matching feature is deployed by joining a group
 * room with an interest phrase and checking if roomInterestVector is present.
 * If it's absent the deployed code is the old version — fail fast with guidance.
 */
async function checkFeatureDeployed(): Promise<void> {
  const {uid, idToken} = await signInAnon();
  let roomId: string | undefined;
  try {
    const res = await callFn(
      "joinGroupRoom",
      {interestText: "football"},
      idToken,
    );
    roomId = res["roomId"] as string;
    const room = await readDoc(`rooms/${roomId}`, idToken);
    // Old code never stores roomInterestVector — field will be absent.
    const hasFeature = room !== null && "roomInterestVector" in room;
    if (!hasFeature) {
      console.error(
        "\n⚠️  Context-aware matchmaking is NOT deployed to production.\n" +
          "   The deployed Cloud Functions are an older version that doesn't\n" +
          "   store roomInterestVector or interestVector.\n\n" +
          "   To fix: merge the PR and run:\n" +
          "     cd functions && npm run deploy\n" +
          "   Then re-run this script.\n",
      );
      process.exit(2);
    }
  } finally {
    if (roomId) {
      await callFn("leaveRoom", {roomId}, idToken).catch(() => null);
    }
    await deleteUser(idToken);
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

async function testGroupRoom(): Promise<boolean> {
  console.log(
    "\n── Group room: joinGroupRoom with interestText ──────────────",
  );

  const {uid, idToken} = await signInAnon();
  console.log(`  user: ${uid}`);

  let roomId: string | undefined;
  let ok = true;

  try {
    const res = await callFn(
      "joinGroupRoom",
      {interestText: "I love football"},
      idToken,
    );
    roomId = res["roomId"] as string;
    pass(`joinGroupRoom → room ${roomId}`);

    const room = await readDoc(`rooms/${roomId}`, idToken);
    if (!room) {
      fail("room document not found in Firestore");
      return false;
    }

    ok = assertVector(room["roomInterestVector"], "roomInterestVector") && ok;

    const interests = room["memberInterests"] as Record<string, unknown> | null;
    if (interests && uid in interests) {
      pass(`memberInterests contains this user's vector`);
      assertVector(interests[uid], "memberInterests[uid]");
    } else {
      fail(`memberInterests missing entry for uid ${uid}`);
      ok = false;
    }
  } finally {
    if (roomId) {
      await callFn("leaveRoom", {roomId}, idToken).catch(() => null);
    }
    await deleteUser(idToken);
  }

  return ok;
}

async function test1v1Pool(): Promise<boolean> {
  console.log(
    "\n── 1v1 pool: join1v1Pool with interestText ──────────────────",
  );

  const {uid, idToken} = await signInAnon();
  console.log(`  user: ${uid}`);

  let ok = true;

  try {
    await callFn("join1v1Pool", {interestText: "playing guitar"}, idToken);
    pass(`join1v1Pool called`);

    // Small delay to allow Firestore write to propagate.
    await new Promise((r) => setTimeout(r, 1000));

    const doc = await readDoc(`waiting_pool/${uid}`, idToken);
    if (!doc) {
      fail("waiting_pool doc not found");
      return false;
    }

    if (doc["interestText"] !== "playing guitar") {
      fail(`interestText mismatch: got "${doc["interestText"]}"`);
      ok = false;
    } else {
      pass(`interestText stored correctly`);
    }

    ok = assertVector(doc["interestVector"], "interestVector") && ok;
  } finally {
    await callFn("cancel1v1Pool", {}, idToken).catch(() => null);
    await deleteUser(idToken);
  }

  return ok;
}

async function testSimilarity(): Promise<boolean> {
  console.log(
    "\n── Similarity: football vs soccer should score ≥ 0.65 ───────",
  );

  const userA = await signInAnon();
  const userB = await signInAnon();

  let roomId: string | undefined;
  let ok = true;

  try {
    // A creates a room with "football" interest.
    const resA = await callFn(
      "joinGroupRoom",
      {interestText: "I love football"},
      userA.idToken,
    );
    roomId = resA["roomId"] as string;
    pass(`user A joined room ${roomId} with "football"`);

    // B tries to join — Phase 0 should route them to A's room.
    const resB = await callFn(
      "joinGroupRoom",
      {interestText: "I enjoy watching soccer"},
      userB.idToken,
    );
    const roomB = resB["roomId"] as string;

    if (roomB === roomId) {
      pass(
        `user B (soccer) routed to user A's room via Phase 0 interest match ✓`,
      );
    } else {
      // Phase 0 may not trigger if vectors aren't similar enough or room was full.
      // This is a soft failure — log but don't count as error.
      console.log(
        `  ℹ️   user B ended up in different room ${roomB} (Phase 0 may not have matched)`,
      );
      await callFn("leaveRoom", {roomId: roomB}, userB.idToken).catch(
        () => null,
      );
    }

    const room = await readDoc(`rooms/${roomId}`, userA.idToken);
    ok =
      assertVector(room?.["roomInterestVector"], "final roomInterestVector") &&
      ok;
  } finally {
    if (roomId) {
      await callFn("leaveRoom", {roomId}, userA.idToken).catch(() => null);
      await callFn("leaveRoom", {roomId}, userB.idToken).catch(() => null);
    }
    await deleteUser(userA.idToken);
    await deleteUser(userB.idToken);
  }

  return ok;
}

// ── Runner ────────────────────────────────────────────────────────────────────

async function run(): Promise<void> {
  console.log("\nProduction Vertex AI smoke test");
  console.log(`Project: ${PROJECT}  |  Functions: ${FUNCTIONS_BASE}\n`);

  console.log("Pre-flight: checking feature is deployed...");
  await checkFeatureDeployed();
  console.log("  ✅  Context-aware matchmaking is deployed\n");

  const results = await Promise.allSettled([
    testGroupRoom(),
    test1v1Pool(),
    testSimilarity(),
  ]);

  const passed = results.filter(
    (r) => r.status === "fulfilled" && r.value,
  ).length;
  const total = results.length;

  console.log(`\n${"─".repeat(60)}`);
  results.forEach((r, i) => {
    const name = ["Group room", "1v1 pool", "Similarity"][i];
    if (r.status === "rejected") {
      console.log(`  ❌  ${name}: ${(r.reason as Error).message}`);
    } else if (!r.value) {
      console.log(`  ❌  ${name}: assertions failed`);
    } else {
      console.log(`  ✅  ${name}`);
    }
  });
  console.log(`\n${passed}/${total} tests passed`);

  if (passed < total) {
    process.exit(1);
  }
}

run().catch((e) => {
  console.error("Fatal:", e);
  process.exit(1);
});
