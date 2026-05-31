# Block Feature

User-level blocking. A user can block up to 5 other users. Blocked relationships are enforced during room joining and 1v1 matching.

## Domain

| Class | File |
|---|---|
| `BlockedUser` | `domain/entities/blocked_user.dart` |
| `BlockRepository` | `domain/repositories/block_repository.dart` |
| `WatchBlockedUsers` | `domain/usecases/watch_blocked_users.dart` |
| `BlockUser` | `domain/usecases/block_user.dart` |
| `UnblockUser` | `domain/usecases/unblock_user.dart` |
| `WatchIsBlockedBy` | `domain/usecases/watch_is_blocked_by.dart` — streams `true` when `partnerUid` has blocked `myUid` |

## Data

| Class | File |
|---|---|
| `BlockedUserModel` | `data/models/blocked_user_model.dart` — `@freezed` DTO with `TimestampConverter` |
| `BlockDatasourceImpl` | `data/datasources/block_datasource.dart` — streams Firestore subcollection; calls `blockUser`/`unblockUser` CFs; `watchIsBlockedBy(partnerUid, myUid)` reads `users/{partnerUid}/blocked/{myUid}` |
| `BlockRepositoryImpl` | `data/repositories/block_repository_impl.dart` |

## Presentation

| Class | File |
|---|---|
| `BlockState` | `presentation/providers/block_provider.dart` — fields: `status`, `blockedUsers`, `isSubmitting`, `error` |
| `BlockNotifier` | `presentation/providers/block_provider.dart` — subscribes in `build()` via `authNotifierProvider`; `block()` + `unblock()` actions |
| `blockNotifierProvider` | `presentation/providers/block_provider.dart` |
| `isBlockedByProvider` | `presentation/providers/block_provider.dart` — `StreamProvider.family<bool, String>`; param is `partnerUid`; returns `true` when that partner has blocked the current user |

## Firestore

Collection: `users/{uid}/blocked/{blockedUid}`

| Field | Type |
|---|---|
| `blockedUid` | string |
| `displayName` | string? |
| `blockedAt` | Timestamp |

Max 5 entries per user.

Security rules: owner has full read/write; the blocked person (`request.auth.uid == blockedId`) has read-only access so `isBlockedByProvider` can check whether they are blocked without exposing the owner's full list.

## Room Block Enforcement

`rooms/{roomId}.blockList`: `Array<{ blockedBy, userId, amount }>`

- `joinGroupRoom` / `joinRoomById`: checks blocklist before join; merges on success
- `leaveRoom`: decrements entries on leave
- `match1v1Users`: skips mutually-blocked pairs

## Admin

`adminGetBlockedUsers` CF lets admins view a user's block list. Surfaced via `AdminUsersNotifier.loadBlockedUsers(uid)` in the admin console Users tab.
