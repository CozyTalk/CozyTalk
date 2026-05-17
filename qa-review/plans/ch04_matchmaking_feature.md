# Chapter 4 Plan — Matchmaking Feature (Flutter)

## Scope

```
apps/mobile/lib/features/matchmaking/
├── data/
│   ├── datasources/matchmaking_datasource.dart
│   ├── models/room_model.dart (.freezed.dart, .g.dart)
│   └── repositories/matchmaking_repository_impl.dart
├── domain/
│   ├── entities/ (matchmaking_status.dart, room.dart)
│   ├── repositories/matchmaking_repository.dart
│   └── usecases/ (9 use cases — join1v1, cancel, join group, create custom,
│                    join by id, leave, set lock, watch match, watch room)
└── presentation/
    ├── providers/matchmaking_provider.dart
    └── screens/matchmaking_test_screen.dart

apps/mobile/test/features/matchmaking/ (all test files)
```

---

## Checks to Perform

### 4.1 Domain Layer Purity
- [ ] `room.dart` and `matchmaking_status.dart` — zero Flutter/Firebase imports.
- [ ] `matchmaking_repository.dart` — abstract interface; no Firestore types leaked in.
- [ ] `Room` entity fields match CLAUDE.md spec: 5-char roomId, status, users, roomType, etc.
- [ ] `MatchmakingStatus` enum — all values covered; check what values exist vs what CLAUDE.md says.

### 4.2 Room Model (Freezed)
- [ ] `RoomModel` has `fromJson` delegating to generated code.
- [ ] `toEntity()` maps all fields correctly.
- [ ] `interestVector` field (256-dim embedding) — represented as `List<double>?` in model and entity.
- [ ] `interestText` field — `String?` in model.
- [ ] `roomId` — 5-char alphanumeric; model doesn't validate length (validation is CF's job).
- [ ] Firestore timestamp fields (`createdAt`, `updatedAt`, `expiresAt`) — handled as `Timestamp` or `DateTime`? Confirm consistent conversion.

### 4.3 Matchmaking Datasource
- [ ] `join1v1Pool` — passes `interestText?` to Cloud Function; CF returns roomId or null.
- [ ] `cancel1v1Pool` — calls CF; handles case where user was already matched.
- [ ] `joinGroupRoom` — passes `interestText?` to CF.
- [ ] `createCustomRoom` — calls CF; stores returned roomId.
- [ ] `joinRoomById` — validates roomId non-empty before CF call.
- [ ] `leaveRoom` — calls `leaveRoom` CF; handles room-not-found gracefully.
- [ ] `setRoomLock` — calls CF; correct param name matches CF signature.
- [ ] `watchMatch` — watches `waiting_pool/{uid}` for `status == 'matched'` and `roomId` field.
- [ ] `watchRoom` — watches `rooms/{roomId}` Firestore document.
- [ ] All CF calls use `FirebaseFunctions.instanceFor(region: 'us-central1')`.
- [ ] Map normalization applied: `Map<String, dynamic>.from(data as Map)`.
- [ ] No raw exceptions swallowed.

### 4.4 MatchmakingRepositoryImpl
- [ ] Implements all 9 use cases' repository interface methods.
- [ ] Model→entity conversion on watch streams.
- [ ] CF errors propagated — not caught and discarded.

### 4.5 Use Cases (9 total)
- [ ] Each has a single `call()` method.
- [ ] Args forwarded exactly.
- [ ] Result returned unchanged.
- [ ] Exception propagates.
- [ ] `watch1v1Match` and `watchRoom` return `Stream<T>` — not `Future<Stream<T>>`.

### 4.6 MatchmakingState & Notifier (`matchmaking_provider.dart`)
- [ ] State fields: verify against actual code (CLAUDE.md doesn't fully spec this state).
- [ ] All nullable fields use sentinel pattern.
- [ ] Session state machine: `Idle → Searching → Matched/Chatting → Disconnected`.
- [ ] State machine is explicit — no state inferred from nullable field being null.
- [ ] Loading guards on all submit actions.
- [ ] On match found: notifier transitions to `Matched` state and navigates to chat.
- [ ] On cancel: notifier transitions back to `Idle`, not `Disconnected`.
- [ ] Stream subscriptions (watchMatch, watchRoom) cancelled on dispose or leave.
- [ ] DI chain correct.

### 4.7 Matchmaking Test Screen
- [ ] This is a dev/test screen — not exposed in production UI.
- [ ] Has a "Test Matchmaking" button.
- [ ] Uses proper `_FakeMatchmakingNotifier` pattern in tests (not real Firebase).

### 4.8 Test Coverage
- [ ] `matchmaking_status_test.dart` — all enum values, single containsAll + length assertion.
- [ ] `room_test.dart` — construction, optional fields null, interestVector null.
- [ ] `room_model_test.dart` — fromJson all fields / with nulls / extra keys; toEntity correct.
- [ ] `matchmaking_repository_impl_test.dart` — all 9 methods: call counts, arg forwarding, model→entity, exception propagation.
- [ ] All 9 use case tests — args, result, exception.
- [ ] `matchmaking_state_test.dart` — sentinel pattern tests for all nullable fields.
- [ ] `matchmaking_test_screen_test.dart` — renders, button calls notifier, state display.
- [ ] `shared_fakes.dart` — `FakeMatchmakingRepository` covers all 9 methods.
- [ ] No Firebase SDK in tests.

### 4.9 Context-Aware Interest Matching (Flutter Side)
- [ ] `interestText` is passed from UI input through use case → datasource → CF call.
- [ ] UI does NOT call Vertex AI directly — it passes text; CF does embedding.
- [ ] If user skips interest input, `interestText` is null — CF falls back to FIFO.
- [ ] `interestVector` in `waiting_pool` doc is read-back handled correctly (List<double> deserialization from Firestore array).

---

## Files to Read in Full

1. `apps/mobile/lib/features/matchmaking/domain/entities/room.dart`
2. `apps/mobile/lib/features/matchmaking/domain/entities/matchmaking_status.dart`
3. `apps/mobile/lib/features/matchmaking/domain/repositories/matchmaking_repository.dart`
4. `apps/mobile/lib/features/matchmaking/data/datasources/matchmaking_datasource.dart`
5. `apps/mobile/lib/features/matchmaking/data/models/room_model.dart`
6. `apps/mobile/lib/features/matchmaking/data/repositories/matchmaking_repository_impl.dart`
7. `apps/mobile/lib/features/matchmaking/presentation/providers/matchmaking_provider.dart`
8. `apps/mobile/lib/features/matchmaking/presentation/screens/matchmaking_test_screen.dart`
9. All test files in `apps/mobile/test/features/matchmaking/`

---

## Expected Findings Categories

- Stream subscriptions not cancelled on dispose (HIGH)
- State machine not exhaustive (MEDIUM)
- Missing sentinel tests (HIGH)
- `interestVector` deserialization from Firestore not handled (MEDIUM)
- CF region not set (`us-central1`) (MEDIUM)
- Watchroom/watchMatch returning Future<Stream> instead of Stream (HIGH)

---

## Output

Write findings to `reviews/ch04_matchmaking_feature.md`.
