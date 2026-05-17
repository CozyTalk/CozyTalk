# Chapter 3 — Chat Feature QA Review

> Status: COMPLETE
> Reviewer: qa-agent-phase2
> Date: 2026-05-17

## Summary

Reviewed all layers of `features/chat/` — domain entities, use cases, repository interface, `ChatDatasourceImpl`, `ChatRepositoryImpl`, `ChatNotifier`/`ChatState`, `ChatScreen`, and all 13 test files. The chat feature is architecturally sound. AES-256-GCM encryption, RTDB listener lifecycle, and state machine transitions all pass review. Two low-severity findings: the `_anonymousName` duplication (shared with ch02) and a proto-session key that is deterministic from the session ID. The RTDB `onDisconnect` hook lifecycle is correct as-is.

**Findings by severity:** HIGH 0 · MEDIUM 0 · LOW 2 · INFO 2

---

## Findings

### F-001 — `_anonymousName()` duplicated from `auth_datasource.dart`
- **Severity:** LOW
- **File:** `apps/mobile/lib/features/chat/data/datasources/chat_datasource.dart`
- **Category:** Style / Tech-Debt
- **Description:** Same finding as ch02-F-002. The function is identical in both files. See `auth` chapter for full details. No immediate action required; extract when a third caller appears.
- **Evidence:** Verbatim duplicate of the 45-line function and word lists.
- **Recommendation:** Track alongside ch02-F-002. Extract to `apps/mobile/lib/shared/anonymous_name.dart` when warranted.

---

### F-002 — Proto-session encryption key is deterministic from session ID
- **Severity:** LOW
- **File:** `apps/mobile/lib/features/chat/data/datasources/chat_datasource.dart`
- **Category:** Security / Design
- **Description:** Proto sessions (session IDs starting with `'proto-'`) derive their AES-256 key from `SHA256('cozytalk-proto-v1:{sessionId}')`. This means anyone who knows the sessionId can reconstruct the key without any additional secret. However, proto sessions are a developer-only feature (not reachable from the production matchmaking flow) and the session ID is not public. This is an acceptable tradeoff for a dev-only flow but should be documented explicitly.
- **Evidence:** Key derivation in `chat_datasource.dart` proto branch: `SHA256('cozytalk-proto-v1:$sessionId')`.
- **Recommendation:** Add a comment explaining proto sessions are dev-only and the deterministic key is intentional. Do not expose proto-session flows to end users.

---

### F-003 — `_cancelSubscriptions()` does not cancel RTDB `onDisconnect` hooks
- **Severity:** INFO
- **File:** `apps/mobile/lib/features/chat/data/datasources/chat_datasource.dart`
- **Category:** Style
- **Description:** `_cancelSubscriptions()` cancels RTDB listeners but does not call `.cancel()` on any `onDisconnect` registration. This is intentional — the `onDisconnect` hook should fire when the socket disconnects to clean up presence/typing data. Cancelling it would defeat the privacy cleanup.
- **Evidence:** `_cancelSubscriptions()` cancels listeners but leaves `onDisconnect` registrations active (correct).
- **Recommendation:** Add a comment at the `_cancelSubscriptions` call site noting that `onDisconnect` hooks are intentionally not cancelled.

---

### F-004 — `ChatNotifier.enterSession()` called via `addPostFrameCallback` — correct lifecycle
- **Severity:** INFO
- **File:** `apps/mobile/lib/features/chat/presentation/screens/chat_screen.dart`
- **Category:** Style
- **Description:** `ChatScreen.initState()` schedules `enterSession()` via `addPostFrameCallback` to ensure the widget tree is mounted before Riverpod state mutations begin. This is the correct pattern and matches how `AvatarPickerScreen.load()` is called. No action needed; noting as confirmed-correct for future reviewers.
- **Evidence:** `initState` in `chat_screen.dart`.
- **Recommendation:** None.

---

## Clean Architecture Compliance

| Layer | Imports | Violations |
|-------|---------|------------|
| `domain/entities/` | Pure Dart | None |
| `domain/repositories/` | Domain only | None |
| `domain/usecases/` | Domain only | None |
| `data/models/` | `json_annotation`, domain | None |
| `data/datasources/` | `firebase_database`, `cloud_firestore`, `cloud_functions`, `cryptography` | None — all SDK calls are in datasource layer |
| `data/repositories/` | Domain + data | None |
| `presentation/providers/` | Riverpod, domain only | None |
| `presentation/screens/` | Flutter, Riverpod, domain | None |

---

## Test Coverage Assessment

| Component | Has Test | Has Sentinel Test | Gaps |
|-----------|----------|-------------------|------|
| `ChatMessage` entity | ✅ | N/A | None |
| `SessionStatus` enum | ✅ | N/A | None |
| `TypingUser` entity | ✅ | N/A | None |
| `WatchMessages` use case | ✅ | N/A | None |
| `SendMessage` use case | ✅ | N/A | None |
| `SetTyping` use case | ✅ | N/A | None |
| `WatchTypingUsers` use case | ✅ | N/A | None |
| `EndSession` use case | ✅ | N/A | None |
| `ChatMessageModel` | ✅ | N/A | None |
| `ChatRepositoryImpl` | ✅ | N/A | None |
| `ChatState.copyWith` | ✅ | ✅ (all nullable fields tested for null-clear) | None |
| `ChatNotifier` | ✅ | ✅ | None |
| `ChatScreen` | ✅ | N/A | None |
| `FakeChatRepository` | Extracted to `shared_fakes.dart` | — | None |

---

## What Is Working Well

- AES-256-GCM per-message IV via `crypto.randomBytes(12)` — no IV reuse ✅
- `senderId` always sourced from `request.auth.uid` in the `sendMessage` CF (server-side) ✅
- `displayName` for messages sourced from Firestore, not client payload ✅
- `endSession` CF now correctly handles both `rooms/` and `active_sessions/` (fixed in Phase 1) ✅
- `ChatState.copyWith` uses sentinel pattern for all 5 nullable fields ✅
- RTDB stream subscriptions properly cancelled in `_cancelSubscriptions()` ✅
- `ListView.builder` used in `ChatScreen` — no unbounded children array ✅
- `FakeChatRepository` extracted to `shared_fakes.dart` — not duplicated across test files ✅
- No Firebase SDK in any test file ✅
- `containsAll` + length assertion used for `SessionStatus` enum test ✅
