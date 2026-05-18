# Friends Feature

Prototype implementation — dev/test only. Not wired to production `screens/`.

---

## Overview

Allows users to send friend requests, accept or decline them, and chat permanently with each accepted friend.

---

## Firestore Collections

| Collection | Purpose |
|---|---|
| `friend_requests/{id}` | Pending / resolved friend requests |
| `friendships/{id}` | One doc per accepted pair; ID = sorted UIDs joined with `_` |
| `friend_messages/{id}/messages/{id}` | Permanent chat messages between friends |

See `docs/database/schema.md` for full field lists and security rules.

---

## Domain Layer

**Entities** (`domain/entities/`)

| Entity | Key fields |
|---|---|
| `AppUser` | `uid`, `displayName` — lightweight view of any user for search |
| `Friend` | `friendshipId`, `friendUid`, `friendDisplayName`, `chatRoomId`, `friendedAt` |
| `FriendRequest` | `id`, `fromUid`, `fromDisplayName`, `toUid`, `status` (enum), `createdAt` |
| `FriendMessage` | `id`, `senderId`, `senderDisplayName`, `text`, `timestamp` |

**Use cases** (`domain/usecases/`)

`WatchAllUsers` · `WatchFriends` · `WatchIncomingRequests` · `WatchFriendMessages` · `SendFriendRequest` · `AcceptFriendRequest` · `DeclineFriendRequest` · `RemoveFriend` · `SendFriendMessage`

---

## Data Layer

**Models** — `@freezed` DTOs with `toEntity()` extensions. Firestore `Timestamp` fields are normalised to `int` milliseconds before `fromJson`.

**`FriendsDatasourceImpl`** — direct Firestore writes (no Cloud Function). The `acceptFriendRequest` method uses a Firestore batch to atomically update the request status and create the `friendships` doc.

**Friendship ID** — deterministic: `[uid1, uid2]..sort()` joined with `_`. Used as both the `friendships` document ID and the `friend_messages` sub-collection path.

---

## Presentation Layer

### Providers

| Provider | Type | Purpose |
|---|---|---|
| `friendsNotifierProvider` | `NotifierProvider<FriendsNotifier, FriendsState>` | Friends list + incoming requests + all-users list; subscriptions started in `build()` |
| `friendChatNotifierProvider` | `NotifierProvider<FriendChatNotifier, FriendChatState>` | Single active chat; `enterChat(roomId, name)` starts subscription, `leaveChat()` cancels it |

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
