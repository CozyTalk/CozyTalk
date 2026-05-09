# PR #9 Review — Feature/chatroom

**Scope:** Flutter chat feature (domain + data + presentation), Cloud Functions (sendMessage, endSession, reportSession, setTyping), Firebase security rules.

---

## Overview

This PR implements the full chat feature end-to-end: AES-256-GCM encrypted messages stored in Firestore (`chat_rooms/{id}/messages` — intentional deviation from RTDB for encryption + TTL support), a proto-session path (`proto-*` prefix) for local testing without matchmaking, typing indicators via RTDB, and Cloud Functions for send/end/report. Architecture broadly follows Clean Architecture conventions.

---

## Critical Bugs

**1. `setTyping` Cloud Function is not exported but is still called by the client**

`functions/src/chat/setTyping.ts` exists but is not exported from `index.ts`. The comment says `// clients write directly to RTDB`, but `chat_datasource.dart:819` calls the Cloud Function for every non-proto session:

```dart
await _functions.httpsCallable('setTyping').call({...});
```

This will throw `NOT_FOUND` at runtime for every real session. Either export the function or rewrite the datasource to write RTDB directly for all sessions.

**2. `setTyping.ts` writes incomplete data that fails RTDB validation**

Even if exported, `setTyping.ts:463` writes only `{isTyping}` to RTDB, but `database.rules.json:9946` now requires `{isTyping, displayName}`. Every write from the Cloud Function would be rejected. The `displayName` would need to be resolved server-side (e.g. from the `users` collection).

**3. Stream subscriptions leak on back-navigation**

`_ChatScreenState.dispose()` cancels the timer and controllers but never cancels `_messagesSub` or `_typingSub` in `ChatNotifier`. Pressing the OS back button leaves both subscriptions alive, delivering state updates to a disposed widget.

```dart
// chat_screen.dart — dispose() needs to call:
ref.read(chatNotifierProvider.notifier)._cancelSubscriptions();
// or expose a dedicated cleanup method
```

**4. Proto-session messages have zero TTL**

```dart
// chat_datasource.dart:789-790
'timestamp': FieldValue.serverTimestamp(),
'expiresAt': FieldValue.serverTimestamp(),
```

Both resolve to the same server timestamp. Any Firestore TTL policy on `expiresAt` will delete proto messages immediately. The intent is presumably a retention window (e.g. 3 days, matching the non-proto path in `sendMessage.ts:60`).

---

## High Severity

**5. `joinProtoSession` bypasses the repository layer**

`ChatNotifier._joinProtoThenSubscribe` reads the datasource directly:

```dart
// chat_provider.dart:322
ref.read(_chatDatasourceProvider).joinProtoSession(...)
```

Notifiers must only call use cases. `joinProtoSession` also has no entry point on `ChatRepository`, which means it can't be tested or swapped.

**6. RTDB security rules weakened globally**

`typing` and `presence` nodes dropped session-membership checks. Any authenticated user can now read typing/presence for every room:

```json
// Before: read gated on session membership
// After:
".read": "auth != null"  // any auth user reads ALL rooms
```

The write rule similarly removes session verification. This exposes who is online and typing in every active session to any signed-in user.

**7. `nameQueue` RTDB node is fully open and completely unused**

```json
"nameQueue": { "$room_id": { ".read": "auth != null", ".write": "auth != null" } }
```

Any authenticated user can read and write here with no per-user constraints. Nothing in the codebase references `nameQueue`. Remove it from the rules entirely.

**8. `seedTtlCollections` is deployed to production as an unauthenticated HTTP endpoint**

The function is exported in `index.ts` with a "remove after running once" comment but nothing enforces removal. A publicly callable HTTP endpoint writing to Firestore is a risk surface — remove it in this PR or a fast-follow, don't leave it to documentation.

**9. No tests**

Zero test files were added. The QA gate requires >80% domain-layer unit test coverage and widget tests for all screens. At minimum, `ChatState.copyWith`, the sentinel pattern, and `_anonymousName` collision handling should be unit-tested before merge.

---

## Medium Severity

**10. `_DisconnectedScreen` is a dead end**

No button to go back to the hello screen or find a new match. Users are trapped until they kill the app.

**11. Proto encryption key is deterministic from source**

```dart
// chat_datasource.dart:880
final hash = await Sha256().hash(utf8.encode('cozytalk-proto-v1:$sessionId'));
```

With `sessionId = 'proto-session-001'` hardcoded in `hello_screen.dart`, anyone with the source can derive the key and decrypt all proto messages. This is probably acceptable for a dev harness, but add a comment and ensure the matchmaking path never generates `proto-*` session IDs.

**12. `expiresAt` normalization in `watchRawMessages` is dead code**

`watchRawMessages` normalizes `expiresAt` from Timestamp → int, but `ChatMessageModel` has no `expiresAt` field — the value is silently dropped. Remove the normalization or add the field to the model.

**13. `session_keys` collection has no explicit Firestore rule**

`endSession.ts` and `reportSession.ts` write encryption keys to `session_keys`. Firestore's default-deny applies, but there is no explicit `allow read, write: if false` rule. An explicit rule documents the intent and prevents accidental access if rules are ever reorganized.

**14. `reportSession` unbounded message batch update**

```typescript
// reportSession.ts:254-261
const msgsSnap = await db.collection('chat_rooms').doc(sessionId)
    .collection('messages').get();  // ← no limit
```

A session with many messages could hit Firestore batch limits (500 docs/batch). `endSession.ts` correctly uses paginated deletes; `reportSession.ts` should do the same for the flag update.

---

## Low / Style

**15. JSDoc comments in Cloud Functions violate project conventions**

`sendMessage.ts` has multi-line JSDoc blocks on `generateKey` and `encryptText`. Project convention: no comments explaining what code does — one short line max for non-obvious WHY.

**16. `_deduplicateName` silently returns a colliding name**

After suffix 10, it returns `baseName` unchanged. Given the 5-user room cap this won't happen today, but the silent collision is surprising. Return something like `'$baseName #${uid.substring(0,4)}'` as a last resort.

**17. `sendMessage.ts` `RETENTION_MS` duplicated**

`RETENTION_MS = 3 * 24 * 60 * 60 * 1000` is defined in both `sendMessage.ts` and `endSession.ts`. Extract to a shared constants file to avoid drift.

---

## Summary

| Severity | Count |
|---|---|
| Critical (runtime failure) | 4 |
| High | 6 |
| Medium | 5 |
| Low / style | 3 |

The critical bugs (missing `setTyping` export, RTDB validation mismatch, subscription leak, zero TTL on proto messages) should be fixed before merge. The weakened RTDB rules and missing tests are the next priority.
