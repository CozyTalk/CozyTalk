# Feature: user_status

RTDB-backed online/in-room/offline presence. Any screen can watch any user's status in real time. `OwnStatusNotifier` manages the current user's own status automatically by reacting to auth and matchmaking state changes — no manual calls needed from screens.

## File Map

```
features/user_status/
├── domain/
│   ├── entities/user_status.dart          UserStatus (uid, status: UserOnlineStatus, roomId?, roomMode?)
│   │                                       UserOnlineStatus enum: online | inRoom | offline
│   ├── repositories/user_status_repository.dart  abstract UserStatusRepository
│   └── usecases/
│       ├── set_online.dart                SetOnline — writes status:'online' to RTDB user_status/{uid}
│       ├── set_in_room.dart               SetInRoom — writes status:'in_room', roomId, roomMode
│       ├── clear_status.dart              ClearStatus — deletes user_status/{uid} node entirely (sign-out)
│       └── watch_user_status.dart         WatchUserStatus — streams any uid's status; emits UserOnlineStatus.offline on absent node
├── data/
│   ├── datasources/user_status_datasource.dart        UserStatusDatasourceImpl (FirebaseDatabase + FirebaseAuth)
│   ├── models/user_status_model.dart                  @freezed UserStatusModel + toEntity()
│   └── repositories/user_status_repository_impl.dart
└── presentation/
    └── providers/user_status_provider.dart
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `watchUserStatusProvider` | `StreamProvider.family<UserStatus, String>` | watch any user's live status by uid |
| `ownStatusNotifierProvider` | `NotifierProvider<OwnStatusNotifier, void>` | lifecycle manager for the current user's own status |

`OwnStatusNotifier` has no public methods — it is purely reactive. Keep it alive from the root widget (`ref.watch(ownStatusNotifierProvider)` in `_MainUIAuthRouter` or equivalent).

## RTDB Path

`user_status/{uid}` — `{ status: 'online' | 'in_room', roomId?: string, roomMode?: string, maxUsers?: number, memberCount?: number, isLocked?: boolean, backgroundTheme?: string }`

`maxUsers`, `memberCount`, `isLocked`, and `backgroundTheme` are only present when `status == 'in_room'`. They let friends render the "currently in" room card without a Firestore read (non-members cannot read `rooms/{roomId}`). The node is deleted entirely on sign-out (not set to offline) to avoid stale data.

Read rule: own UID + `friends/{uid}/{auth.uid} === true` (friends can read each other's status). Write rule: own UID only.

## Key Behavior

`OwnStatusNotifier.build()` sets up two `ref.listen` callbacks that run for the lifetime of the provider:

1. **Auth listener** (`authNotifierProvider`):
   - `authenticated` → `setOnline()` (fires immediately on first build via `fireImmediately: true`)
   - `unauthenticated` (transitioning from authenticated) → `clearStatus()`

2. **Matchmaking listener** (`matchmakingNotifierProvider`):
   - `status == matched && roomId != null` → `setInRoom(roomId, mode, maxUsers, memberCount, isLocked, backgroundTheme)`. Writes immediately on match using defaults when `currentRoom` is not yet loaded, then re-fires each time `currentRoom` changes (Firestore subscription delivery). Change detection uses a multi-field fingerprint: the write is skipped only when `roomId`, `memberCount`, `isLocked`, `backgroundTheme`, **and** the `Room?` Freezed object reference are all identical to the last written values — ensuring null→non-null transitions (e.g. first Firestore snapshot) always trigger a refresh.
   - leaving matched state → resets all fingerprint fields to `null`, calls `setOnline()`

All use case calls log errors via `debugPrint` but do not rethrow — presence is best-effort and must not crash the app.

## Usage

```dart
// Watch another user's status (e.g. in friends list)
final status = ref.watch(watchUserStatusProvider(friendUid));

// Keep own status synced (do this once at the root widget)
ref.watch(ownStatusNotifierProvider);
```

Do not call `SetOnline`, `SetInRoom`, or `ClearStatus` directly from screens — `OwnStatusNotifier` manages these automatically.
