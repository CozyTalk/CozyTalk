# Security Audit — Save Report + Fix All Findings

## Context

A full security audit was run against the `feat/friends` branch. This plan (1) persists the audit report as a markdown file, (2) fixes every finding in severity order, (3) updates all docs that describe the changed behaviour, and (4) re-runs the security-reviewer checklist to confirm clean.

---

## Step 0 — Save the audit report

**Create** `docs/security/audit-2025-05-18.md`

Paste the full findings report produced in this session (all severity tiers, checklist pass/fail table, and privacy note). This is a new file in a new `docs/security/` directory.

---

## Step 1 — HIGH: H-1 — Remove `email` from Firestore (nothing reads it from there)

**Root cause:** `allow read: if isSignedIn()` on `users/{uid}` exposes `email` to all authenticated users. Email is stored in Firebase Auth and is never read from Firestore by any datasource, model, or screen.

**Fix 1a — `apps/mobile/lib/features/auth/data/datasources/auth_datasource.dart`**
Remove the `'email': email` / `'email': user.email` key from the `set()` call in **all three** sign-up paths:
- `signInAnonymously()` — already omits email ✓  
- `signUp()` — remove `'email': email` (line ~121)  
- `signInWithGoogle()` — remove `'email': user.email` (line ~87)

**Fix 1b — `firestore.rules`**
- In `allow create` for `users/{userId}`: remove `'email'` from the `hasOnly([...])` allowlist (line 49)
- In `allow update` for `users/{userId}`: remove `'email'` from the `affectedKeys().hasOnly([...])` list (line 56)

**After fix:** `users` docs contain only: `uid`, `role`, `createdAt`, `lastSeen`, `displayName`, `photoUrl`, `hatKey`, `moodKey`, `interest`, `thoughts` — all benign for a social app. The `allow read: if isSignedIn()` rule is then acceptable.

---

## Step 2 — HIGH: H-2 — Gate `friendships` create on an accepted friend request

**Root cause:** Any user can `set()` a `friendships` doc with `users: [self, victim]`, bypassing the request/accept flow.

**Fix 2a — `apps/mobile/lib/features/friends/data/datasources/friends_datasource.dart`**

Split the batch write in `acceptFriendRequest()` into two sequential writes so the friend-request status is committed before the friendship is created:

```dart
// 1. Mark request accepted first (commits to Firestore)
await _firestore.collection('friend_requests').doc(requestId).update({
  'status': 'accepted',
});

// 2. Create friendship — rule will see the accepted request
await _firestore.collection('friendships').doc(friendshipId).set({
  'users': [fromUid, currentUid],
  'displayNames': {fromUid: fromDisplayName, currentUid: myDisplayName},
  'chatRoomId': friendshipId,
  'createdAt': FieldValue.serverTimestamp(),
});
```

**Fix 2b — `firestore.rules`**

Replace the `friendships` `allow create` rule with one that cross-references `friend_requests`:

```
allow create: if isSignedIn()
  && request.auth.uid in request.resource.data.users
  && request.resource.data.keys().hasAll(['users', 'displayNames', 'chatRoomId', 'createdAt'])
  && (
    (
      exists(/databases/$(database)/documents/friend_requests/$(request.resource.data.users[0] + '_' + request.resource.data.users[1]))
      && get(/databases/$(database)/documents/friend_requests/$(request.resource.data.users[0] + '_' + request.resource.data.users[1])).data.status == 'accepted'
    ) || (
      exists(/databases/$(database)/documents/friend_requests/$(request.resource.data.users[1] + '_' + request.resource.data.users[0]))
      && get(/databases/$(database)/documents/friend_requests/$(request.resource.data.users[1] + '_' + request.resource.data.users[0])).data.status == 'accepted'
    )
  );
```

**Why this works:** The `users` array in the new friendship is `[fromUid, currentUid]` matching the request doc ID `{fromUid}_{currentUid}`. Since the status update is committed in step 1 before the friendship create in step 2, the rule sees `status == 'accepted'` correctly.

---

## Step 3 — HIGH: H-3 — Align proto-session key derivation

**Root cause:** Client hashes `'cozytalk-proto-v1:' + sessionId`; server hashes just `sessionId`. Keys never match → all proto-session report chat logs have `text: null`.

**Fix — `functions/src/chat/reportSession.ts` line 56-58**

```typescript
function _deriveProtoKey(sessionId: string): string {
  return createHash("sha256")
    .update(`cozytalk-proto-v1:${sessionId}`, "utf8")
    .digest("hex");
}
```

---

## Step 4 — MEDIUM: M-1 — Restrict `typing` and `presence` RTDB reads to room members

**Fix — `database.rules.json`**

Change `.read` on both `typing/$room_id` and `presence/$room_id` from `"auth != null"` to:
```json
"auth != null && root.child('rooms').child($room_id).child('members').child(auth.uid).exists()"
```

---

## Step 5 — MEDIUM: M-2 — Restrict `user_status` RTDB reads to owner

**Fix — `database.rules.json`**

Change `.read` on `user_status/$uid` from `"auth != null"` to `"auth != null && auth.uid == $uid"`.

---

## Step 6 — MEDIUM: M-3 — Validate `contextImageUrls` as Firebase Storage URLs

**Fix — `functions/src/chat/reportSession.ts`** (in the `contextImageUrls` validation block, after the array check)

```typescript
const STORAGE_BASE = "https://firebasestorage.googleapis.com/";
for (const url of contextImageUrls) {
  if (typeof url !== "string" || !url.startsWith(STORAGE_BASE)) {
    throw new HttpsError(
      "invalid-argument",
      "Each image URL must be a Firebase Storage URL.",
    );
  }
}
```

---

## Step 7 — LOW: L-1 — Env-var escape hatch for API key in test file

**Fix — `functions/src/matchmaking/__tests__/testProdVertexAI.ts` line 17**

```typescript
// Public web API key (same as firebase_options.dart — safe to commit).
// Override via FIREBASE_WEB_API_KEY for CI environments.
const API_KEY =
  process.env.FIREBASE_WEB_API_KEY ??
  "AIzaSyAhEm1tJRomLx7ErcaHDYSlnyrpchgmro8";
```

---

## Step 8 — LOW: L-2 — Fix proto-session `expiresAt` (immediate → 3-day TTL)

**Fix — `apps/mobile/lib/features/chat/data/datasources/chat_datasource.dart` line ~149**

Replace:
```dart
'expiresAt': FieldValue.serverTimestamp(),
```
With:
```dart
'expiresAt': Timestamp.fromMillisecondsSinceEpoch(
  DateTime.now().millisecondsSinceEpoch +
      const Duration(days: 3).inMilliseconds,
),
```
`Timestamp` is already available from the `cloud_firestore` import.

---

## Step 9 — LOW: L-3 — Mark admin console as non-functional prototype

**Fix — `apps/mobile/lib/screens/admin_console_screen.dart`** top of `build()`:
```dart
assert(false, 'AdminConsoleScreen is a design-preview prototype using mock data. '
    'No Firebase operations are wired. Do not use in production.');
```

---

## Step 10 — LOW: L-4 — Server-side cleanup of `friend_messages` on friendship delete

**New file — `functions/src/friends/removeFriendship.ts`**

Firestore `onDocumentDeleted` trigger on `friendships/{friendshipId}`:
```typescript
import {onDocumentDeleted} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {deleteSubcollection} from "../matchmaking/_utils";

export const onFriendshipDeleted = onDocumentDeleted(
  {document: "friendships/{friendshipId}", region: "us-central1"},
  async (event) => {
    const {friendshipId} = event.params;
    const db = admin.firestore();
    await deleteSubcollection(
      db,
      db.collection("friend_messages").doc(friendshipId).collection("messages"),
    );
    logger.info("Cleaned up friend messages on friendship delete", {friendshipId});
  },
);
```

Reuses `deleteSubcollection` from `functions/src/matchmaking/_utils.ts`.

**Export — `functions/src/index.ts`**
Add:
```typescript
export {onFriendshipDeleted} from "./friends/removeFriendship";
```

This becomes CF #16 (internal trigger, not exported as a public callable). Total exported count: 16.

---

## Step 11 — LOW: L-6 — Add explicit field validation + `$other: false` to RTDB typing node

**Fix — `database.rules.json`** — expand the `typing.$room_id.$uid` node to add per-field rules and reject unknown fields:

```json
"$uid": {
  ".write": "auth != null && auth.uid == $uid",
  ".validate": "newData.hasChildren(['isTyping', 'displayName'])",
  "isTyping": { ".validate": "newData.isBoolean()" },
  "displayName": { ".validate": "newData.isString() && newData.val().length <= 100" },
  "photoUrl":    { ".validate": "!newData.exists() || (newData.isString() && newData.val().length <= 500)" },
  "$other":      { ".validate": false }
}
```

`photoUrl` is retained as an allowed optional field (used by `chat_datasource.dart:setTyping`).

---

## Step 12 — Doc updates (non-negotiable per CLAUDE.md §16)

| Doc | What to update |
|---|---|
| `docs/security/audit-2025-05-18.md` | NEW — full audit report (Step 0) |
| `PROJECT_CONTEXT.md` schema table | Remove `email` from `users/{uid}` field table; update `users` create/update rule summary; update RTDB `typing`/`presence` access to "room member"; add `user_status` RTDB row; update CF count to 16 |
| `CLAUDE.md §7` | Update RTDB typing/presence/user_status access notes; remove email from users field list |
| `.claude/agents/security-reviewer.md` | Update Known Security State: mark all fixed items ✓ with new rule description; remove stale `sessions/{roomId}` RTDB entry; add `user_status`, `friend_messages`, `friendships` rows; add Storage rules section |
| `docs/backend/cloud-functions.md` (if exists) | Add `onFriendshipDeleted` row (Firestore trigger, us-central1, friends) |

---

## Critical files

| File | Why touched |
|---|---|
| `firestore.rules` | H-1, H-2 |
| `database.rules.json` | M-1, M-2, L-6 |
| `functions/src/chat/reportSession.ts` | H-3, M-3 |
| `apps/mobile/lib/features/auth/data/datasources/auth_datasource.dart` | H-1 |
| `apps/mobile/lib/features/friends/data/datasources/friends_datasource.dart` | H-2 |
| `apps/mobile/lib/features/chat/data/datasources/chat_datasource.dart` | L-2 |
| `functions/src/matchmaking/__tests__/testProdVertexAI.ts` | L-1 |
| `apps/mobile/lib/screens/admin_console_screen.dart` | L-3 |
| `functions/src/friends/removeFriendship.ts` | L-4 (new file) |
| `functions/src/index.ts` | L-4 |
| `.claude/agents/security-reviewer.md` | Step 12 |
| `PROJECT_CONTEXT.md` | Step 12 |
| `CLAUDE.md` | Step 12 |

---

## Verification

1. **Firestore rules:** `firebase emulators:start` + manual test that:
   - Anonymous user cannot create friendship without accepted request
   - Friend messages blocked after friendship deletion
   - Email field rejected on `users` create/update

2. **RTDB rules:** Emulator + verify that unauthenticated / non-member reads on `typing` and `presence` are rejected

3. **Proto-session key:** Manually verify `createHash("sha256").update("cozytalk-proto-v1:test", "utf8").digest("hex")` matches Dart's `Sha256().hash(utf8.encode("cozytalk-proto-v1:test"))` converted to hex

4. **Flutter tests:** `cd apps/mobile && flutter test` — all 530 tests must pass (removing email write should not affect any test since no test validates email in Firestore)

5. **CF Jest:** `cd functions && npm run build && npm test` — all 93 unit tests must pass

6. **Security re-review:** Walk through `.claude/agents/security-reviewer.md` checklist line-by-line after all fixes are in place
