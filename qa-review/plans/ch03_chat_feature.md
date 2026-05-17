# Chapter 3 Plan — Chat Feature

## Scope

```
apps/mobile/lib/features/chat/
├── data/
│   ├── datasources/chat_datasource.dart
│   ├── models/chat_message_model.dart (.freezed.dart, .g.dart)
│   └── repositories/chat_repository_impl.dart
├── domain/
│   ├── entities/ (chat_message.dart, session_status.dart, typing_user.dart)
│   ├── repositories/chat_repository.dart
│   └── usecases/ (watch_messages, send_message, set_typing, watch_partner_typing, end_session)
└── presentation/
    ├── providers/chat_provider.dart
    └── screens/chat_screen.dart

apps/mobile/test/features/chat/ (all test files)
```

---

## Checks to Perform

### 3.1 Domain Layer Purity
- [ ] `chat_message.dart`, `session_status.dart`, `typing_user.dart` — zero Flutter/Firebase imports.
- [ ] `chat_repository.dart` — abstract interface only.
- [ ] `SessionStatus` enum: `idle | searching | chatting | disconnected` — all four values present.
- [ ] `ChatMessage` entity: `id`, `senderId`, `displayName`, `text` (decrypted plaintext), `timestamp` — matches CLAUDE.md spec.
- [ ] `TypingUser` entity: `uid`, `displayName`, `photoUrl?` — matches spec.

### 3.2 Session Type Discrimination (Proto vs 1v1)
- [ ] `sessionId.startsWith('proto-')` is the only discriminator — consistent across datasource.
- [ ] Proto sessions: client-side AES-256-GCM, key derived from `SHA256('cozytalk-proto-v1:{sessionId}')`.
- [ ] 1v1 sessions: call `sendMessage` and `endSession` Cloud Functions.
- [ ] 1v1 sessions: encryption key fetched from `rooms/{sessionId}.encryptionKey`.
- [ ] No proto-session code path shares state with 1v1 path accidentally.

### 3.3 Encryption / Decryption Logic
- [ ] `ChatMessageModel` stores encrypted fields: `encryptedText`, `iv`, `authTag` (base64-encoded AES-256-GCM).
- [ ] `ChatRepositoryImpl.watchMessages()` fetches session key ONCE, then streams + decrypts all messages.
- [ ] Decryption is deterministic — same key + iv + ciphertext always produces same plaintext.
- [ ] Failed decryption is handled — doesn't crash the stream; either skips the message or surfaces error.
- [ ] IV is unique per message (not reused) — check proto-session write path.
- [ ] AES-GCM auth tag is verified during decryption (integrity check).
- [ ] Key derivation for proto sessions: SHA256 is applied correctly (not truncated, not hex-encoded vs raw).

### 3.4 RTDB Integration
- [ ] `typing/{sessionId}/{uid}` — read + write by client; correct path structure.
- [ ] `presence/{sessionId}/{uid}` — read + write with `onDisconnect().remove()`.
- [ ] `onDisconnect()` is registered BEFORE setting presence (race condition check).
- [ ] RTDB listeners are cancelled in `dispose` / `endSession` — no leaked subscriptions.
- [ ] RTDB write errors don't silently fail — at minimum logged.

### 3.5 ChatMessageModel (Freezed)
- [ ] `@freezed` annotation; `fromJson` delegates to generated code.
- [ ] `toEntity()` extension decrypts on-the-fly or receives pre-decrypted text?
  - Verify: decryption should happen in repository, not model.
- [ ] Encrypted fields are base64 strings — `fromJson` handles base64 correctly.
- [ ] No plaintext `text` field in the model (would be a security issue).

### 3.6 ChatRepositoryImpl
- [ ] `watchMessages` returns `Stream<List<ChatMessage>>` (decrypted).
- [ ] Session key fetch is cached for the lifetime of the subscription (not fetched per message).
- [ ] Firestore `chat_rooms/{sessionId}/messages` collection stream ordering — is it sorted by timestamp?
- [ ] `sendMessage` calls correct path based on session type (proto vs 1v1).
- [ ] `endSession` calls correct path (1v1 → CF; proto → direct RTDB delete).
- [ ] `watchTypingUsers` stream: filters out current user from typing list.

### 3.7 ChatState & ChatNotifier (`chat_provider.dart`)
- [ ] `ChatState` fields match CLAUDE.md: `status`, `sessionId?`, `currentUserId?`, `currentUserDisplayName?`, `currentUserPhotoUrl?`, `messages`, `typingUsers`, `isSending`, `error?`.
- [ ] All nullable fields use sentinel pattern in `copyWith`.
- [ ] `enterSession()` — called by `ChatScreen.initState()`; validates sessionId non-null before entering.
- [ ] State machine: transitions `idle → searching → chatting → disconnected` are explicit.
- [ ] `disconnected` state is set when partner leaves — not inferred from null fields.
- [ ] `isSending` guard prevents double-send.
- [ ] Subscriptions (messages, typing) are cancelled on `endSession` or dispose.
- [ ] DI chain is correct; no Firebase calls in provider class itself.

### 3.8 ChatScreen
- [ ] `initState` calls `enterSession()` with session ID and user info — not from `build`.
- [ ] Messages list uses `ListView.builder` — not `ListView(children: [...])`.
- [ ] Typing indicator displayed when `typingUsers` is non-empty (excluding self).
- [ ] Skip / Next Person button transitions to `searching` state (calls `endSession` then re-joins pool).
- [ ] Disconnected state shown when `status == disconnected` — not inferred from empty messages.
- [ ] Moods/Drinks SVG icebreakers use `flutter_svg` with asset precaching.
- [ ] No `print()` calls.
- [ ] No Firebase SDK imports.

### 3.9 Test Coverage
- [ ] All three entity tests: construction, optional fields null, enum all-values test.
- [ ] `chat_message_model_test.dart` — fromJson all fields / with nulls / extra keys; toEntity() maps correctly.
- [ ] `chat_repository_impl_test.dart` — session type discrimination tested; stream decryption mocked; subscription cleanup.
- [ ] All use case tests — args, result, exception propagation.
- [ ] `chat_state_test.dart` — sentinel pattern tests for ALL nullable fields.
- [ ] `chat_screen_test.dart` — renders, loading, error, send action, disconnected state.
- [ ] `shared_fakes.dart` (`FakeChatRepository`) — implements all interface methods.
- [ ] No Firebase SDK in tests.
- [ ] Crypto is NOT mocked in tests (test with real keys to avoid mock/prod divergence).

### 3.10 `_anonymousName` Duplication Check
- [ ] Confirm `chat_datasource.dart` contains a copy of `_anonymousName`.
- [ ] Confirm it is identical to the one in `auth_datasource.dart`.
- [ ] Flag as tech debt: extract to `lib/shared/anonymous_name.dart` if 3rd caller appears.

---

## Files to Read in Full

1. `apps/mobile/lib/features/chat/domain/entities/chat_message.dart`
2. `apps/mobile/lib/features/chat/domain/entities/session_status.dart`
3. `apps/mobile/lib/features/chat/domain/repositories/chat_repository.dart`
4. `apps/mobile/lib/features/chat/data/datasources/chat_datasource.dart`
5. `apps/mobile/lib/features/chat/data/models/chat_message_model.dart`
6. `apps/mobile/lib/features/chat/data/repositories/chat_repository_impl.dart`
7. `apps/mobile/lib/features/chat/presentation/providers/chat_provider.dart`
8. `apps/mobile/lib/features/chat/presentation/screens/chat_screen.dart`
9. All test files in `apps/mobile/test/features/chat/`

---

## Expected Findings Categories

- IV reuse in proto-session encryption (CRITICAL if found)
- RTDB listener leak on session end (HIGH)
- Missing decryption failure handling (HIGH)
- Sentinel pattern missing for one or more nullable fields in ChatState (HIGH)
- Decryption in model instead of repository (MEDIUM — CA violation)
- `_anonymousName` duplication (MEDIUM — tech debt)
- `ListView(children: [...])` for messages (HIGH — performance violation)
- Missing `chatting → disconnected` state test (MEDIUM)

---

## Output

Write findings to `reviews/ch03_chat_feature.md`.
