# Chapter 15 — context-aware_matchmaking.md QA Review

> Status: COMPLETE
> Reviewer: qa-agent-supplemental
> Date: 2026-05-17

## Summary

Audited both `context-aware_matchmaking.md` (decision log) and `MATCHMAKING_CONTEXT_AWARE.md` (authoritative reference) against the actual TypeScript Cloud Functions and Flutter implementation. All core constants (model name, dimension count, similarity threshold) match the code exactly. The overall architecture description is accurate and the Flutter data-flow documentation is correct. Eight findings were identified: five in the reference doc (`MATCHMAKING_CONTEXT_AWARE.md`) and three in the decision log (`context-aware_matchmaking.md`). The most significant issues are stale describe-group names and counts in both docs (the test suite was restructured after the docs were written), a wrong test assertion example in the reference doc (wrong vector axis, wrong triggering CF), and a misleading static-import code snippet in the decision log that doesn't reflect the lazy dynamic-import pattern the code actually uses. No CRITICAL severity issues; all findings are Doc-Drift.

---

## Doc-Drift Table

| Doc File | Section | Was | Now | Severity | Applied |
|---|---|---|---|---|---|
| `context-aware_matchmaking.md` | Test Coverage › New describe groups | `"1v1 interest matching: prefers similar-interest candidates"` — 3 scenarios | Actual group name: `"1v1 interest matching: prefers similar-interest candidate"` (no trailing s); 2 tests, not 3 | MEDIUM | No |
| `context-aware_matchmaking.md` | Test Coverage › New describe groups | `"1v1 interest matching: falls back to FIFO without interest data"` — 3 scenarios | No such top-level group exists; the FIFO fallback test is the second test inside `"1v1 interest matching: prefers similar-interest candidate"` | MEDIUM | No |
| `context-aware_matchmaking.md` | Test Coverage › New describe groups | `"group interest matching: routes to interest-matching room"` — 4 scenarios | Group is now named `"group interest matching: Phase 0 routing"` with 3 tests | MEDIUM | No |
| `context-aware_matchmaking.md` | Test Coverage › New describe groups | `"group interest matching: graceful fallback"` — 3 scenarios | No such group exists; absorbed into `"group interest matching: Phase 0 routing"` | MEDIUM | No |
| `context-aware_matchmaking.md` | Test Coverage › New describe groups | `"room interest vector: maintained on join/leave"` — 6 scenarios | Split into three separate groups: `"1v1 interest matching: room interest vectors"` (2), `"group room: roomInterestVector maintained on leave"` (2), and new groups for join1v1Pool/joinGroupRoom seeding | MEDIUM | No |
| `context-aware_matchmaking.md` | New File: embeddingService.ts › API | `import {v1, helpers} from "@google-cloud/aiplatform";` (static top-level import) | Code uses lazy `await import("@google-cloud/aiplatform")` inside `_getClient()` and `embedText()` to avoid OOM at cold start | MEDIUM | No |
| `MATCHMAKING_CONTEXT_AWARE.md` | matchmaking.test.ts › 60 tests across 14 describe groups (table) | Table lists only 11 of 14 groups; missing: `"join1v1Pool: interest text and embedding"` (3 tests), `"joinGroupRoom: interest text seeded into room"` (2 tests), `"group interest matching: Phase 0 routing"` (3 tests) | 14 groups present in code, 3 omitted from the table | MEDIUM | No |
| `MATCHMAKING_CONTEXT_AWARE.md` | matchmaking.test.ts › table | `RTDB and edge cases` → 4 tests; `1v1 pool and match` → 6 tests; `flows` → 9 tests | Actual counts: `RTDB and edge cases` = 5, `1v1 pool and match` = 7, `flows` = 12 | LOW | No |
| `MATCHMAKING_CONTEXT_AWARE.md` | group room leave test assertion example | "Trigger cleanupMember by deleting RTDB member" via `rtdbDeleteMember(roomId, uidA)` | Actual test calls `callFn("leaveRoom")` — exercises `leaveRoom` CF, not `cleanupMember`; uidB (not uidA) is the signed-in user who leaves | HIGH | No |
| `MATCHMAKING_CONTEXT_AWARE.md` | group room leave test assertion example | `expect(updated!["roomInterestVector"][1]).toBe(1)` (uidB's unitVec(1) remains) | Actual assertion: `expect(rv[0]).toBe(1); expect(rv[1]).toBe(0)` — uidA's unitVec(0) remains after uidB leaves | HIGH | No |
| `MATCHMAKING_CONTEXT_AWARE.md` | File Map | `testEmbeddingLive.ts` listed; `embeddingService.integration.test.ts` absent | `embeddingService.integration.test.ts` exists on disk (7 live Vertex AI tests, run via `npm run test:embedding`); not in the file map | LOW | No |

---

## Findings

### F-001 — Decision Log Lists Five Stale Describe Group Names
- **Severity:** MEDIUM
- **File:** `context-aware_matchmaking.md` lines 151–155
- **Category:** Doc-Drift
- **Description:** The decision log lists five "new describe groups" added to `matchmaking.test.ts`. All five names are wrong or no longer exist as discrete groups. The test suite was restructured after this doc was written.
- **Evidence:**
  - Doc: `"1v1 interest matching: prefers similar-interest candidates"` (plural, 3 scenarios)
  - Actual: `"1v1 interest matching: prefers similar-interest candidate"` (singular, 2 tests)
  - Doc: `"1v1 interest matching: falls back to FIFO without interest data"` — does not exist as a separate group; the FIFO fallback is the second test inside the group above.
  - Doc: `"group interest matching: routes to interest-matching room"` — actual name is `"group interest matching: Phase 0 routing"` (3 tests).
  - Doc: `"group interest matching: graceful fallback"` — not a distinct group; folded into Phase 0 routing group.
  - Doc: `"room interest vector: maintained on join/leave"` — split into three narrower describe groups.
- **Recommendation:** Replace the five listed names with the six actual describe group names and correct test counts: `"1v1 interest matching: room interest vectors"` (2), `"group room: roomInterestVector maintained on leave"` (2), `"1v1 interest matching: prefers similar-interest candidate"` (2), `"join1v1Pool: interest text and embedding"` (3), `"joinGroupRoom: interest text seeded into room"` (2), `"group interest matching: Phase 0 routing"` (3).

---

### F-002 — Decision Log Shows Static Import; Code Uses Lazy Dynamic Import
- **Severity:** MEDIUM
- **File:** `context-aware_matchmaking.md` lines 52–53
- **Category:** Doc-Drift
- **Description:** The `API` code block in the decision log shows `import {v1, helpers} from "@google-cloud/aiplatform";` as a top-level static import. The actual implementation uses `await import("@google-cloud/aiplatform")` inside the `_getClient()` async function (and again inside `embedText()`) to avoid loading the 30+ MB package at container cold-start. The doc misleads contributors about the initialization pattern.
- **Evidence:**
  ```typescript
  // embeddingService.ts line 24
  const {v1} = await import("@google-cloud/aiplatform");
  // embeddingService.ts line 52
  const [{helpers}, client] = await Promise.all([
    import("@google-cloud/aiplatform"),
    _getClient(),
  ]);
  ```
- **Recommendation:** Update the API snippet to show the dynamic `await import(...)` pattern, or add a note explaining that the snippet is simplified and the real code uses lazy loading via a `_getClient()` singleton helper.

---

### F-003 — Reference Doc Omits Three Describe Groups from the Test Table
- **Severity:** MEDIUM
- **File:** `MATCHMAKING_CONTEXT_AWARE.md` lines 396–408 (the "60 tests across 14 describe groups" table)
- **Category:** Doc-Drift
- **Description:** The table claims 14 describe groups and 60 tests but only rows for 11 groups are shown. Three groups added during the later interest-seeding and Phase 0 routing work are missing entirely: `"join1v1Pool: interest text and embedding"` (3 tests), `"joinGroupRoom: interest text seeded into room"` (2 tests), `"group interest matching: Phase 0 routing"` (3 tests). The total test count of 60 is correct; only the table rows are incomplete.
- **Evidence:** `grep -c "describe(" matchmaking.test.ts` → 14; table rows → 11.
- **Recommendation:** Add the three missing rows to the table.

---

### F-004 — Reference Doc Has Wrong Test Counts for Three Existing Groups
- **Severity:** LOW
- **File:** `MATCHMAKING_CONTEXT_AWARE.md` lines 398–405 (test count table)
- **Category:** Doc-Drift
- **Description:** Three group test counts in the table are stale.
- **Evidence:**
  | Group | Doc count | Actual count |
  |---|---|---|
  | `RTDB and edge cases` | 4 | 5 |
  | `1v1 pool and match` | 6 | 7 |
  | `flows` | 9 | 12 |
- **Recommendation:** Update the three counts in the table to 5, 7, and 12 respectively.

---

### F-005 — Reference Doc Shows Wrong CF and Wrong Assertion for Group Leave Test
- **Severity:** HIGH
- **File:** `MATCHMAKING_CONTEXT_AWARE.md` lines 465–488 (Key interest test assertions — Group section)
- **Category:** Doc-Drift
- **Description:** The reference doc's assertion example for the group-leave vector recomputation test is wrong on two counts. First, it claims the test triggers `cleanupMember` via `rtdbDeleteMember(roomId, uidA)`. The actual test calls `callFn("leaveRoom")` — it exercises `leaveRoom`, not `cleanupMember`. Second, the assertion example shows `expect(updated!["roomInterestVector"][1]).toBe(1)` (suggesting uidB's `unitVec(1)` survives), but the actual test has `callFn("leaveRoom")` called by uidB (the currently-signed-in user), so uidA's `unitVec(0)` remains, and the assertions are `expect(rv[0]).toBe(1); expect(rv[1]).toBe(0)`.
- **Evidence:**
  ```typescript
  // Doc claims:
  // "Trigger cleanupMember by deleting RTDB member"
  // await rtdbDeleteMember(roomId, uidA);
  // ...
  // expect(updated!["roomInterestVector"][1]).toBe(1);

  // Actual test (matchmaking.test.ts line 1459-1471):
  await callFn("leaveRoom", {roomId});  // uidB leaves (current signed-in user)
  const rv = updated!["roomInterestVector"] as number[];
  expect(rv[0]).toBe(1);   // uidA's unitVec(0) remains
  expect(rv[1]).toBe(0);
  ```
- **Recommendation:** Update the code snippet to use `callFn("leaveRoom", {roomId})` and correct the assertion to `expect(rv[0]).toBe(1); expect(rv[1]).toBe(0)`. Add a note clarifying this test exercises `leaveRoom`; `cleanupMember` is covered by a separate test described in Known Pitfall #5.

---

### F-006 — Reference Doc File Map Missing embeddingService.integration.test.ts
- **Severity:** LOW
- **File:** `MATCHMAKING_CONTEXT_AWARE.md` lines 33–38 (file map `__tests__/` block)
- **Category:** Doc-Drift
- **Description:** The file map lists `testEmbeddingLive.ts` but omits `embeddingService.integration.test.ts`, which exists on disk and contains 7 live Vertex AI integration tests run via `npm run test:embedding`. The CLAUDE.md root document already documents this file (it mentions "7 live Vertex AI integration tests in `embeddingService.integration.test.ts`"), so the omission creates a gap between the project-level docs and the matchmaking-specific reference.
- **Evidence:** `ls functions/src/matchmaking/__tests__/` includes `embeddingService.integration.test.ts`.
- **Recommendation:** Add `embeddingService.integration.test.ts ← live Vertex AI integration tests (run via npm run test:embedding)` to the file map.

---

### F-007 — Decision Log embeddingService Test Summary Undercounts meanVector Tests
- **Severity:** LOW
- **File:** `context-aware_matchmaking.md` line 148
- **Category:** Doc-Drift
- **Description:** The decision log describes the `embeddingService.test.ts` coverage as: `"meanVector: identity, two-vector average, three vectors"` — listing only 3 cases. The actual `meanVector` describe has 4 tests: the three listed plus `"empty input → empty array"`. This is a minor undocumentation.
- **Evidence:** `embeddingService.test.ts` lines 39–65: four tests in the `meanVector` describe block.
- **Recommendation:** Append `empty input` to the meanVector bullet: `"meanVector: identity, two-vector average, three vectors, empty input → []"`.

---

### F-008 — Decision Log and Reference Doc Both Omit 1v1 Re-Queue Interest Preservation
- **Severity:** LOW
- **File:** `context-aware_matchmaking.md` (Cloud Function Changes section); `MATCHMAKING_CONTEXT_AWARE.md` (leaveRoom section)
- **Category:** Doc-Drift
- **Description:** When a 1v1 partner leaves and the remaining user is re-queued, `leaveRoom.ts` (and `cleanupMember.ts`) preserves that user's `interestVector` in the new `waiting_pool` doc (via `requeueInterestVector`). Neither doc mentions this behavior. It is a meaningful feature: re-queued users retain their interest preference so the next match can still use cosine similarity.
- **Evidence:**
  ```typescript
  // leaveRoom.ts lines 45, 73, 116-117
  let requeueInterestVector: number[] | null = null;
  requeueInterestVector = mi?.[requeueUid] ?? null;
  // written to new pool doc:
  interestText: null,
  interestVector: requeueInterestVector,
  ```
- **Recommendation:** Add a bullet to the `leaveRoom.ts` + `cleanupMember.ts` section in both docs: `"1v1 re-queue: remaining user's interestVector is carried over into the new waiting_pool doc so the next match can still apply interest sorting"`.
