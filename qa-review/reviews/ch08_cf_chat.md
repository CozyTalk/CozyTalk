# Chapter 08 — Cloud Functions: Chat Backend QA Review

> Status: COMPLETE
> Date: 2026-05-17

## Summary

Reviewed `sendMessage`, `endSession`, `reportSession`, `setTyping`, and `onProtoPresenceDeleted`. The chat backend passes all critical security checks: `senderId` is always server-side from `request.auth.uid`, `displayName` is sourced from Firestore (never client payload), AES-256-GCM IV is generated fresh per message with `crypto.randomBytes(12)`, the encryption key is read server-side from Firestore (never from client), self-reports are blocked, and all callable functions check auth. One HIGH functional gap: `endSession` only handles `active_sessions` collection and will return `not-found` for any 1v1 session created via the new matchmaking system (stored in `rooms/`). One HIGH dead-code issue: `setTyping.ts` is a full implementation that is intentionally not exported.

**Findings: 2 HIGH, 0 MEDIUM, 0 LOW, 2 INFO/DOC-DRIFT**

---

## Findings

### F-001 — endSession does not support rooms/ collection (new matchmaking sessions)
- **Severity:** HIGH
- **File:** `functions/src/chat/endSession.ts` lines 28–31
- **Category:** Bug
- **Description:** `endSession` reads only from `db.collection("active_sessions").doc(sessionId)`. The new matchmaking system creates sessions in `rooms/{roomId}`. Any 1v1 chat session started via `join1v1Pool` → `match1v1Users` uses `rooms/`, not `active_sessions/`. When a Flutter client calls `endSession` for such a session, the function throws `not-found`, leaving the encryption key unarchived in `rooms/{sessionId}` and RTDB data uncleaned. `sendMessage` already handles this correctly with a dual-collection lookup (checks `rooms/` first, falls back to `active_sessions/`).
- **Evidence:**
  ```typescript
  // Only active_sessions lookup — missing rooms/ branch:
  const sessionDoc = await db.collection("active_sessions").doc(sessionId).get();
  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Session not found.");
  }
  ```
- **Recommendation:** Mirror `sendMessage`'s dual-collection pattern. Check `rooms/` first; fall back to `active_sessions/`. For `rooms/`-sourced sessions, tombstone the room (set `status: expired`, `users: []`) in addition to archiving the key and cleaning RTDB. **Fixed in this QA pass.**

### F-002 — setTyping.ts is dead code (implemented but not exported)
- **Severity:** HIGH
- **File:** `functions/src/chat/setTyping.ts`
- **Category:** Dead Code / Doc-Drift
- **Description:** `setTyping.ts` contains a full 45-line CF implementation (auth check, session validation, RTDB write) but is NOT imported or exported in `index.ts`. The `index.ts` comment correctly says `// setTyping: no Cloud Function — clients write directly to RTDB.` CLAUDE.md also correctly states no CF is needed. The file is dead code that creates confusion and also only handles `active_sessions` (it would fail for new-style rooms anyway).
- **Evidence:** `index.ts` has comment but no export for setTyping. File exists at full implementation.
- **Recommendation:** Delete `functions/src/chat/setTyping.ts`. **Fixed in this QA pass.**

### F-003 — onProtoPresenceDeleted.ts is a disabled stub
- **Severity:** INFO / DOC-DRIFT
- **File:** `functions/src/chat/onProtoPresenceDeleted.ts`
- **Category:** Doc-Drift
- **Description:** File content is `export {};`. Comment: "Disabled: proto room cleanup on last-user disconnect is removed during solo testing. Re-enable when matchmaking is implemented." Since matchmaking IS now implemented, this trigger should be re-evaluated. CLAUDE.md documents it as an active function.
- **Recommendation:** Evaluate whether to re-enable or formally remove. Update CLAUDE.md to reflect disabled state. **CLAUDE.md updated in this QA pass.**

### F-004 — Callable CFs lack top-level JSDoc (style note)
- **Severity:** INFO
- **File:** `sendMessage.ts`, `endSession.ts`, `reportSession.ts`
- **Category:** Style
- **Description:** The exported `const` CF expressions (`export const sendMessage = onCall(...)`) lack JSDoc. Per CLAUDE.md style rules, `const` arrow functions are exempt from the JSDoc requirement. Internal helper functions (`generateKey`, `encryptText`) DO have JSDoc. This is technically compliant.
- **Recommendation:** No action required. Note for awareness.

---

## Security Audit Results

| Check | Result |
|-------|--------|
| sendMessage: senderId set from request.auth.uid (server-side) | ✅ PASS |
| sendMessage: displayName sourced from Firestore, never client payload | ✅ PASS (falls back to RTDB presence name, never request.data) |
| sendMessage: unique random IV per message (crypto.randomBytes(12)) | ✅ PASS |
| sendMessage: IV is exactly 12 bytes (96 bits) | ✅ PASS |
| sendMessage: encryption key read server-side from Firestore, never from client | ✅ PASS (transaction ensures key exists) |
| sendMessage: expiresAt always set (3-day TTL) | ✅ PASS |
| sendMessage: supports both rooms/ and active_sessions/ | ✅ PASS |
| endSession: verifies caller is participant | ✅ PASS (for active_sessions path) |
| endSession: archives encryption key to session_keys | ✅ PASS (for active_sessions path) |
| endSession: destroys RTDB data immediately | ✅ PASS |
| endSession: supports rooms/ collection | ❌ FAIL (F-001, fixed) |
| reportSession: blocks self-reports | ✅ PASS (reporterId === reportedUserId check) |
| reportSession: reporterId set from request.auth.uid | ✅ PASS |
| reportSession: verifies reporter is participant | ✅ PASS (checks rooms/, active_sessions/, session_keys/) |
| reportSession: retains chat log (removes TTL) | ✅ PASS (expiresAt: null on messages + session_keys) |
| All callable CFs check request.auth | ✅ PASS |
| All errors use HttpsError (not plain throw) | ✅ PASS |
| No console.log (uses firebase-functions/logger) | ✅ PASS |
| No implicit any TypeScript types | ✅ PASS |

## Privacy by Design Verification

| Requirement | Result |
|-------------|--------|
| Chat messages destroyed on session end | ✅ PASS (deleteSubcollection called) |
| RTDB presence/typing destroyed on session end | ✅ PASS |
| Encryption key archived before messages deleted | ✅ PASS |
| reportSession is the ONLY path that retains messages indefinitely | ✅ PASS (sets expiresAt: null on flagged messages) |
| Non-reported session keys expire after 3 days | ✅ PASS (RETENTION_MS = 3 days) |
