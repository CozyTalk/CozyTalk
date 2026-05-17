# Feature: matchmaking

1v1 pool matching and group room joining. All matching logic runs in Cloud Functions — never on client.

## File Map

```
features/matchmaking/
├── domain/
│   ├── entities/
│   │   ├── matchmaking_status.dart    MatchmakingStatus enum
│   │   └── room.dart                  Room (roomId, roomType, mode, status, ...)
│   ├── repositories/matchmaking_repository.dart  abstract MatchmakingRepository
│   └── usecases/
│       ├── cancel_1v1_pool.dart       Cancel1v1Pool
│       ├── create_custom_room.dart    CreateCustomRoom
│       ├── join_1v1_pool.dart         Join1v1Pool
│       ├── join_group_room.dart       JoinGroupRoom
│       ├── join_room_by_id.dart       JoinRoomById
│       ├── leave_room.dart            LeaveRoom
│       ├── set_room_lock.dart         SetRoomLock
│       ├── watch_1v1_match.dart       Watch1v1Match
│       └── watch_room.dart            WatchRoom
├── data/
│   ├── datasources/matchmaking_datasource.dart        MatchmakingDatasourceImpl
│   ├── models/room_model.dart                         @freezed RoomModel + toEntity()
│   └── repositories/matchmaking_repository_impl.dart
└── presentation/
    ├── providers/matchmaking_provider.dart            matchmakingNotifierProvider, MatchmakingNotifier, MatchmakingState
    └── screens/matchmaking_test_screen.dart           MatchmakingTestScreen (dev/test only)
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `matchmakingNotifierProvider` | `NotifierProvider<MatchmakingNotifier, MatchmakingState>` | room lifecycle |

## State

`MatchmakingStatus` enum: `idle | searching | waiting1v1 | matched | creating | error`

`MatchmakingState` — `status`, `room` (Room?), `error` (String?)

`Room` entity fields: `roomId` (String), `roomType` (RoomType: public|custom), `mode` (RoomMode: oneToOne|group), `status` (RoomStatus: active|padding|expired)

## Room Types

| Dimension | Values | Meaning |
|---|---|---|
| `mode` | `1v1` / `group` | 2 users vs 2–5 users |
| `roomType` | `public` / `custom` | pool-matched vs created with custom ID |

## Key Behavior

- 1v1 flow: `join1v1Pool` (CF) → `match1v1Users` Firestore trigger fires → `watch1v1Match` stream picks up result
- Group flow: `joinGroupRoom` (CF) — 3-phase: find candidate rooms → compute cosine similarity → join or create
- Custom room: `createCustomRoom` (CF) → share 5-char room ID → partner uses `joinRoomById` (CF)
- `cancel1v1Pool` returns `{success: false, reason: "matching_in_progress"}` if already matching — Flutter must handle this case
- Interest vectors: Vertex AI `text-multilingual-embedding-002`, 256 dims, cosine threshold 0.65
- Stored in `waiting_pool/{uid}.interestVector` (256-element array); text cached in `SharedPreferences`
- `match1v1Users` CF deployed to `asia-southeast1` (co-located with RTDB — intentional for RTDB write latency)

## Production Screens

- `screens/finding_room_screen.dart` — `FindingRoomScreen` (StatefulWidget — not yet integrated)
- `screens/choose_room_type_screen.dart` — `ChooseRoomTypeScreen` (StatefulWidget — not yet integrated)
- `screens/join_room_id_screen.dart` — `JoinRoomIdScreen` (StatefulWidget — not yet integrated)
- `screens/group_chat_screen.dart` — `GroupChatScreen` (⚠️ partial — `ConsumerStatefulWidget` but uses `shared/` providers only, not wired to `chatNotifierProvider`)

## Notes

- `ref impl #3` — third canonical CA example
- All race conditions handled server-side (Firestore transactions in CFs)
- Client must never call matchmaking Firestore APIs directly — always through CF callable
