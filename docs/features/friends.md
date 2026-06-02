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

`WatchAllUsers` · `WatchFriends` · `WatchIncomingRequests` · `WatchFriendMessages` · `SendFriendRequest` · `AcceptFriendRequest` · `DeclineFriendRequest` · `RemoveFriend` · `SendFriendMessage` · `WatchFriendPresence` · `WatchFriendLastMessage` · `WatchFriendRoom` · `GetUnreadMessageCount` · `SetChatRead` · `WatchChatRead`

---

## Data Layer

**Models** — `@freezed` DTOs with `toEntity()` extensions. Firestore `Timestamp` fields are normalised to `int` milliseconds before `fromJson`.

**`FriendsDatasourceImpl`** — direct Firestore and RTDB reads/writes (no Cloud Function). Constructor takes `FirebaseFirestore`, `FirebaseAuth`, and `FirebaseDatabase`.

- `acceptFriendRequest`: Firestore batch (update request + create friendship doc), then writes `friends/{currentUid}/{fromUid}: true` and `friends/{fromUid}/{currentUid}: true` to RTDB.
- `watchFriendPresence(friendUid)`: streams `user_status/{friendUid}` existence as `bool`.
- `watchFriendLastMessage(chatRoomId)`: streams `({String text, DateTime? timestamp, String senderId})` from the latest message in `friend_messages/{chatRoomId}/messages` (descending by timestamp, limit 1). Emits `(text: '', timestamp: null, senderId: '')` when no messages exist.
- `watchFriendRoom(friendUid)`: streams `user_status/{friendUid}` and emits a `FriendRoomStatus` when `status == 'in_room'`; emits `null` otherwise. Reads `roomId`, `memberCount`, `maxUsers`, `isLocked`, `roomMode`, `backgroundTheme` from RTDB. If `backgroundTheme` is absent from the RTDB node (e.g. written before the theme field was added, or before `OwnStatusNotifier` re-fired with the Firestore room data), the datasource performs a one-shot `rooms/{roomId}` Firestore read to fill in the theme. Errors in the fallback read are swallowed — the card renders with a null theme (fallback label) rather than failing.

**Friendship ID** — deterministic: `[uid1, uid2]..sort()` joined with `_`. Used as both the `friendships` document ID and the `friend_messages` sub-collection path.

---

## Presentation Layer

### State — `FriendsState`

| Field | Type | Purpose |
|---|---|---|
| `friends` | `List<Friend>` | Active friendships |
| `incomingRequests` | `List<FriendRequest>` | All friend requests addressed to the current user (all statuses); sorted newest-first, capped at 10 client-side |
| `pendingActions` | `Map<String, String>` | Local-only deferred decisions: `requestId → 'accepted' \| 'declined' \| 'undoing'`; committed to Firestore when the user leaves `NotificationScreen` |
| `allUsers` | `List<AppUser>` | All users (for friend search in dev screens) |
| `isLoading` | `bool` | Mutation in progress |
| `error` | `String?` | Last error message; cleared by `clearError()` |
| `presenceMap` | `Map<String, bool>` | keyed by `friendUid` — `true` when `user_status` node exists |
| `lastMessageMap` | `Map<String, String>` | keyed by `chatRoomId` — last message text |
| `lastMessageTimestampMap` | `Map<String, DateTime?>` | keyed by `chatRoomId` — timestamp of the most recent message; `null` when no messages exist |
| `roomMap` | `Map<String, FriendRoomStatus?>` | keyed by `friendUid` — current room or `null` |
| `unreadCountMap` | `Map<String, int>` | keyed by `chatRoomId` — count of unread messages from the friend (not from self); recomputed from the server read marker and incremented per incoming message |

Per-friend enrichment subscriptions are managed by `_updateEnrichmentSubscriptions()` in `FriendsNotifier`, called whenever the `friends` list changes. Stale subscriptions are cancelled when a friend is removed.

**Unread count (server-authoritative read marker)** — the read marker lives in Firestore at `friend_messages/{chatRoomId}/reads/{uid}` as `{ lastReadAt: Timestamp }`, written with `serverTimestamp()`. Because the marker and message `timestamp`s both come from the server clock, the unread boundary has no client-clock skew, and the marker syncs across devices.

- Each room subscribes to `watchChatRead(chatRoomId)`. On every emission (initial load, this device marking read, or another device marking read), `_recomputeUnread` runs `getUnreadMessageCount(sinceMs: lastReadAt, friendUid:)` and sets `unreadCountMap[chatRoomId]` to the exact count.
- `getUnreadMessageCount` counts the **trailing run** of the friend's messages newest-first, stopping at the first message the current user sent — so if the last message is the user's own, the count is 0. `sinceMs = 0` (no marker yet) counts that trailing run over all history.
- New messages arriving while the app is open bump the badge by 1 (`watchFriendLastMessage`), except for the chat the user is currently viewing (`_activeChatRoomId`).
- `setActiveChat`/`clearActiveChat` (called by `FriendChatNotifier.enterChat`/`leaveChat`) mark the room active and write the read marker via `markChatRead` (which calls `setChatRead` + clears the badge optimistically). `markChatAsRead(chatRoomId)` is an in-memory-only optimistic clear used on a friend-card tap.

### Providers

| Provider | Type | Purpose |
|---|---|---|
| `friendsDatasourceProvider` | `Provider<FriendsDatasource>` | Shared datasource instance |
| `friendsRepositoryProvider` | `Provider<FriendsRepository>` | Shared repository instance |
| `friendsNotifierProvider` | `NotifierProvider<FriendsNotifier, FriendsState>` | Friends list + requests + enrichment maps |
| `friendChatNotifierProvider` | `NotifierProvider<FriendChatNotifier, FriendChatState>` | Single active chat; `enterChat(roomId, name)` starts subscription |

### Production Screens

`FriendsScreen` (`screens/friends_screen.dart`) — integrated with `friendsNotifierProvider`. Maps `domain.Friend` → screen `Friend` model via `_toScreenFriend(f, state)`, pulling `isOnline` from `presenceMap`, `lastMessage` from `lastMessageMap`, and `room` (as `RoomInfo`) from `roomMap`. The list is sorted by `lastMessageTimestampMap` (most recently messaged first; friends with no messages fall to the bottom). Unread badge count comes directly from `state.unreadCountMap[chatRoomId]` (recomputed from the server read marker; see "Unread count" above). Tapping a friend card calls `markChatAsRead(chatRoomId)` for an optimistic in-memory reset; the chat screen's `enterChat` then writes the authoritative marker. The three-dot menu shows **Block** when the friend is not blocked and **Unblock** when they are. Notes remain local-only state for this prototype.

`HomeScreen` (`screens/home_screen.dart`) — the Friends `_QuickAction` box displays a red dot badge in its top-right corner when `unreadCountMap.values.any((c) => c > 0)`. The bell/notification icon badge reflects only `incomingRequests.isNotEmpty` (friend requests).

### Friend Request Popup (any screen)

When a friend request arrives, a slide-down banner overlays the active screen — including chat rooms, the finding-room screen, and any other route. The banner has Accept and Decline buttons and auto-dismisses after 5 seconds; the user can also swipe up to dismiss it early.

**Implementation:** `_FriendRequestListener` in `main.dart` is a `ConsumerStatefulWidget` that wraps the authenticated home widget in `_MainUIAuthRouter`. Its `build()` calls `ref.listen` on `friendsNotifierProvider.select((s) => s.incomingRequests)`. Because it is mounted above the `Navigator`'s route stack, its `Overlay.of(context)` is the root overlay, so `OverlayEntry` banners render above all pushed routes.

**New-request detection:** `_FriendRequestListenerState` owns a `Set<String>? _seenIds`. On the first emission (app launch / sign-in), all current pending request IDs are seeded silently so pre-existing requests do not produce a popup. Only IDs absent from `_seenIds` on subsequent emissions trigger `showFriendRequestPopup()`.

**Popup widget:** `apps/mobile/lib/shared/friend_request_popup.dart` — `showFriendRequestPopup(context, {requesterName, fromUid, onAccept, onDecline, autoDismissAfter})`. Inserts an `OverlayEntry` with a slide animation; renders the sender's live avatar via `avatarDecorationByUidProvider(fromUid)`; a `_dismissed` flag prevents double-dismiss if the timer fires while the user is already swiping.

**Join-friend-room shortcut** — When a friend's `roomMap` entry is non-null and they're online, the friend card renders a `FriendRoomCard` (`screens/widgets.dart`) showing the live room (thumbnail + name derived from `backgroundTheme` via `resolveRoomTheme()` in `theme/room_themes.dart`; falls back to "Group Room"/"1v1 Room" when theme is null). Tapping **Join** navigates to `AppRoutes.findingRoom` with `{roomType: 'joinById', roomId, isGroup: true, roomName, bgImage}` — `roomName` and `bgImage` are the resolved display values passed so `FindingRoomScreen` can forward them to the chat screen for immediate display before `currentRoom` loads from Firestore. `GroupChatScreen` additionally overrides `roomName`/`bgImage` with live `matchState.currentRoom?.backgroundTheme` via `resolveRoomTheme()` once the Firestore subscription delivers, ensuring the header always reflects the ground truth. The **Join** button is hidden for 1v1 rooms (privacy: no third-party joins), disabled/replaced with **Locked** or **Full** badges when the room is unavailable, and rendered as a **greyed-out Join** (non-tappable) when either party has blocked the other — checked via `friend.isBlocked` (current user blocked the friend) OR `isBlockedByProvider(friendUid)` (friend blocked the current user). The same block guard applies to the "CURRENTLY IN" banner in `FriendChatScreen`. `memberCount` defaults to 1 (not 0) when the field is absent from an older RTDB entry written before the join-shortcut feature was deployed.

`FriendChatScreen` (`screens/friend_chat_screen.dart`) — integrated with `friendChatNotifierProvider`. Receives a `Friend` (screen model) from route arguments. Calls `enterChat(chatRoomId, username)` on first frame and `leaveChat()` on dispose. Renders real messages from `FriendChatState.messages`; `isMe` is derived from `senderId == authNotifierProvider.user.uid`. Shows loading indicator and sending indicator from state. The date label + safety notice banner are always rendered above the message list, even when there are no messages yet. Errors surface as SnackBar via `ref.listen`. A "CURRENTLY IN" banner pulls the partner's live room state from `friendsNotifierProvider.roomMap[partnerUid]` (not from stale route args) and offers a **Join** action with the same logic as `FriendsScreen`.

`NotificationScreen` (`screens/notification_screen.dart`) — integrated with `friendsNotifierProvider.incomingRequests`. Uses a **deferred-write pattern**: tapping Accept or Decline queues the decision in `pendingActions` locally (showing the card greyed-out immediately). The Firestore write happens only when the user presses Back (`commitPendingActions()`), called via `PopScope.onPopInvokedWithResult` and the custom app bar back button. Tapping a grey card undoes the queued action (`undoPendingAction` — local only) or reverts an already-committed action (`undoCommittedAction` — Firestore write reverting status back to `'pending'`). The history shows up to 10 cards (all statuses, newest-first); badge counts and the Requests tab in `FriendsListScreen` filter to `status == pending` only.

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
