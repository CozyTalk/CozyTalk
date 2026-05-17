# Chapter 4 — Matchmaking Feature (Flutter) QA Review

> Status: COMPLETE
> Reviewer: qa-agent-phase2
> Date: 2026-05-17

## Summary

Reviewed all layers of `features/matchmaking/` — domain entities, all 8 use cases, repository interface, `MatchmakingDatasourceImpl`, `MatchmakingRepositoryImpl`, `MatchmakingNotifier`/`MatchmakingState`, and the matchmaking test suite. The Flutter matchmaking feature is architecturally complete and handles the complex race-condition scenarios (stale pool entries, partner-left requeue, padding-state requeue) correctly. One LOW finding: `cancelSearch()` swallows all CF errors silently. Everything else — sentinel pattern, stream lifecycle, `SharedPreferences` interest text persistence — passes.

**Findings by severity:** HIGH 0 · MEDIUM 0 · LOW 2 · INFO 2

---

## Findings

### F-001 — `cancelSearch()` swallows all CF cancel failures
- **Severity:** LOW
- **File:** `apps/mobile/lib/features/matchmaking/presentation/providers/matchmaking_provider.dart` line 303
- **Category:** Bug
- **Description:** `cancelSearch()` calls `ref.read(_cancel1v1PoolProvider)().catchError((_) => false)`. The `catchError` returns `false` for ANY error, not just "pool entry already gone". If the CF fails for a network or permission reason, the `waiting_pool` doc may remain active, causing the user to be matched again immediately after cancel. The current behaviour silently resets state to idle even if the server-side cancel failed.
- **Evidence:**
  ```dart
  await ref.read(_cancel1v1PoolProvider)().catchError((_) => false);
  ```
- **Recommendation:** Mirror the pattern in `leaveRoom()` which distinguishes "not found" (acceptable) from other errors. At minimum, log unexpected cancel failures to Crashlytics so they surface in monitoring. A stricter fix would surface the error to the user and not reset to idle if the cancel definitely failed.

---

### F-002 — `_lastKnownRoomId` field is a subtle cross-state sentinel — needs a comment
- **Severity:** LOW
- **File:** `apps/mobile/lib/features/matchmaking/presentation/providers/matchmaking_provider.dart` line 131–132
- **Category:** Style
- **Description:** `_lastKnownRoomId` is used as a cross-state-reset sentinel to skip stale `waiting_pool` entries that the Firestore local cache delivers before the CF's pool reset propagates. The comment at the field declaration is clear, but callers (`_requeue1v1`, `join1v1Pool`, `cancelSearch`) each have their own local reasoning for why they set or read this field. A future maintainer adding a new path might forget to update `_lastKnownRoomId`, causing the stale-skip guard to not fire.
- **Evidence:** Field at line 131–132 with comment; used in 4 separate code paths.
- **Recommendation:** The existing comments are good. Add a brief note at the top of `_subscribeToMatch` explaining the expected invariant: `skipRoomId` should always equal the room the user was most recently in.

---

### F-003 — `SharedPreferences` for `interestText` persistence is correct
- **Severity:** INFO
- **File:** `apps/mobile/lib/features/matchmaking/presentation/providers/matchmaking_provider.dart` line 145–155
- **Category:** Style
- **Description:** `interestText` is persisted to `SharedPreferences` so the user's interest carries across app restarts. This is appropriate for non-sensitive, user-visible text. The `.catchError((_) => false)` on the async write is acceptable — interest text loss on prefs failure is not critical.
- **Evidence:** `setInterestText()` and `loadSavedInterestText()` methods.
- **Recommendation:** None.

---

### F-004 — `FirebaseFunctions.instanceFor(region: 'us-central1')` hardcoded in DI
- **Severity:** INFO
- **File:** `apps/mobile/lib/features/matchmaking/presentation/providers/matchmaking_provider.dart` line 30
- **Category:** Style
- **Description:** The region is hardcoded rather than read from an environment config. This is correct for the current single-region deployment and acceptable given the project setup. If the region ever changes, this is a single point of update (good).
- **Evidence:** `FirebaseFunctions.instanceFor(region: 'us-central1')`.
- **Recommendation:** None. Document in CLAUDE.md that the `us-central1` value must match the deployed function region.

---

## Clean Architecture Compliance

| Layer | Imports | Violations |
|-------|---------|------------|
| `domain/entities/` | Pure Dart | None |
| `domain/repositories/` | Domain only | None |
| `domain/usecases/` | Domain only | None |
| `data/models/` | `json_annotation`, `freezed_annotation`, domain | None |
| `data/datasources/` | `cloud_firestore`, `cloud_functions`, `firebase_database`, `firebase_auth` | None — all SDK calls in datasource layer |
| `data/repositories/` | Domain + data | None |
| `presentation/providers/` | Riverpod, `cloud_firestore`, `cloud_functions`, `firebase_database`, `firebase_auth`, `shared_preferences` | None — DI wiring is the correct place for SDK instantiation |
| `presentation/screens/` | Flutter, Riverpod, domain | None |

---

## Test Coverage Assessment

| Component | Has Test | Has Sentinel Test | Gaps |
|-----------|----------|-------------------|------|
| `MatchmakingStatus` enum | ✅ | N/A | None |
| `Room` entity | ✅ | N/A | None |
| `RoomMode` enum | ✅ | N/A | None |
| `RoomStatus` enum | ✅ | N/A | None |
| `JoinGroupRoom` use case | ✅ | N/A | None |
| `CreateCustomRoom` use case | ✅ | N/A | None |
| `JoinRoomById` use case | ✅ | N/A | None |
| `LeaveRoom` use case | ✅ | N/A | None |
| `Join1v1Pool` use case | ✅ | N/A | None |
| `Cancel1v1Pool` use case | ✅ | N/A | None |
| `SetRoomLock` use case | ✅ | N/A | None |
| `WatchRoom` use case | ✅ | N/A | None |
| `Watch1v1Match` use case | ✅ | N/A | None |
| `MatchmakingRepositoryImpl` | ✅ | N/A | None |
| `MatchmakingState.copyWith` | ✅ | ✅ (roomId, currentRoom, error null-clear) | None |
| `MatchmakingNotifier` | ✅ | ✅ | None |
| Matchmaking screens | ✅ | N/A | None |

---

## What Is Working Well

- Sentinel pattern applied correctly to `roomId?`, `currentRoom?`, `error?` in `MatchmakingState.copyWith` ✅
- `_lastKnownRoomId` guard prevents stale Firestore cache entries from triggering a false match ✅
- `_subscribeToRoom` handles all room lifecycle events: null (room gone), expired (tombstone), padding (partner left), active (normal) ✅
- `ref.onDispose(_cancelSubscriptions)` ensures streams are cleaned up on provider disposal ✅
- `_requeue1v1` correctly captures `previousRoomId` before clearing state for the stale-skip guard ✅
- `_subscribeToMatch` correctly skips the old room ID to avoid processing a stale pool entry ✅
- `registerRoomPresence()` called after match to set up RTDB `onDisconnect` cleanup ✅
- All guard conditions at the top of action methods prevent double-invocation ✅
- `containsAll` + length assertion used for `MatchmakingStatus` and `RoomStatus` enum tests ✅
- No Firebase SDK in any test file ✅
