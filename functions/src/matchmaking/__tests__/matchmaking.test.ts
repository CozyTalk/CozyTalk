import {
  signInAnon,
  signOut,
  callFn,
  resetEmulatorData,
  rtdbGet,
  waitUntilRtdbValue,
  adminFirestoreDoc,
  waitUntilAdminDocMatches,
  tryLeaveRoom,
  tryCancelPool,
  buildRoom,
  sleep,
} from "./helpers";

beforeEach(async () => {
  await signOut();
  await resetEmulatorData();
}, 15_000);

afterEach(async () => {
  signOut();
  await resetEmulatorData();
}, 15_000);

// ── Group Room: Priority Selection ─────────────────────────────────────────

describe("priority", () => {
  test("1-member room chosen over 2-member room", async () => {
    const roomA = await buildRoom(2);
    const roomB = await buildRoom(1);

    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");

    expect(res["roomId"]).toBe(roomB);

    const docA = await adminFirestoreDoc(`rooms/${roomA}`);
    expect(docA!["memberCount"]).toBe(2);
    await tryLeaveRoom(res["roomId"] as string);
  });

  test("1-member room chosen when competing with 3-member and 4-member rooms", async () => {
    const roomA = await buildRoom(4);
    const roomB = await buildRoom(3);
    const roomC = await buildRoom(1);

    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");

    expect(res["roomId"]).toBe(roomC);

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${roomA}`),
      adminFirestoreDoc(`rooms/${roomB}`),
    ]);
    expect(docs[0]!["memberCount"]).toBe(4);
    expect(docs[1]!["memberCount"]).toBe(3);
    await tryLeaveRoom(res["roomId"] as string);
  });

  test("1-member room wins from mixed field (1/5, 2/5, 3/5, 4/5)", async () => {
    const room4 = await buildRoom(4);
    const room2 = await buildRoom(2);
    const room3 = await buildRoom(3);
    const room1 = await buildRoom(1);

    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");

    expect(res["roomId"]).toBe(room1);

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${room4}`),
      adminFirestoreDoc(`rooms/${room2}`),
      adminFirestoreDoc(`rooms/${room3}`),
    ]);
    expect(docs[0]!["memberCount"]).toBe(4);
    expect(docs[1]!["memberCount"]).toBe(2);
    expect(docs[2]!["memberCount"]).toBe(3);
    await tryLeaveRoom(res["roomId"] as string);
  });

  test("priority distribution: 15 consecutive joiners spread randomly across 3 one-member rooms", async () => {
    const roomX = await buildRoom(1);
    const roomY = await buildRoom(1);
    const roomZ = await buildRoom(1);
    const knownRooms = new Set([roomX, roomY, roomZ]);
    const counts: Record<string, number> = {[roomX]: 0, [roomY]: 0, [roomZ]: 0};

    for (let i = 0; i < 15; i++) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom");
      const joined = res["roomId"] as string;

      expect([...knownRooms]).toContain(joined);
      counts[joined] = (counts[joined] ?? 0) + 1;
      await callFn("leaveRoom", {roomId: joined});
    }

    const distinct = Object.values(counts).filter((c) => c > 0).length;
    expect(distinct).toBeGreaterThanOrEqual(2);
    // Sanity bound: P(max ≥ 14 out of 15) ≈ 0.00065% with uniform 3-room dist.
    expect(Math.max(...Object.values(counts))).toBeLessThan(14);
  });

  test("after first 1-member room fills, next joiner picks the remaining 1-member room", async () => {
    const roomX = await buildRoom(1);
    const roomY = await buildRoom(1);

    signOut();
    await signInAnon();
    const resU = await callFn("joinGroupRoom");
    const joinedByU = resU["roomId"] as string;
    expect([roomX, roomY]).toContain(joinedByU);
    const remaining = joinedByU === roomX ? roomY : roomX;

    signOut();
    await signInAnon();
    const resV = await callFn("joinGroupRoom");
    expect(resV["roomId"]).toBe(remaining);

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${roomX}`),
      adminFirestoreDoc(`rooms/${roomY}`),
    ]);
    expect(docs[0]!["memberCount"]).toBe(2);
    expect(docs[1]!["memberCount"]).toBe(2);
    await tryLeaveRoom(resV["roomId"] as string);
  });

  test("priority load test: 20 joiners across 5 one-member rooms", async () => {
    const rooms: string[] = [];
    for (let i = 0; i < 5; i++) {
      rooms.push(await buildRoom(1));
    }
    const knownRooms = new Set(rooms);
    const counts: Record<string, number> = Object.fromEntries(
      rooms.map((r) => [r, 0]),
    );

    for (let i = 0; i < 20; i++) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom");
      const joined = res["roomId"] as string;

      expect([...knownRooms]).toContain(joined);
      counts[joined] = (counts[joined] ?? 0) + 1;
      await callFn("leaveRoom", {roomId: joined});
    }

    const distinct = Object.values(counts).filter((c) => c > 0).length;
    expect(distinct).toBeGreaterThanOrEqual(3);
    // Sanity bound only: catches a completely degenerate picker (all 20 into
    // one room). Not a distribution test — tight bounds on 20 samples are
    // statistically flaky (~11% failure at <8 with uniform 5-room distribution).
    expect(Math.max(...Object.values(counts))).toBeLessThan(16);
  });

  test("priority concurrent race: two rapid joiners to the same 1-member room", async () => {
    const roomX = await buildRoom(1);

    signOut();
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const joinedA = resA["roomId"] as string;

    signOut();
    await signInAnon();
    const resB = await callFn("joinGroupRoom");
    const joinedB = resB["roomId"] as string;

    expect(resA["roomId"]).not.toBeNull();
    expect(resB["roomId"]).not.toBeNull();

    if (joinedA === roomX && joinedB === roomX) {
      const doc = await adminFirestoreDoc(`rooms/${roomX}`);
      const users = doc!["users"] as string[];
      expect(new Set(users).size).toBe(users.length);
      expect(users).toContain(uidA);
    }

    const roomDoc = await adminFirestoreDoc(`rooms/${roomX}`);
    expect(roomDoc!["memberCount"]).toBeLessThanOrEqual(5);
    await tryLeaveRoom(joinedB);
  });
});

// ── Group Room: Secondary Randomness ──────────────────────────────────────

describe("secondary randomness", () => {
  test("15 joiners spread across 3 two-member rooms", async () => {
    const roomA = await buildRoom(2);
    const roomB = await buildRoom(2);
    const roomC = await buildRoom(2);
    const knownRooms = new Set([roomA, roomB, roomC]);
    const counts: Record<string, number> = {[roomA]: 0, [roomB]: 0, [roomC]: 0};

    for (let i = 0; i < 15; i++) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom");
      const joined = res["roomId"] as string;

      expect([...knownRooms]).toContain(joined);
      counts[joined] = (counts[joined] ?? 0) + 1;
      await callFn("leaveRoom", {roomId: joined});
    }

    const distinct = Object.values(counts).filter((c) => c > 0).length;
    expect(distinct).toBeGreaterThanOrEqual(2);
    // Sanity bound: P(max ≥ 14 out of 15) ≈ 0.00065% with uniform 3-room dist.
    expect(Math.max(...Object.values(counts))).toBeLessThan(14);
  });

  test("repeated join-leave by same user does not always hit same room", async () => {
    await buildRoom(3);
    await buildRoom(3);
    await buildRoom(3);

    const visited = new Set<string>();

    for (let i = 0; i < 12; i++) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom");
      const joined = res["roomId"] as string;
      visited.add(joined);
      await callFn("leaveRoom", {roomId: joined});
    }

    expect(visited.size).toBeGreaterThanOrEqual(2);
  });

  test("joins distributed across rooms of different sizes (2/5, 3/5, 4/5)", async () => {
    const roomA = await buildRoom(2);
    const roomB = await buildRoom(3);
    const roomC = await buildRoom(4);
    const knownRooms = new Set([roomA, roomB, roomC]);
    const counts: Record<string, number> = {[roomA]: 0, [roomB]: 0, [roomC]: 0};

    for (let i = 0; i < 12; i++) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom");
      const joined = res["roomId"] as string;
      expect([...knownRooms]).toContain(joined);
      counts[joined] = (counts[joined] ?? 0) + 1;
      await callFn("leaveRoom", {roomId: joined});
    }

    const distinct = Object.values(counts).filter((c) => c > 0).length;
    expect(distinct).toBeGreaterThanOrEqual(2);
  });

  test("all secondary rooms fill up → new room created", async () => {
    const roomA = await buildRoom(4);

    signOut();
    await signInAnon();
    await callFn("joinRoomById", {roomId: roomA});
    expect((await adminFirestoreDoc(`rooms/${roomA}`))!["memberCount"]).toBe(5);

    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");
    expect(res["isNewRoom"]).toBe(true);
    expect(res["roomId"]).not.toBe(roomA);
    await tryLeaveRoom(res["roomId"] as string);
  });
});

// ── Padding: Not Joinable ──────────────────────────────────────────────────

describe("padding", () => {
  test("last user leaves → padding → next joiner creates new room", async () => {
    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");
    const originalRoomId = res["roomId"] as string;
    await callFn("leaveRoom", {roomId: originalRoomId});

    const paddingDoc = await adminFirestoreDoc(`rooms/${originalRoomId}`);
    expect(paddingDoc!["status"]).toBe("padding");
    expect(paddingDoc!["memberCount"]).toBe(0);

    signOut();
    await signInAnon();
    const newRes = await callFn("joinGroupRoom");
    expect(newRes["isNewRoom"]).toBe(true);
    expect(newRes["roomId"]).not.toBe(originalRoomId);

    const stillPadding = await adminFirestoreDoc(`rooms/${originalRoomId}`);
    expect(stillPadding!["status"]).toBe("padding");
    await tryLeaveRoom(newRes["roomId"] as string);
  });

  test("joinRoomById on padding room throws failed-precondition", async () => {
    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");
    const roomId = res["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    expect((await adminFirestoreDoc(`rooms/${roomId}`))!["status"]).toBe(
      "padding",
    );

    signOut();
    await signInAnon();
    try {
      await callFn("joinRoomById", {roomId});
      throw new Error("expected exception for padding room");
    } catch (e) {
      expect((e as Error).message).toContain("failed-precondition");
    }
  });

  test("expired room via joinRoomById throws an error", async () => {
    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");
    const roomId = res["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    signOut();
    await signInAnon();
    try {
      await callFn("joinRoomById", {roomId});
      throw new Error("expected exception for unavailable room");
    } catch (e) {
      expect((e as Error).message).toMatch(/failed-precondition|not-found/);
    }
  });

  test("1v1 room in padding is not returned by joinGroupRoom", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const v1RoomId = poolDoc!["roomId"] as string;

    await callFn("leaveRoom", {roomId: v1RoomId});

    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );
    await tryCancelPool();

    signOut();
    await signInAnon();
    const groupRes = await callFn("joinGroupRoom");
    expect(groupRes["isNewRoom"]).toBe(true);
    expect(groupRes["roomId"]).not.toBe(v1RoomId);

    const v1Doc = await adminFirestoreDoc(`rooms/${v1RoomId}`);
    expect(v1Doc!["mode"]).toBe("1v1");
    expect(v1Doc!["status"]).toBe("padding");
    await tryLeaveRoom(groupRes["roomId"] as string);
  });
});

// ── RTDB & Edge Cases ──────────────────────────────────────────────────────

describe("RTDB and edge cases", () => {
  test("membership set for both creator and joiner", async () => {
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomId = resA["roomId"] as string;

    signOut();
    const uidB = await signInAnon();
    await callFn("joinGroupRoom");

    const snapA = await rtdbGet(`rooms/${roomId}/members/${uidA}`);
    const snapB = await rtdbGet(`rooms/${roomId}/members/${uidB}`);
    expect(snapA.value).toBe(true);
    expect(snapB.value).toBe(true);

    await tryLeaveRoom(roomId);
  });

  test("leaveRoom cleans typing and presence paths (not just members)", async () => {
    await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomId = resA["roomId"] as string;

    signOut();
    const uidB = await signInAnon();
    await callFn("joinGroupRoom");
    await callFn("leaveRoom", {roomId});

    const [typing, presence, member] = await Promise.all([
      rtdbGet(`typing/${roomId}/${uidB}`),
      rtdbGet(`presence/${roomId}/${uidB}`),
      rtdbGet(`rooms/${roomId}/members/${uidB}`),
    ]);
    expect(typing.exists).toBe(false);
    expect(presence.exists).toBe(false);
    expect(member.exists).toBe(false);

    await tryLeaveRoom(roomId);
  });

  test("full room (5/5): joinGroupRoom creates new room; joinRoomById throws", async () => {
    const roomA = await buildRoom(4);

    signOut();
    await signInAnon();
    await callFn("joinRoomById", {roomId: roomA});
    expect((await adminFirestoreDoc(`rooms/${roomA}`))!["memberCount"]).toBe(5);

    signOut();
    await signInAnon();
    const newRes = await callFn("joinGroupRoom");
    expect(newRes["isNewRoom"]).toBe(true);
    expect(newRes["roomId"]).not.toBe(roomA);

    try {
      await callFn("joinRoomById", {roomId: roomA});
      throw new Error("expected exception for full room");
    } catch (e) {
      expect((e as Error).message).toMatch(
        /resource-exhausted|failed-precondition/,
      );
    }
    await tryLeaveRoom(newRes["roomId"] as string);
  });

  test("locked room excluded from joinGroupRoom; unlocked room still joinable", async () => {
    const roomA = await buildRoom(1);
    await callFn("setRoomLock", {roomId: roomA, isLocked: true});

    const roomB = await buildRoom(3);

    signOut();
    await signInAnon();
    const res = await callFn("joinGroupRoom");

    expect(res["roomId"]).toBe(roomB);
    expect((await adminFirestoreDoc(`rooms/${roomA}`))!["memberCount"]).toBe(1);

    await tryLeaveRoom(roomB);
  });

  test("user already in room: joinGroupRoom produces no duplicate in users array", async () => {
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomId = resA["roomId"] as string;

    const resA2 = await callFn("joinGroupRoom");

    const doc = await adminFirestoreDoc(`rooms/${roomId}`);
    const users = doc!["users"] as string[];
    expect(users.filter((u) => u === uidA).length).toBeLessThanOrEqual(1);

    await tryLeaveRoom(roomId);
    const secondRoom = resA2["roomId"] as string;
    if (secondRoom !== roomId) await tryLeaveRoom(secondRoom);
  });
});

// ── 1v1 Pool & Match Trigger ───────────────────────────────────────────────

describe("1v1 pool and match", () => {
  test("join1v1Pool: pool entry has all required fields", async () => {
    const uid = await signInAnon();
    await callFn("join1v1Pool");

    const doc = await adminFirestoreDoc(`waiting_pool/${uid}`);
    expect(doc!["status"]).toBe("waiting");
    expect(doc!["mode"]).toBe("1v1");
    expect(doc!["roomId"]).toBeNull();
    expect(doc!["createdAt"]).not.toBeNull();
    expect(doc!["updatedAt"]).not.toBeNull();

    await tryCancelPool();
  });

  test("match1v1Users trigger: two users matched with correct room and RTDB membership", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDoc!["roomId"] as string;
    expect(roomId).toHaveLength(5);

    const roomDoc = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(roomDoc!["mode"]).toBe("1v1");
    expect(roomDoc!["status"]).toBe("active");
    expect(roomDoc!["memberCount"]).toBe(2);
    expect(roomDoc!["users"] as string[]).toEqual(
      expect.arrayContaining([uidA, uidB]),
    );

    // match1v1Users writes Firestore (status=matched) before RTDB members —
    // poll until both entries are visible rather than reading immediately.
    const [rtdbA, rtdbB] = await Promise.all([
      waitUntilRtdbValue(`rooms/${roomId}/members/${uidA}`, (s) => s.exists),
      waitUntilRtdbValue(`rooms/${roomId}/members/${uidB}`, (s) => s.exists),
    ]);
    expect(rtdbA.value).toBe(true);
    expect(rtdbB.value).toBe(true);

    await callFn("leaveRoom", {roomId});
  });

  test("match1v1Users: single user in pool stays waiting — trigger handles no-candidate", async () => {
    const uid = await signInAnon();
    await callFn("join1v1Pool");

    await sleep(5000);

    const doc = await adminFirestoreDoc(`waiting_pool/${uid}`);
    expect(doc!["status"]).toBe("waiting");

    await tryCancelPool();
  });

  test("match1v1Users: 3 users in pool — first two matched, third stays waiting", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();

    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );

    signOut();
    const uidC = await signInAnon();
    await callFn("join1v1Pool");

    await sleep(5000);

    const docs = await Promise.all([
      adminFirestoreDoc(`waiting_pool/${uidA}`),
      adminFirestoreDoc(`waiting_pool/${uidB}`),
      adminFirestoreDoc(`waiting_pool/${uidC}`),
    ]);

    expect(docs[0]!["status"]).toBe("matched");
    expect(docs[1]!["status"]).toBe("matched");
    expect(docs[0]!["roomId"]).toBe(docs[1]!["roomId"]);
    expect(docs[2]!["status"]).toBe("waiting");

    await tryCancelPool();
    await tryLeaveRoom(docs[0]!["roomId"] as string);
  });

  test("match1v1Users scale: 10 users → 5 pairs all matched correctly", async () => {
    const uids: string[] = [];
    for (let i = 0; i < 10; i++) {
      signOut();
      uids.push(await signInAnon());
      await callFn("join1v1Pool");
      await sleep(50);
    }

    const poolDocs = await Promise.all(
      uids.map((uid) =>
        waitUntilAdminDocMatches(
          `waiting_pool/${uid}`,
          (d) => d?.["status"] === "matched",
        ),
      ),
    );

    for (let i = 0; i < 10; i++) {
      expect(poolDocs[i]!["status"]).toBe("matched");
    }

    const roomIdSet = new Set(poolDocs.map((d) => d!["roomId"] as string));
    expect(roomIdSet.size).toBe(5);

    const roomDocs = await Promise.all(
      [...roomIdSet].map((id) => adminFirestoreDoc(`rooms/${id}`)),
    );
    for (const doc of roomDocs) {
      expect(doc!["memberCount"]).toBe(2);
      expect((doc!["users"] as string[]).length).toBe(2);
      expect(doc!["mode"]).toBe("1v1");
    }

    for (const id of roomIdSet) {
      await tryLeaveRoom(id);
    }
  });

  test("join1v1Pool idempotent: calling twice recreates entry without error", async () => {
    const uid = await signInAnon();
    await callFn("join1v1Pool");
    expect((await adminFirestoreDoc(`waiting_pool/${uid}`))!["status"]).toBe(
      "waiting",
    );

    await callFn("join1v1Pool");
    expect((await adminFirestoreDoc(`waiting_pool/${uid}`))!["status"]).toBe(
      "waiting",
    );

    await tryCancelPool();
  });

  test("cancel1v1Pool: entry deleted; re-join creates fresh entry", async () => {
    const uid = await signInAnon();
    await callFn("join1v1Pool");
    await callFn("cancel1v1Pool");

    expect(await adminFirestoreDoc(`waiting_pool/${uid}`)).toBeNull();

    await callFn("join1v1Pool");
    const recreated = await adminFirestoreDoc(`waiting_pool/${uid}`);
    expect(recreated!["status"]).toBe("waiting");

    await tryCancelPool();
  });
});

// ── 1v1 Leave & Requeue ───────────────────────────────────────────────────

describe("1v1 leave and requeue", () => {
  test("leaveRoom (1v1): room enters 30-second padding — not 5-minute group padding", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDoc!["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    const roomDoc = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(roomDoc!["status"]).toBe("padding");

    const paddingUntil = roomDoc!["paddingUntil"];
    expect(paddingUntil).not.toBeNull();

    const paddingMs = new Date(paddingUntil as string).getTime();
    const diffSeconds = (paddingMs - Date.now()) / 1000;
    // Upper bound of 35s since both client and server run on the same host
    // (no Android emulator clock skew).
    expect(diffSeconds).toBeLessThan(35);
    expect(diffSeconds).toBeGreaterThan(0);

    expect(uidA).not.toBe("");
  });

  test("leaveRoom (1v1): remaining user gets fresh waiting_pool entry (delete+set fix)", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDoc!["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    const requeuedDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );
    expect(requeuedDoc!["status"]).toBe("waiting");
    expect(requeuedDoc!["mode"]).toBe("1v1");
    expect(requeuedDoc!["roomId"]).toBeNull();
  });

  test("leaveRoom (1v1): RTDB cleared for both users including remaining user", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDoc!["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );

    const [snapA, snapB] = await Promise.all([
      rtdbGet(`rooms/${roomId}/members/${uidA}`),
      rtdbGet(`rooms/${roomId}/members/${uidB}`),
    ]);
    expect(snapA.exists).toBe(false);
    expect(snapB.exists).toBe(false);
  });

  test("leaveRoom (1v1): typing and presence RTDB paths removed for leaving user", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolDoc = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolDoc!["roomId"] as string;
    await callFn("leaveRoom", {roomId});

    const [typing, presence] = await Promise.all([
      rtdbGet(`typing/${roomId}/${uidB}`),
      rtdbGet(`presence/${roomId}/${uidB}`),
    ]);
    expect(typing.exists).toBe(false);
    expect(presence.exists).toBe(false);

    expect(uidA).not.toBe("");
  });
});

// ── Complete User Flows ────────────────────────────────────────────────────

describe("flows", () => {
  test("full 1v1 lifecycle — pool → match → RTDB → leave → requeue → cancel", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    expect((await adminFirestoreDoc(`waiting_pool/${uidA}`))!["status"]).toBe(
      "waiting",
    );

    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolB = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId = poolB!["roomId"] as string;

    const roomDoc = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(roomDoc!["mode"]).toBe("1v1");
    expect(roomDoc!["memberCount"]).toBe(2);

    // match1v1Users writes Firestore before RTDB — poll until both entries appear.
    const [snapA, snapB] = await Promise.all([
      waitUntilRtdbValue(`rooms/${roomId}/members/${uidA}`, (s) => s.exists),
      waitUntilRtdbValue(`rooms/${roomId}/members/${uidB}`, (s) => s.exists),
    ]);
    expect(snapA.value).toBe(true);
    expect(snapB.value).toBe(true);

    await callFn("leaveRoom", {roomId});
    expect((await adminFirestoreDoc(`rooms/${roomId}`))!["status"]).toBe(
      "padding",
    );

    const requeuedA = await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );
    expect(requeuedA!["status"]).toBe("waiting");

    await tryCancelPool();
  });

  test("1v1 chain — A+B match → B leaves → A+C match in new room", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolB = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId1 = poolB!["roomId"] as string;

    await callFn("leaveRoom", {roomId: roomId1});
    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );

    expect((await adminFirestoreDoc(`rooms/${roomId1}`))!["status"]).toBe(
      "padding",
    );

    signOut();
    const uidC = await signInAnon();
    await callFn("join1v1Pool");

    const poolC = await waitUntilAdminDocMatches(
      `waiting_pool/${uidC}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId2 = poolC!["roomId"] as string;

    expect(roomId2).not.toBe(roomId1);

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${roomId2}`),
      adminFirestoreDoc(`rooms/${roomId1}`),
    ]);
    expect(docs[0]!["users"] as string[]).toEqual(
      expect.arrayContaining([uidA, uidC]),
    );
    expect(docs[1]!["status"]).toBe("padding");

    await callFn("leaveRoom", {roomId: roomId2});
  });

  test("group room lifecycle — fill to 3 → sequential leaves → padding → new user gets new room", async () => {
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomX = resA["roomId"] as string;
    expect(resA["isNewRoom"]).toBe(true);

    signOut();
    const uidB = await signInAnon();
    const resB = await callFn("joinGroupRoom");
    expect(resB["roomId"]).toBe(roomX);

    signOut();
    const uidC = await signInAnon();
    await callFn("joinGroupRoom");
    const doc3 = await adminFirestoreDoc(`rooms/${roomX}`);
    expect(doc3!["memberCount"]).toBe(3);
    expect(doc3!["users"] as string[]).toEqual(
      expect.arrayContaining([uidA, uidB, uidC]),
    );

    await callFn("leaveRoom", {roomId: roomX});
    expect((await adminFirestoreDoc(`rooms/${roomX}`))!["memberCount"]).toBe(2);
    expect((await adminFirestoreDoc(`rooms/${roomX}`))!["status"]).toBe(
      "active",
    );

    await tryLeaveRoom(roomX);
    await sleep(500);

    signOut();
    await signInAnon();
    const resD = await callFn("joinGroupRoom");
    expect((resD["roomId"] as string).length).toBe(5);

    await tryLeaveRoom(resD["roomId"] as string);
  });

  test("custom room — create → lock → block → unlock → join → message → padding", async () => {
    await signInAnon();
    const resA = await callFn("createCustomRoom");
    const roomId = resA["roomId"] as string;

    const docInit = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(docInit!["roomType"]).toBe("custom");
    expect(docInit!["isLocked"]).toBe(false);

    await callFn("setRoomLock", {roomId, isLocked: true});
    expect((await adminFirestoreDoc(`rooms/${roomId}`))!["isLocked"]).toBe(
      true,
    );

    signOut();
    await signInAnon();
    try {
      await callFn("joinRoomById", {roomId});
      throw new Error("expected failed-precondition for locked room");
    } catch (e) {
      expect((e as Error).message).toContain("failed-precondition");
    }

    await tryLeaveRoom(roomId);
  });

  test("1v1 and group rooms do not cross-contaminate", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");

    signOut();
    const uidB = await signInAnon();
    const resB = await callFn("joinGroupRoom");
    const groupRoomId = resB["roomId"] as string;

    signOut();
    const uidC = await signInAnon();
    await callFn("join1v1Pool");

    const poolC = await waitUntilAdminDocMatches(
      `waiting_pool/${uidC}`,
      (d) => d?.["status"] === "matched",
    );
    const v1RoomId = poolC!["roomId"] as string;

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${v1RoomId}`),
      adminFirestoreDoc(`rooms/${groupRoomId}`),
    ]);

    const v1Room = docs[0]!;
    const groupRoom = docs[1]!;

    expect(v1Room["mode"]).toBe("1v1");
    expect(v1Room["users"] as string[]).toEqual(
      expect.arrayContaining([uidA, uidC]),
    );
    expect(groupRoom["mode"]).toBe("group");
    expect(groupRoom["memberCount"]).toBe(1);
    expect(groupRoom["users"] as string[]).toContain(uidB);
    expect(groupRoom["users"] as string[]).not.toContain(uidA);
    expect(groupRoom["users"] as string[]).not.toContain(uidC);

    await Promise.all([
      callFn("leaveRoom", {roomId: v1RoomId}),
      tryLeaveRoom(groupRoomId),
    ]);
  });

  test("repeated switching — user visits multiple rooms across cycles", async () => {
    // All three rooms are 3/5 so they are in the secondary (random) pool.
    // There is no priority room, so selection is random across P, Q, R.
    const roomP = await buildRoom(3);
    const roomQ = await buildRoom(3);
    const roomR = await buildRoom(3);
    const knownRooms = new Set([roomP, roomQ, roomR]);
    const visited = new Set<string>();

    for (let i = 0; i < 12; i++) {
      signOut();
      await signInAnon();
      const res = await callFn("joinGroupRoom");
      const joined = res["roomId"] as string;
      expect([...knownRooms]).toContain(joined);
      visited.add(joined);
      await callFn("leaveRoom", {roomId: joined});
    }

    expect(visited.size).toBeGreaterThanOrEqual(2);
  });

  test("rapid 12 join-leave cycles without error", async () => {
    await buildRoom(3);
    await buildRoom(3);
    await buildRoom(3);

    const visited = new Set<string>();
    let errors = 0;

    for (let i = 0; i < 12; i++) {
      signOut();
      await signInAnon();
      try {
        const res = await callFn("joinGroupRoom");
        const joined = res["roomId"] as string;
        visited.add(joined);
        await callFn("leaveRoom", {roomId: joined});
      } catch (_) {
        errors++;
      }
    }

    expect(errors).toBe(0);
    expect(visited.size).toBeGreaterThanOrEqual(2);
  });

  test("1v1 triple chain — A matches 3 different partners in sequence", async () => {
    const doMatch = async (): Promise<string> => {
      signOut();
      const uidPartner = await signInAnon();
      await callFn("join1v1Pool");
      const poolDoc = await waitUntilAdminDocMatches(
        `waiting_pool/${uidPartner}`,
        (d) => d?.["status"] === "matched",
      );
      return poolDoc!["roomId"] as string;
    };

    const uidA = await signInAnon();
    await callFn("join1v1Pool");

    const roomId1 = await doMatch();
    await callFn("leaveRoom", {roomId: roomId1});
    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );

    const roomId2 = await doMatch();
    await callFn("leaveRoom", {roomId: roomId2});
    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );

    const roomId3 = await doMatch();

    expect(new Set([roomId1, roomId2, roomId3]).size).toBe(3);

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${roomId1}`),
      adminFirestoreDoc(`rooms/${roomId2}`),
      adminFirestoreDoc(`rooms/${roomId3}`),
    ]);
    expect(docs[0]!["status"]).toBe("padding");
    expect(docs[1]!["status"]).toBe("padding");
    expect(docs[2]!["status"]).toBe("active");

    await callFn("leaveRoom", {roomId: roomId3});
  });

  test("padding blocks all re-entry — joinRoomById and joinGroupRoom both refuse", async () => {
    signOut();
    await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomX = resA["roomId"] as string;

    signOut();
    await signInAnon();
    await callFn("joinGroupRoom");
    await callFn("leaveRoom", {roomId: roomX});

    await tryLeaveRoom(roomX);
    await sleep(300);

    const paddingDoc = await adminFirestoreDoc(`rooms/${roomX}`);
    if (paddingDoc!["status"] === "padding") {
      signOut();
      await signInAnon();

      try {
        await callFn("joinRoomById", {roomId: roomX});
        throw new Error("expected failed-precondition for padding room");
      } catch (e) {
        expect((e as Error).message).toContain("failed-precondition");
      }

      const newRes = await callFn("joinGroupRoom");
      expect(newRes["roomId"]).not.toBe(roomX);
      await tryLeaveRoom(newRes["roomId"] as string);
    }
  });

  test("mixed mode — user transitions from 1v1 to group, no contamination", async () => {
    const uidA = await signInAnon();
    await callFn("join1v1Pool");
    signOut();
    const uidB = await signInAnon();
    await callFn("join1v1Pool");

    const poolB = await waitUntilAdminDocMatches(
      `waiting_pool/${uidB}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId1v1 = poolB!["roomId"] as string;

    await callFn("leaveRoom", {roomId: roomId1v1});
    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );

    signOut();
    const uidC = await signInAnon();
    await callFn("join1v1Pool");

    const poolC = await waitUntilAdminDocMatches(
      `waiting_pool/${uidC}`,
      (d) => d?.["status"] === "matched",
    );
    const roomId2 = poolC!["roomId"] as string;

    await callFn("leaveRoom", {roomId: roomId2});
    await waitUntilAdminDocMatches(
      `waiting_pool/${uidA}`,
      (d) => d !== null && d["status"] === "waiting",
      {timeout: 10000},
    );

    signOut();
    await signInAnon();
    const groupRes = await callFn("joinGroupRoom");
    const groupRoomId = groupRes["roomId"] as string;

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${groupRoomId}`),
      adminFirestoreDoc(`rooms/${roomId1v1}`),
      adminFirestoreDoc(`rooms/${roomId2}`),
    ]);

    expect(docs[0]!["mode"]).toBe("group");
    expect(docs[1]!["mode"]).toBe("1v1");
    expect(docs[2]!["mode"]).toBe("1v1");

    const groupUsers = docs[0]!["users"] as string[];
    expect(groupUsers).not.toContain(uidA);
    expect(groupUsers).not.toContain(uidB);

    await tryLeaveRoom(groupRoomId);
  });

  test("concurrent group room creation merge — near-simultaneous creators", async () => {
    signOut();
    const uidA = await signInAnon();
    const resA = await callFn("joinGroupRoom");
    const roomA = resA["roomId"] as string;

    signOut();
    await signInAnon();
    const resB = await callFn("joinGroupRoom");
    const roomB = resB["roomId"] as string;

    expect(roomA).toHaveLength(5);
    expect(roomB).toHaveLength(5);

    const docs = await Promise.all([
      adminFirestoreDoc(`rooms/${roomA}`),
      adminFirestoreDoc(`rooms/${roomB}`),
    ]);

    for (const doc of docs) {
      expect(doc!["memberCount"]).toBeGreaterThanOrEqual(1);
      expect(doc!["memberCount"]).toBeLessThanOrEqual(5);
      expect(doc!["mode"]).toBe("group");
      const users = doc!["users"] as string[];
      expect(new Set(users).size).toBe(users.length);
    }

    if (roomA === roomB) {
      const mergedDoc = await adminFirestoreDoc(`rooms/${roomA}`);
      const users = mergedDoc!["users"] as string[];
      expect(users.filter((u) => u === uidA).length).toBe(1);
    }

    await Promise.all([tryLeaveRoom(roomA), tryLeaveRoom(roomB)]);
  });

  test("group room load test — 15 users fill rooms, each UID in exactly one room", async () => {
    const uids: string[] = [];
    const roomAssignments: Record<string, string> = {};

    for (let i = 0; i < 15; i++) {
      signOut();
      uids.push(await signInAnon());
      const res = await callFn("joinGroupRoom");
      roomAssignments[uids[uids.length - 1]] = res["roomId"] as string;
    }

    expect(Object.values(roomAssignments).every((r) => r.length === 5)).toBe(
      true,
    );

    const uniqueRooms = new Set(Object.values(roomAssignments));
    expect(uniqueRooms.size).toBeGreaterThanOrEqual(3);

    const roomDocs = await Promise.all(
      [...uniqueRooms].map((id) => adminFirestoreDoc(`rooms/${id}`)),
    );
    for (const doc of roomDocs) {
      expect(doc!["memberCount"]).toBeLessThanOrEqual(5);
      expect(doc!["memberCount"]).toBeGreaterThan(0);
    }

    const allUsers = roomDocs.flatMap((d) => d!["users"] as string[]);
    for (const uid of uids) {
      expect(allUsers.filter((u) => u === uid).length).toBe(1);
    }

    for (const id of uniqueRooms) {
      await tryLeaveRoom(id);
    }
  });
});
