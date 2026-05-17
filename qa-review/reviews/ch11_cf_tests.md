# Chapter 11 — Cloud Functions Tests QA Review

> Status: COMPLETE
> Reviewer: qa-agent-phase3
> Date: 2026-05-17

## Summary

Reviewed all CF test infrastructure: `matchmaking.test.ts` (60 tests, 14 describe groups), `embeddingService.test.ts` (21 tests), `chat.test.ts` (11 tests), `embeddingService.integration.test.ts` (7 tests), `helpers.ts`, both Jest configs, `tsconfig.test.json`, and `eslint.config.mjs`. Jest configuration is correct. Embedding and matchmaking test coverage is comprehensive. One HIGH gap: `endSession` has no test for the `rooms/` path (the Phase 1 fix) — only the `active_sessions` path is covered. One MEDIUM concern: ESLint is excluded from all `__tests__/**` files, leaving test code unchecked for type safety and style.

**Findings by severity:** HIGH 1 · MEDIUM 1 · LOW 1 · INFO 2

---

## Findings

### F-001 — `endSession` has no test for `rooms/` path
- **Severity:** HIGH
- **File:** `functions/src/chat/__tests__/chat.test.ts` lines 187–227
- **Category:** Missing Test
- **Description:** Phase 1 fixed `endSession.ts` to support both `rooms/` (new matchmaking) and `active_sessions/` (legacy proto-session). All three `endSession` tests in `chat.test.ts` set up `active_sessions/${sessionId}` docs and test only that path. There is no test that:
  1. Creates a `rooms/${roomId}` document
  2. Calls `endSession({sessionId: roomId})`
  3. Verifies the room is tombstoned (`status: "expired"`, `users: []`)
  4. Verifies RTDB rooms membership is cleaned up
  5. Verifies `session_keys` is written
  If the `rooms/` branch regresses, all tests still pass.
- **Evidence:** `chat.test.ts:187–227` — `adminFirestoreSet('active_sessions/${sessionId}', ...)` is the only setup pattern; no `rooms/` setup or assertion.
- **Recommendation:** Add a test in the `"session_keys TTL"` or `"Privacy by Design"` describe block:
  ```typescript
  test("endSession tombstones new-style room and cleans up RTDB", async () => {
    const roomId = await buildRoom(2); // creates rooms/{roomId} via createCustomRoom
    await callFn("endSession", {sessionId: roomId});
    const roomDoc = await adminFirestoreDoc(`rooms/${roomId}`);
    expect(roomDoc?.["status"]).toBe("expired");
    expect(roomDoc?.["users"]).toEqual([]);
    const rtdbRoom = await rtdbGet(`rooms/${roomId}`);
    expect(rtdbRoom.exists).toBe(false);
  });
  ```

---

### F-002 — ESLint excludes all `__tests__/**` — test code has no type or style enforcement
- **Severity:** MEDIUM
- **File:** `functions/eslint.config.mjs` line 7
- **Category:** Style / Maintenance
- **Description:** `eslint.config.mjs` has `ignores: [..., "src/**/__tests__/**"]`. This means TypeScript type checking (`@typescript-eslint/no-explicit-any`, `no-unused-vars`, etc.) and code style rules (double quotes, trailing commas, no implicit `any`) are NOT enforced in any test file. The `helpers.ts` file is notably large (300+ lines) and type-correct, but future additions to test files could introduce `any` types or implicit return types without CI catching them.
- **Evidence:** `eslint.config.mjs:7` — `"src/**/__tests__/**"` in the `ignores` array.
- **Recommendation:** The exclusion is intentional (noted in `jest.config.js` comment context). If retaining it, add a comment explaining why (common reason: test-specific patterns like `jest.fn<any>()` are hard to type strictly). Alternatively, create a less strict lint config for `__tests__/**` that keeps `no-explicit-any` but relaxes other rules.

---

### F-003 — `embeddingService.integration.test.ts` timeout of 30s may be too tight
- **Severity:** LOW
- **File:** `functions/jest.integration.config.js`
- **Category:** Style
- **Description:** Integration tests call live Vertex AI (`text-multilingual-embedding-002`). The timeout is 30s per test. Vertex AI response times are typically 2–5s in the same region, but cold starts or elevated load could push individual tests close to 30s. The unit test timeout is 60s, making integration tests shorter-budgeted despite being slower.
- **Evidence:** `jest.integration.config.js` — `testTimeout: 30_000`; `jest.config.js` — `testTimeout: 60_000`.
- **Recommendation:** Increase integration test timeout to 60s to match unit tests.

---

### F-004 — Manual test scripts (`testEmbeddingLive.ts`, `testProdVertexAI.ts`) are not in Jest pattern but live in `__tests__/`
- **Severity:** INFO
- **File:** `functions/src/matchmaking/__tests__/testEmbeddingLive.ts`, `testProdVertexAI.ts`
- **Category:** Style
- **Description:** These are `ts-node` manual scripts, not Jest tests. They do not match the `*.test.ts` pattern so they will never run via `npm test`. No hardcoded credentials (they use `process.env.GCLOUD_PROJECT` and `gcloud auth application-default login`). The `console.log` spam is expected for manual scripts and does not affect Jest runs.
- **Evidence:** File names end in `.ts` not `.test.ts`; confirmed excluded from Jest pattern.
- **Recommendation:** None required. Optionally move them to `tools/` or `scripts/` at the repo root to signal they are not test files. A `README.md` comment in `__tests__/` explaining the two scripts would help new contributors.

---

### F-005 — CLAUDE.md test count description mixes unit and integration
- **Severity:** INFO
- **File:** `CLAUDE.md` — Cloud Functions section
- **Category:** Doc-Drift
- **Description:** CLAUDE.md states "99 unit tests total across three files." But 60 + 21 + 11 = 92 unit tests. The total of 99 comes from adding 7 integration tests. The breakdown is accurate but the "unit tests total" label is wrong.
- **Evidence:** `matchmaking.test.ts`: 60, `embeddingService.test.ts`: 21, `chat.test.ts`: 11 → sum: 92. Integration: 7. Grand total: 99.
- **Recommendation:** Update CLAUDE.md: "92 unit tests (matchmaking.test.ts: 60, embeddingService.test.ts: 21, chat.test.ts: 11) + 7 integration tests in `embeddingService.integration.test.ts` = 99 total."

---

## Jest Configuration Audit

| Check | Result |
|-------|--------|
| `jest.config.js` excludes `.integration.test.ts` | ✅ `testPathIgnorePatterns: [..., "\\.integration\\.test\\.ts$"]` |
| `jest.config.js` uses `maxWorkers: 1` | ✅ Prevents emulator state conflicts |
| Unit test timeout | ✅ 60,000ms |
| Integration test timeout | ⚠️ 30,000ms (LOW — may be tight) |
| TypeScript preset | ✅ `ts-jest` |
| `tsconfig.test.json` includes `__tests__/` | ✅ `"include": ["src/**/__tests__/**/*.ts"]` |
| `tsconfig.test.json` sets `noUnusedLocals: false` | ✅ Appropriate for test files |
| `jest.integration.config.js` targets `.integration.test.ts` only | ✅ |
| Manual scripts excluded from Jest | ✅ Do not match `*.test.ts` pattern |

---

## Test-to-Source Mapping

| Source File | Has Unit Test | Key Behaviors Tested | Gaps |
|---|---|---|---|
| `join1v1Pool.ts` | ✅ | Pool create, interest text stored, unauthenticated rejected | None |
| `cancel1v1Pool.ts` | ✅ | Cancel removes doc, `matching_in_progress` race case | None |
| `match1v1Users.ts` | ✅ | Transaction atomicity, FIFO fallback, cosine similarity threshold (0.65), interest vector stored | None |
| `joinGroupRoom.ts` | ✅ | Join fills slot, creates room when pool empty, unauthenticated rejected | None |
| `createCustomRoom.ts` | ✅ | Room created, locked room rejects join, roomType='custom' | None |
| `joinRoomById.ts` | ✅ | Locked room rejected, expired room rejected, invalid ID rejected | None |
| `leaveRoom.ts` | ✅ | memberCount decremented, padding transition when last member leaves | None |
| `setRoomLock.ts` | ✅ | Lock toggled, non-member rejected, non-custom room rejected | None |
| `expireRooms.ts` | ✅ | Tombstones expired rooms, re-verifies RTDB membership before expiry | None |
| `cleanupMember.ts` | ✅ | RTDB disconnect triggers Firestore memberCount decrement | None |
| `cleanupPoolMember.ts` | ✅ | RTDB pool_presence delete triggers waiting_pool cleanup | None |
| `sendMessage.ts` | ✅ | Fields present, IV uniqueness (two messages), non-participant rejected, text length validation | None |
| `endSession.ts` | ⚠️ | `active_sessions` path fully tested | **F-001: `rooms/` path not tested** |
| `reportSession.ts` | ✅ | Chat log retained, self-report rejected, unauthenticated rejected, `session_keys.flagged=true` | None |
| `embeddingService.ts` | ✅ | Comprehensive: same/opposite/orthogonal vectors, zero vector, meanVector, null on failure | None |

---

## `helpers.ts` Audit

| Check | Result |
|-------|--------|
| Emulator connection (Auth 9099, Firestore 8080, RTDB 9000, Functions 5001) | ✅ Correct ports |
| Hardcoded credentials | ✅ None — uses `Bearer owner` for emulator admin access only |
| `resetEmulatorData()` clears both Firestore and RTDB | ✅ |
| `waitUntilRtdbValue()` / `waitUntilAdminDocMatches()` poll helpers | ✅ Correct pattern — prevents flaky async timing |
| `adminFirestoreUpdate()` uses field mask (non-destructive) | ✅ |
| `buildRoom()` helper for multi-user setup | ✅ Reusable |
| `signInAnon()` / `signOut()` for auth context management | ✅ |

---

## What Is Working Well

- IV uniqueness tested: two consecutive `sendMessage` calls assert `m1.iv !== m2.iv` ✅
- `senderId` verified from auth UID, not payload ✅ (sendMessage test sets up with a specific UID and asserts doc.senderId matches)
- `displayName` verified from Firestore user record ✅
- Cosine similarity threshold boundary tested: pairs above/below 0.65 ✅
- Zero-vector divide-by-zero guard tested: `cosineSimilarity([0,0,0], [1,2,3]) === 0` ✅
- `reportSession` `session_keys.flagged = true` verified ✅
- `expireRooms` re-verifies RTDB membership before tombstoning (regression test added) ✅
- All 14 matchmaking describe groups cover real behavioral scenarios ✅
- `helpers.ts` uses polling helpers instead of `sleep()` — tests are resilient to async CF delays ✅
- No hardcoded credentials in any file ✅
- Integration tests correctly excluded from `npm test` ✅
