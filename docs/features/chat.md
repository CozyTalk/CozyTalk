# Feature: chat

AES-256-GCM encrypted messaging over Firestore, with RTDB presence and typing indicators.

## File Map

```
features/chat/
├── domain/
│   ├── entities/
│   │   ├── chat_message.dart          ChatMessage (id, senderId, text, timestamp)
│   │   ├── session_status.dart        SessionStatus enum
│   │   └── typing_user.dart           TypingUser (uid, isTyping)
│   ├── repositories/chat_repository.dart  abstract ChatRepository
│   └── usecases/
│       ├── end_session.dart           EndSession
│       ├── send_message.dart          SendMessage
│       ├── set_typing.dart            SetTyping
│       ├── watch_messages.dart        WatchMessages
│       └── watch_partner_typing.dart  WatchPartnerTyping
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

`ChatState` — `status` (SessionStatus), `messages` (List\<ChatMessage\>), `sessionId` (String?), `partnerName` (String?)

## Key Behavior

- `ChatNotifier.enterSession(sessionId)` is the entry point; call from screen with the room ID
- `ChatDatasourceImpl` routes on `sessionId.startsWith('proto-')`:
  - proto-session: SHA256-derived key + direct Firestore writes (dev/test only)
  - real session: calls `sendMessage` / `endSession` CFs
- RTDB paths used: `typing/{sessionId}/{uid}`, `presence/{sessionId}/{uid}`
- `onDisconnect().remove()` set on `presence` path in proto sessions only; for real sessions the `endSession` CF handles RTDB cleanup server-side
- Message encryption: AES-256-GCM, 12-byte random IV per message (`crypto.randomBytes(12)` in CF)
- `_cancelSubscriptions()` does NOT cancel `onDisconnect` hooks — intentional

## Production Screens

- `screens/chat_screen.dart` — `ChatScreen` (ConsumerStatefulWidget, ⚠️ partial — uses `shared/` providers only, not wired to `chatNotifierProvider`)
- `screens/group_chat_screen.dart` — `GroupChatScreen` (not yet integrated)

## Privacy

On `endSession`: `chat_rooms/{id}/messages` destroyed, RTDB presence/typing wiped, `rooms/{id}` tombstoned (`status: expired`). Only `reportSession` CF retains messages.
