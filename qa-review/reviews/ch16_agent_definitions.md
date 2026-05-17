# Chapter 16 — Agent Definitions QA Review

> Status: COMPLETE
> Reviewer: qa-agent-supplemental
> Date: 2026-05-17

## Summary

Reviewed all four agent definition files in `.claude/agents/`: `architect.md`, `flutter-engineer.md`, `qa-engineer.md`, and `security-reviewer.md`. Three agents are substantially accurate. Two agents contain stale counts or stale auth-state claims that would mislead anyone relying on them without cross-referencing `CLAUDE.md`. One agent (`architect.md`) contains a stale RTDB path in its Privacy by Design section. No agent definitions conflict with each other in a way that would cause incorrect code generation, but the stale data could cause confusion during onboarding or task delegation.

## Findings

### F-001 — `architect.md` Privacy by Design references stale RTDB path `messages/{roomId}`
- **Severity:** MEDIUM
- **File:** `.claude/agents/architect.md` line 29
- **Category:** Doc-Drift
- **Description:** The Privacy by Design cleanup procedure (step 1) states "Cloud Function deletes `messages/{roomId}` in RTDB." No such RTDB path exists in the current system. Chat messages are stored in Firestore at `chat_rooms/{sessionId}/messages/{messageId}`, not in RTDB. The actual RTDB paths that are cleaned up are `rooms/{roomId}/members/{uid}`, `typing/{roomId}/{uid}`, and `presence/{roomId}/{uid}` — all wiped by `leaveRoom` / `expireRooms` Cloud Functions. This is confirmed by the integration tests in `matchmaking_advanced_test.dart` (lines 409–428: RTDB tests assert on `typing/`, `presence/`, `rooms/members/`, not `messages/`).
- **Evidence:** `CLAUDE.md` RTDB path table: `rooms/{roomId}/members/{uid}`, `typing/{roomId}/{uid}`, `presence/{roomId}/{uid}`, `nameQueue/{roomId}`, `pool_presence/{uid}`. No `messages/` path. `firestore.rules` has `chat_rooms/{sessionId}/messages/{messageId}` as the Firestore message collection.
- **Recommendation:** Replace step 1 with the correct cleanup list: "Cloud Function (`leaveRoom` / `expireRooms`) removes RTDB paths: `rooms/{roomId}/members/{uid}`, `typing/{roomId}/{uid}`, `presence/{roomId}/{uid}`." Also add that Firestore `chat_rooms/{sessionId}/messages` is wiped by `endSession`.

### F-002 — `architect.md` Privacy by Design step 2 references `active_sessions` as primary cleanup target
- **Severity:** LOW
- **File:** `.claude/agents/architect.md` line 30
- **Category:** Doc-Drift
- **Description:** Step 2 states "Cloud Function deletes `active_sessions/{sessionId}` in Firestore." In the current architecture `active_sessions` is a legacy-compat collection only. New rooms use `rooms/{roomId}` which transitions to `status: "expired"` (tombstoning) rather than being deleted. The agent definition implies deletion where tombstoning now occurs.
- **Evidence:** `CLAUDE.md` rooms collection description: "Rooms expire via state machine: when empty, status transitions to `padding`; `expireRooms` (cron) tombstones them after the padding window." `architect.md` lines 44–45: the Session Lifecycle Design section correctly describes the tombstone pattern — inconsistent with line 30.
- **Recommendation:** Update step 2: "Cloud Function tombstones `rooms/{roomId}` (`status: 'expired'`, `users: []`) and deletes legacy `active_sessions/{sessionId}` for proto-sessions only."

### F-003 — `qa-engineer.md` Jest test count is severely stale (43/7 vs actual 60/14)
- **Severity:** HIGH
- **File:** `.claude/agents/qa-engineer.md` line 103, 111
- **Category:** Doc-Drift
- **Description:** The agent states "Jest tests live at `functions/src/matchmaking/__tests__/matchmaking.test.ts` — 43 tests, 7 describe groups." The actual counts are 60 tests and 14 describe groups. This has likely confused the 43-test count from the _Dart_ integration test file (`matchmaking_advanced_test.dart` has exactly 43 tests) with the Jest file. The "all 43 tests" reference at line 111 repeats the error. Anyone using this agent to assess test coverage will believe 17 tests and 7 describe groups do not exist.
- **Evidence:** `grep -c "^\s*test\b" functions/src/matchmaking/__tests__/matchmaking.test.ts` → 60. `grep -c "^describe" ...matchmaking.test.ts` → 14. Dart: `grep -c "^\s*test\b" apps/mobile/integration_test/matchmaking_advanced_test.dart` → 43.
- **Recommendation:** Update line 103 and 111: "Jest tests live at `functions/src/matchmaking/__tests__/matchmaking.test.ts` — **60 tests, 14 describe groups**." Also note that `chat.test.ts` has 12 tests (not 11 — one test was added in the QA Phase 2 fix commit to cover the `rooms/` path in `endSession`).

### F-004 — `qa-engineer.md` `helpers.ts` documentation is incomplete (7 undocumented functions)
- **Severity:** LOW
- **File:** `.claude/agents/qa-engineer.md` lines 116–123
- **Category:** Doc-Drift
- **Description:** The agent documents 7 helpers: `signInAnon`, `signOut`, `callFn`, `adminFirestoreDoc`, `rtdbGet`, `resetEmulatorData`, `buildRoom`. The actual `helpers.ts` exports 13 functions: additionally `waitUntilRtdbValue`, `waitUntilAdminDocMatches`, `tryLeaveRoom`, `tryCancelPool`, `adminFirestoreUpdate`, `adminFirestoreSet`, `adminFirestoreList`, `callScheduledFn`, and `adminFirestoreList`. The polling helpers (`waitUntilAdminDocMatches`, `waitUntilRtdbValue`) are used extensively throughout `matchmaking.test.ts` and are essential for writing async CF trigger tests correctly.
- **Evidence:** `cat functions/src/matchmaking/__tests__/helpers.ts` exports 13+ functions. The agent describes only 7.
- **Recommendation:** Add at minimum `waitUntilAdminDocMatches` and `waitUntilRtdbValue` to the helper pattern documentation, as these are the primary polling primitives needed to test Firestore trigger side-effects.

### F-005 — `security-reviewer.md` Auth section marks Google + Email/Password as "not yet wired in Flutter"
- **Severity:** MEDIUM
- **File:** `.claude/agents/security-reviewer.md` line 29
- **Category:** Doc-Drift
- **Description:** The Known Security State section states "Google + Email/Password: on, not yet wired in Flutter." Both auth methods are fully implemented in the `auth` feature. `AuthDatasourceImpl.signInWithGoogle()` uses `GoogleSignIn.instance.authenticate()` on native and `signInWithPopup(GoogleAuthProvider())` on web. Email/password uses `signInWithEmailAndPassword`. Both are in the `auth` feature as of PR #33. A security reviewer using this agent would incorrectly consider these paths unimplemented and skip their review.
- **Evidence:** `apps/mobile/lib/features/auth/data/datasources/auth_datasource.dart` lines 11 (`signInWithGoogle` abstract), 69–75 (Google impl), 147 (email/password impl). `CLAUDE.md` Auth Feature section: "Use cases: SignUp, SignIn, SignOut, SignInAnonymously, SignInWithGoogle."
- **Recommendation:** Update to: "Google + Email/Password: on, **wired in Flutter** (`features/auth/`). Platform split in `signInWithGoogle()`: web uses `signInWithPopup`, native uses `GoogleSignIn.instance.authenticate()`."

### F-006 — `flutter-engineer.md` references matchmaking as having "9 usecases" — accurate but the comment "SetRoomLock pattern" implies it is exceptional
- **Severity:** INFO
- **File:** `.claude/agents/flutter-engineer.md` line 12
- **Category:** Minor inaccuracy
- **Description:** The file reads "matchmaking, 9 usecases, SetRoomLock pattern". The count of 9 is correct (cancel_1v1_pool, create_custom_room, join_1v1_pool, join_group_room, join_room_by_id, leave_room, set_room_lock, watch_1v1_match, watch_room). The parenthetical "SetRoomLock pattern" appears to call out `set_room_lock` as having a notable pattern, but the file does not elaborate on what that pattern is. This is vague for an agent meant to guide implementation.
- **Evidence:** `apps/mobile/lib/features/matchmaking/domain/usecases/` contains exactly 9 files.
- **Recommendation:** Either remove the parenthetical or replace it with a short note: "(SetRoomLock demonstrates the boolean-toggle usecase pattern — no return value, bool argument, throws on not-found)."

### F-007 — `architect.md` "Open Decisions" section still lists matchmaking design as unresolved
- **Severity:** INFO
- **File:** `.claude/agents/architect.md` lines 49–54
- **Category:** Stale state
- **Description:** Item 1 is struck through with "Resolved" — this is correct. Items 2–5 are unresolved. This section is largely fine, but item 5 ("Group room reporting: deferred") is no longer a decision-point item; the current `reportSession` CF retains a session key and the flow is implemented. The comment "message snippet retention planned" may confuse future contributors about what is and is not built.
- **Evidence:** `CLAUDE.md` chat CF section: "`reportSession` (retain chat log for moderation)." The functionality exists.
- **Recommendation:** Mark item 5 as resolved: "~~Group room reporting~~ — **Resolved**: `reportSession` CF retains `session_keys` doc and sets `flagged=true` to prevent TTL auto-delete. Message snapshot retention for group rooms is still deferred."

## Agent Role Overlap Assessment

No destructive conflicts exist between agents. The agents cover orthogonal responsibilities (architecture, implementation, testing, security). The QA agent and Security agent both reference integration tests and Firebase rules but from different angles without contradiction. One overlap worth noting: both `flutter-engineer.md` and `qa-engineer.md` contain canonical widget test patterns — these are intentionally duplicated as quick-reference for each agent's context and are consistent with each other and with `CLAUDE.md`.
