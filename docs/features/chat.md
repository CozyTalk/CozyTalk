# Feature: chat

AES-256-GCM encrypted messaging over Firestore, with RTDB presence and typing indicators.

## File Map

```
features/chat/
├── domain/
│   ├── entities/
│   │   ├── chat_message.dart          ChatMessage (id, senderId, displayName, text, timestamp)
│   │   ├── session_status.dart        SessionStatus enum
│   │   ├── shuffle_event.dart         ShuffleEvent (shufflerUid, shufflerName, questionId, questionText, questionCategory, questionDepth)
│   │   └── typing_user.dart           TypingUser (uid, displayName, photoUrl?)
│   ├── repositories/chat_repository.dart  abstract ChatRepository
│   └── usecases/
│       ├── end_session.dart           EndSession
│       ├── send_message.dart          SendMessage
│       ├── set_card_shuffle.dart      SetCardShuffle
│       ├── set_typing.dart            SetTyping
│       ├── watch_card_shuffle.dart    WatchCardShuffle
│       ├── watch_messages.dart        WatchMessages
│       ├── watch_partner_typing.dart  WatchTypingUsers
│       └── watch_presence.dart        WatchPresence
├── data/
│   ├── datasources/chat_datasource.dart        ChatDatasourceImpl (Firestore + RTDB + CFs)
│   ├── models/chat_message_model.dart          @freezed ChatMessageModel + toEntity()
│   └── repositories/chat_repository_impl.dart
└── presentation/
    ├── providers/chat_provider.dart            chatNotifierProvider, ChatNotifier, ChatState
    └── screens/chat_screen.dart               ChatScreen (dev path, ConsumerStatefulWidget)
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `chatNotifierProvider` | `NotifierProvider<ChatNotifier, ChatState>` | session lifecycle + messages |

## State

`SessionStatus` enum: `idle | searching | chatting | disconnected`

`ChatState` — `status` (SessionStatus), `messages` (List\<ChatMessage\>), `sessionId` (String?), `currentUserId` (String?), `currentUserDisplayName` (String?), `currentUserPhotoUrl` (String?), `typingUsers` (List\<TypingUser\>), `presenceMembers` (Set\<String\>? — UIDs currently live in RTDB `presence/{sessionId}`; null until first event delivered), `isSending` (bool), `activeShuffleEvent` (ShuffleEvent? — latest card broadcast from RTDB `card_shuffle/{sessionId}`; null until first event)

## Key Behavior

- `ChatNotifier.enterSession(sessionId)` is the entry point; call from screen with the room ID
- `ChatDatasourceImpl` routes on `sessionId.startsWith('proto-')`:
  - proto-session: SHA256-derived key + direct Firestore writes (dev/test only)
  - real session: calls `sendMessage` / `endSession` CFs
- RTDB paths used: `typing/{sessionId}/{uid}`, `presence/{sessionId}/{uid}`, `card_shuffle/{sessionId}`
- `onDisconnect().remove()` set on `presence` path in proto sessions only; for real sessions the `endSession` CF handles RTDB cleanup server-side
- `ChatNotifier.broadcastCardShuffle(question)` writes to `card_shuffle/{sessionId}` so all room participants receive the shuffle event; `activeShuffleEvent` in `ChatState` updates for every participant when any member shuffles
- `ChatNotifier` subscribes to `presence/{sessionId}` via `WatchPresence` use case; result stored in `ChatState.presenceMembers` as a `Set<String>` of live UIDs. `GroupChatScreen` uses this to filter Firestore `roomUsers` — only UIDs present in RTDB are rendered in the banner, suppressing phantom members whose `cleanupMember` CF hasn't yet run.
- `GroupChatScreen` maintains a `_memberAvatarCache` (`Map<String, AvatarState>`) that is populated whenever `avatarDecorationByUidProvider(uid)` resolves during `build()`. Message bubble rendering falls back to this cache when a sender is no longer in `roomUsers`, ensuring mood and hat overlays persist on past messages even after the user leaves.
- Message encryption: AES-256-GCM, 12-byte random IV per message (`crypto.randomBytes(12)` in CF)
- `_cancelSubscriptions()` does NOT cancel `onDisconnect` hooks — intentional

## Production Screens

- `screens/chat_screen.dart` — `ChatScreen` (ConsumerStatefulWidget, ⚠️ partial — uses `shared/` providers only, not wired to `chatNotifierProvider`). AppBar has Jukebox music button (`Icons.queue_music_rounded`) and `JukeboxChatPlayer` is mounted in the Column body for audio lifecycle management.
- `screens/group_chat_screen.dart` — `GroupChatScreen` (ConsumerStatefulWidget, integrated). Banner member list filtered by `chatState.presenceMembers` — only shows UIDs confirmed live in RTDB, falling back to the full Firestore `roomUsers` list while the subscription delivers its first event.

## Privacy

On `endSession`: `chat_rooms/{id}/messages` destroyed, RTDB presence/typing wiped, `rooms/{id}` tombstoned (`status: expired`). Only `reportSession` CF retains messages.
