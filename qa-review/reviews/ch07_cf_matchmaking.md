# Chapter 07 — Cloud Functions: Matchmaking Backend QA Review

> Status: COMPLETE
> Date: 2026-05-17

## Summary

Reviewed all 11 exported matchmaking Cloud Functions plus `embeddingService.ts` and `_utils.ts`. The matchmaking backend is well-engineered overall: the 2-phase transaction in `match1v1Users` correctly prevents race conditions, `cosineSimilarity` has a divide-by-zero guard, `expireRooms` re-verifies RTDB state before tombstoning, all callable functions require auth, and the encryption key uses `crypto.randomBytes`. One MEDIUM security finding: `generateRoomId()` uses `Math.random()` (not crypto-random). One LOW finding: legacy RTDB `sessions`/`messages` rules are referenced but no code writes to them. Several doc-drift items in CLAUDE.md.

**Findings: 1 MEDIUM, 3 LOW, 5 INFO/DOC-DRIFT**

---

## Findings

### F-001 — generateRoomId uses Math.random()
- **Severity:** MEDIUM
- **File:** `functions/src/matchmaking/_utils.ts` lines 17–22
- **Category:** Security
- **Description:** Room IDs are generated using `Math.floor(Math.random() * ROOM_ID_CHARS.length)`. `Math.random()` is not cryptographically random. Room IDs are not used as auth tokens (Firestore rules enforce `users[]` membership), so this is not a direct auth bypass. However, predictable IDs allow targeted room squatting — an attacker could pre-generate likely IDs to collide with or occupy rooms. Inconsistency: `generateKey()` in the same file correctly uses `crypto.randomBytes(32)`.
- **Evidence:**
  ```typescript
  () => ROOM_ID_CHARS[Math.floor(Math.random() * ROOM_ID_CHARS.length)]
  ```
- **Recommendation:** Replace with `crypto.randomBytes(ROOM_ID_LENGTH)` and use `b % ROOM_ID_CHARS.length` for character selection. **Fixed in this QA pass.**

### F-002 — match1v1Users uses Math.random() for candidate shuffling
- **Severity:** INFO
- **File:** `functions/src/matchmaking/match1v1Users.ts` line 60
- **Category:** Style
- **Description:** `interestCandidates.sort(() => Math.random() - 0.5)` shuffles interest-matched candidates for fairness. This is non-cryptographic but not security-sensitive — it's a UX fairness mechanism, not an auth control.
- **Recommendation:** Acceptable as-is. Document intent if questioned.

### F-003 — cancel1v1Pool matching_in_progress return not documented
- **Severity:** LOW
- **File:** `functions/src/matchmaking/cancel1v1Pool.ts` lines 20–23
- **Category:** Doc-Drift
- **Description:** If the user's pool entry has `status == "matching"` (CF mid-execution), cancel returns `{success: false, reason: "matching_in_progress"}`. CLAUDE.md and the use case docs don't mention this. Flutter client must handle `success: false` — if it assumes success always, the user may get stuck in a "cancelling" UI state.
- **Evidence:**
  ```typescript
  if (snap.data()?.status === "matching") {
    return {success: false, reason: "matching_in_progress"};
  }
  ```
- **Recommendation:** Document in CLAUDE.md. Verify Flutter `cancel1v1Pool` use case handles `success: false`. **CLAUDE.md updated in this QA pass.**

### F-004 — match1v1Users Firestore trigger deployed to asia-southeast1
- **Severity:** LOW
- **File:** `functions/src/matchmaking/match1v1Users.ts` — `region: "asia-southeast1"`
- **Category:** Performance
- **Description:** This is a Firestore trigger; Firestore is likely deployed in `us-central1`. Running the trigger in `asia-southeast1` adds cross-region latency for Firestore reads/writes (~100–200ms). The tradeoff is that RTDB writes (membership anchors) benefit from co-location with the `asia-southeast1` RTDB instance. This appears intentional.
- **Recommendation:** Add a comment in the code explaining the region choice. Document in CLAUDE.md. **CLAUDE.md updated in this QA pass.**

### F-005 — onProtoPresenceDeleted is a disabled stub
- **Severity:** LOW / DOC-DRIFT
- **File:** `functions/src/chat/onProtoPresenceDeleted.ts`
- **Category:** Doc-Drift
- **Description:** File content is `export {};`. Comment reads: "Disabled: proto room cleanup on last-user disconnect is removed during solo testing. Re-enable when matchmaking is implemented." CLAUDE.md documents this as an active RTDB trigger.
- **Recommendation:** Update CLAUDE.md to mark as disabled stub. **Fixed in this QA pass.**

### F-006 — helloWorld export not counted in CLAUDE.md CF list
- **Severity:** INFO
- **File:** `functions/src/index.ts`
- **Category:** Doc-Drift
- **Description:** `helloWorld` is exported from `index.ts` as a 15th function. CLAUDE.md counts 11 matchmaking + 3 chat = 14. This is the function the `hello` Flutter feature calls as a smoke test.
- **Recommendation:** Mention in CLAUDE.md. **Fixed in this QA pass.**

### F-007 — CLAUDE.md rooms schema lists expiresAt; code uses paddingUntil
- **Severity:** INFO / DOC-DRIFT
- **File:** `functions/src/matchmaking/_utils.ts` — `RoomData` interface
- **Category:** Doc-Drift
- **Description:** The `rooms/{roomId}` schema in CLAUDE.md describes an `expiresAt` field. The actual `RoomData` TypeScript interface has `paddingUntil: null`. Rooms use a state machine: `status: "padding"` + `paddingUntil` timestamp. `expiresAt` exists on `chat_rooms/messages` and `session_keys`, not on rooms.
- **Recommendation:** Fix CLAUDE.md rooms schema. **Fixed in this QA pass.**

### F-008 — CLAUDE.md conflates mode and roomType fields
- **Severity:** INFO / DOC-DRIFT
- **File:** `functions/src/matchmaking/_utils.ts` — `RoomData` interface
- **Category:** Doc-Drift
- **Description:** `RoomData` has two distinct fields: `roomType: "public" | "custom"` (public matchmaking vs creator-controlled) and `mode: "1v1" | "group"` (participant count). CLAUDE.md uses `roomType` in some places where the code uses `mode`, and the Firestore index uses `mode` for matchmaking queries.
- **Recommendation:** Fix CLAUDE.md to clearly distinguish both fields. **Fixed in this QA pass.**

---

## Clean Architecture Compliance

N/A — Cloud Functions, not Flutter Clean Architecture.

## Security Audit Checklist

| Check | Result |
|-------|--------|
| All callable CFs check request.auth | ✅ PASS |
| RTDB triggers use asia-southeast1 + instance | ✅ PASS |
| generateKey() uses crypto.randomBytes(32) | ✅ PASS |
| generateRoomId() uses crypto randomness | ❌ FAIL (F-001, fixed) |
| match1v1Users uses Firestore transaction for atomic matching | ✅ PASS (2-phase) |
| cosineSimilarity has divide-by-zero guard | ✅ PASS |
| expireRooms re-checks RTDB membership before tombstoning | ✅ PASS |
| embedText returns null on failure (graceful degradation) | ✅ PASS |
| meanVector handles empty array (returns []) | ✅ PASS |
| All HttpsErrors use typed codes (not plain Error) | ✅ PASS (internal throws inside transactions are control flow, not API responses) |
| JSDoc on internal function declarations | ✅ PASS (all internal functions have JSDoc; exported const arrows are exempt per style rule) |
| No implicit any types | ✅ PASS |
| No @ts-ignore or eslint-disable comments | ✅ PASS |
