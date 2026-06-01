# Friends Feature

Prototype implementation. All production screens for the add-friend flow are now integrated: `FriendsScreen`, `FriendChatScreen`, `NotificationScreen`, and the "Add Friend" button in `ChatScreen`/`GroupChatScreen`.

---

## Overview

Allows users to send friend requests, accept or decline them, chat permanently with accepted friends, and see real-time presence and room status for each friend.

---

## Firestore Collections

| Collection | Purpose |
|---|---|
| `friend_requests/{id}` | Pending / resolved friend requests |
| `friendships/{id}` | One doc per accepted pair; ID = sorted UIDs joined with `_` |
| `friend_messages/{id}/messages/{id}` | Permanent chat messages between friends |

See `docs/database/schema.md` for full field lists and security rules.

---

## RTDB Paths

| Path | Purpose |
|---|---|
| `user_status/{uid}` | Read by friends via `friends/{uid}/{auth.uid} === true` rule (see schema.md) |
| `friends/{ownerUid}/{friendUid}` | Denormalized friendship flag (`true`) — used only for RTDB rule evaluation |

---

## Domain Layer

**Entities** (`domain/entities/`)

| Entity | Key fields |
|---|---|
| `AppUser` | `uid`, `displayName` — lightweight view of any user for search |
| `Friend` | `friendshipId`, `friendUid`, `friendDisplayName`, `chatRoomId`, `friendedAt` |
| `FriendRequest` | `id`, `fromUid`, `fromDisplayName`, `toUid`, `status` (enum), `createdAt` |
| `FriendMessage` | `id`, `senderId`, `senderDisplayName`, `text`, `timestamp` |
| `FriendRoomStatus` | `roomId`, `memberCount`, `maxUsers`, `isLocked`, `mode`, `backgroundTheme?` — snapshot of a friend's current room (sourced entirely from RTDB `user_status` — never Firestore) |

**Use cases** (`domain/usecases/`)

`WatchAllUsers` · `WatchFriends` · `WatchIncomingRequests` · `WatchFriendMessages` · `SendFriendRequest` · `AcceptFriendRequest` · `DeclineFriendRequest` · `RemoveFriend` · `SendFriendMessage` · `WatchFriendPresence` · `WatchFriendLastMessage` · `WatchFriendRoom`

---

## Data Layer

**Models** — `@freezed` DTOs with `toEntity()` extensions. Firestore `Timestamp` fields are normalised to `int` milliseconds before `fromJson`.

**`FriendsDatasourceImpl`** — direct Firestore and RTDB reads/writes (no Cloud Function). Constructor takes `FirebaseFirestore`, `FirebaseAuth`, and `FirebaseDatabase`.

- `acceptFriendRequest`: Firestore batch (update request + create friendship doc), then writes `friends/{currentUid}/{fromUid}: true` and `friends/{fromUid}/{currentUid}: true` to RTDB.
- `watchFriendPresence(friendUid)`: streams `user_status/{friendUid}` existence as `bool`.
- `watchFriendLastMessage(chatRoomId)`: streams `({String text, DateTime? timestamp, String senderId})` from the latest message in `friend_messages/{chatRoomId}/messages` (descending by timestamp, limit 1). Emits `(text: '', timestamp: null, senderId: '')` when no messages exist.
- `watchFriendRoom(friendUid)`: streams `user_status/{friendUid}` and emits a `FriendRoomStatus` when `status == 'in_room'` (reading `roomId`, `memberCount`, `maxUsers`, `isLocked`, `roomMode`, `backgroundTheme` directly from RTDB); emits `null` otherwise. No Firestore read — non-members are not allowed to read `rooms/{roomId}` per the security rules, so all room metadata is mirrored on the friend's own `user_status` node by `OwnStatusNotifier` when they enter a room.

**Friendship ID** — deterministic: `[uid1, uid2]..sort()` joined with `_`. Used as both the `friendships` document ID and the `friend_messages` sub-collection path.

---

## Presentation Layer

### State — `FriendsState`

| Field | Type | Purpose |
|---|---|---|
| `friends` | `List<Friend>` | Active friendships |
| `incomingRequests` | `List<FriendRequest>` | Pending requests for the current user |
| `allUsers` | `List<AppUser>` | All users (for friend search in dev screens) |
| `isLoading` | `bool` | Mutation in progress |
| `error` | `String?` | Last error message; cleared by `clearError()` |
| `presenceMap` | `Map<String, bool>` | keyed by `friendUid` — `true` when `user_status` node exists |
| `lastMessageMap` | `Map<String, String>` | keyed by `chatRoomId` — last message text |
| `lastMessageTimestampMap` | `Map<String, DateTime?>` | keyed by `chatRoomId` — timestamp of the most recent message; `null` when no messages exist |
| `roomMap` | `Map<String, FriendRoomStatus?>` | keyed by `friendUid` — current room or `null` |
| `unreadCountMap` | `Map<String, int>` | keyed by `chatRoomId` — count of unread messages from the friend (not from self); incremented per incoming message, reset to 0 by `markChatAsRead(chatRoomId)` |

Per-friend enrichment subscriptions are managed by `_updateEnrichmentSubscriptions()` in `FriendsNotifier`, called whenever the `friends` list changes. Stale subscriptions are cancelled when a friend is removed.

**Unread persistence** — `FriendsNotifier` persists `lastReadAt` (milliseconds epoch) per chatRoom in `SharedPreferences` under the key `friends_last_read_<chatRoomId>`. On the first stream emission after app restart, if the message timestamp is newer than the stored `lastReadAt` and the message was sent by the friend, `unreadCountMap` is initialised to 1. `markChatAsRead(chatRoomId)` is `Future<void>`; it saves the last message timestamp to `SharedPreferences` before resetting the in-memory count. If the key has never been written (first-ever session or before this feature was deployed), no badge is shown on startup.

### Providers

| Provider | Type | Purpose |
|---|---|---|
| `friendsDatasourceProvider` | `Provider<FriendsDatasource>` | Shared datasource instance |
| `friendsRepositoryProvider` | `Provider<FriendsRepository>` | Shared repository instance |
| `friendsNotifierProvider` | `NotifierProvider<FriendsNotifier, FriendsState>` | Friends list + requests + enrichment maps |
| `friendChatNotifierProvider` | `NotifierProvider<FriendChatNotifier, FriendChatState>` | Single active chat; `enterChat(roomId, name)` starts subscription |

### Production Screens

`FriendsScreen` (`screens/friends_screen.dart`) — integrated with `friendsNotifierProvider`. Maps `domain.Friend` → screen `Friend` model via `_toScreenFriend(f, state)`, pulling `isOnline` from `presenceMap`, `lastMessage` from `lastMessageMap`, and `room` (as `RoomInfo`) from `roomMap`. The list is sorted by `lastMessageTimestampMap` (most recently messaged first; friends with no messages fall to the bottom). Unread badge count comes directly from `state.unreadCountMap[chatRoomId]`; the notifier increments it for every incoming message whose `senderId` differs from the current user's UID, so only messages received from the friend (not sent by self) count toward the badge. Tapping a friend card calls `markChatAsRead(chatRoomId)` which resets the count to 0 in state and persists the read timestamp to `SharedPreferences`. The three-dot menu shows **Block** when the friend is not blocked and **Unblock** when they are. Notes remain local-only state for this prototype.

`HomeScreen` (`screens/home_screen.dart`) — the Friends `_QuickAction` box displays a red dot badge in its top-right corner when `unreadCountMap.values.any((c) => c > 0)`. The bell/notification icon badge reflects only `incomingRequests.isNotEmpty` (friend requests).

**Join-friend-room shortcut** — When a friend's `roomMap` entry is non-null and they're online, the friend card renders a `FriendRoomCard` (theme/widgets.dart) showing the live room (thumbnail + name derived from `backgroundTheme` via `resolveRoomTheme()` in `theme/room_themes.dart`; falls back to "Group Room"/"1v1 Room" when theme is null). Tapping **Join** navigates to `AppRoutes.findingRoom` with `{roomType: 'joinById', roomId, isGroup: true, roomName, bgImage}` — `roomName` and `bgImage` are the resolved display values passed so `FindingRoomScreen` can forward them to the chat screen for immediate display before `currentRoom` loads from Firestore. `GroupChatScreen` additionally overrides `roomName`/`bgImage` with live `matchState.currentRoom?.backgroundTheme` via `resolveRoomTheme()` once the Firestore subscription delivers, ensuring the header always reflects the ground truth. The button is hidden for 1v1 rooms (privacy: no third-party joins) and disabled/replaced with **Locked** or **Full** badges otherwise. `memberCount` defaults to 1 (not 0) when the field is absent from an older RTDB entry written before the join-shortcut feature was deployed.

`FriendChatScreen` (`screens/friend_chat_screen.dart`) — integrated with `friendChatNotifierProvider`. Receives a `Friend` (screen model) from route arguments. Calls `enterChat(chatRoomId, username)` on first frame and `leaveChat()` on dispose. Renders real messages from `FriendChatState.messages`; `isMe` is derived from `senderId == authNotifierProvider.user.uid`. Shows loading indicator and sending indicator from state. The date label + safety notice banner are always rendered above the message list, even when there are no messages yet. Errors surface as SnackBar via `ref.listen`. A "CURRENTLY IN" banner pulls the partner's live room state from `friendsNotifierProvider.roomMap[partnerUid]` (not from stale route args) and offers a **Join** action with the same logic as `FriendsScreen`.

`NotificationScreen` (`screens/notification_screen.dart`) — integrated with `friendsNotifierProvider.incomingRequests`. Accept/decline wired to notifier.

**"Add Friend" in active chat sessions** — `ChatScreen` and `GroupChatScreen` call `friendsNotifierProvider.sendFriendRequest(AppUser)` when the "Add friend" button in the partner's `UserProfileDialog` is tapped. Partner identity is resolved from `MatchmakingState.partnerUids` via `getUsersByIdsProvider`. `getUsersByIdsProvider` is a `FutureProvider.autoDispose.family<List<AppUser>, List<String>>` in `friends_provider.dart` that reads `users/{uid}` Firestore docs. Errors surface as SnackBar via `ref.listen`. `isLoading` guard prevents duplicate requests.

### Prototype Screens (dev only)

| Screen | Purpose |
|---|---|
| `FriendsTestScreen` | Dev hub: current user info, all-users list with "Add" buttons, navigation to friends list |
| `FriendsListScreen` | Tabbed view: "Friends" tab (tap to chat, long-press to remove) + "Requests" tab (accept/decline) |
| `FriendDirectChatScreen` | Real-time permanent chat with a specific friend |

Entry point: **HelloScreen → "Test Friends" button**.

---

## Key Design Decisions

- **Plaintext messages** — friend chat stores messages without encryption (prototype only).
- **Permanent history** — no `expiresAt` TTL; messages persist indefinitely.
- **Client-side writes** — no Cloud Function for friendship creation; the batch write atomically updates the request and creates the friendship doc.
- **`users` read broadened** — `firestore.rules` `users/{uid}` read changed from `isOwner` to `isSignedIn` to allow the friends user-search query.
- **RTDB friend-only presence rule** — `user_status/{uid}` is readable by friends, not the public. The `friends/{ownerUid}/{friendUid}: true` RTDB node is the rule anchor; it is client-written on `acceptFriendRequest` and cleaned up server-side by the `onFriendshipDeleted` CF.
- **N+1 enrichment subscriptions** — each friend has separate RTDB and Firestore listeners; acceptable for this prototype's small friend lists.
