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

`user_status/{uid}` — `{ status: 'online' | 'in_room', roomId?: string, roomMode?: string }`

Read rule: own UID. Write rule: own UID. Node is deleted entirely on sign-out (not set to offline) to avoid stale data.

## Key Behavior

`OwnStatusNotifier.build()` sets up two `ref.listen` callbacks that run for the lifetime of the provider:

1. **Auth listener** (`authNotifierProvider`):
   - `authenticated` → `setOnline()` (fires immediately on first build)
   - `unauthenticated` (transitioning from authenticated) → `clearStatus()`

2. **Matchmaking listener** (`matchmakingNotifierProvider`):
   - `status == matched && roomId != null && roomId != lastReportedRoomId` → `setInRoom(roomId, mode)`; updates `lastReportedRoomId` guard to prevent redundant RTDB writes as `currentRoom` populates incrementally
   - leaving matched state → `lastReportedRoomId = null`, `setOnline()`

All use case calls swallow errors silently (`catchError((_) {})`) — presence is best-effort and must not crash the app.

## Usage

```dart
// Watch another user's status (e.g. in friends list)
final status = ref.watch(watchUserStatusProvider(friendUid));

// Keep own status synced (do this once at the root widget)
ref.watch(ownStatusNotifierProvider);
```

Do not call `SetOnline`, `SetInRoom`, or `ClearStatus` directly from screens — `OwnStatusNotifier` manages these automatically.
