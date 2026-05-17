# Chapter 9 Plan — Firebase Config & Security Rules

## Scope

```
firestore.rules
firestore.indexes.json
database.rules.json
firebase.json
.firebaserc
apps/mobile/firebase_options.dart
```

---

## Checks to Perform

### 9.1 Firestore Security Rules (`firestore.rules`)

#### Helper Functions
- [ ] `isSignedIn()` — returns `request.auth != null`.
- [ ] `isOwner(uid)` — returns `request.auth.uid == uid`.
- [ ] `isAdmin()` — reads `request.auth.token.role == 'admin'` OR reads from Firestore `users/{uid}.role`. If it reads from Firestore, confirm it uses `get()` not `exists()` and handles missing doc.
- [ ] `_isRoomsParticipant(sessionId)` — checks `rooms/{sessionId}.users` contains caller UID. Uses `get()` call — confirm path is correct.
- [ ] `_isActiveSessionParticipant(sessionId)` — same for legacy `active_sessions`.
- [ ] `isChatRoomParticipant(sessionId)` — combines both checks.

#### Collection: `users/{userId}`
- [ ] Read: only owner can read own profile. Admins can read any profile.
- [ ] Create: only owner can create own doc (UID in path matches auth UID).
- [ ] Update: owner can update mutable fields only. Immutable fields: `uid`, `role`, `createdAt`.
- [ ] Update rule prevents `role` escalation (user cannot set own role to `admin`).
- [ ] Delete: nobody can delete (or only admin).
- [ ] Rule does NOT allow reading `encryptionKey` (not a field here, but double-check).
- [ ] Anonymous users: can they create/update their own doc? (Required for anonymous auth flow.)

#### Collection: `waiting_pool/{userId}`
- [ ] Create: only owner. Fields required: status `waiting|matched|canceled`, mode `1v1|group`.
- [ ] Update: owner can update `updatedAt` only (per CLAUDE.md spec).
- [ ] Delete: owner can delete (cancel).
- [ ] Read: only owner.
- [ ] `interestText` and `interestVector` are writable on create but not update (or are they writable on both)?
- [ ] Cloud Functions bypass rules via admin SDK — confirm this is the intended path for match writes.

#### Collection: `rooms/{roomId}`
- [ ] Read: participants can read their own room. Expired rooms readable by any signed-in user.
- [ ] `isLocked` — only members can toggle for custom rooms. Not writable for 1v1 rooms.
- [ ] **CRITICAL:** Does the read rule expose `encryptionKey`? If clients can read `rooms/{roomId}` and the doc contains `encryptionKey`, the encryption is worthless.
  - Options: field-level security (Firestore doesn't support field-level — must use a separate collection), or CF-only write and no-client-read for that field.
  - The correct approach: move `encryptionKey` to `session_keys/{sessionId}` which is CF-only.
  - Check if `rooms/{roomId}` currently stores the key and if rules block it.
- [ ] Write: Cloud Functions only (via admin SDK — rules can deny all writes to lock it down).
- [ ] Expired rooms: readable by any signed-in user — why? This seems broad. Is it needed for UI to show "session ended"?

#### Collection: `active_sessions/{sessionId}`
- [ ] Read-only for participants.
- [ ] Cloud Functions manage writes.
- [ ] Is this collection still used in production? Or fully replaced by `rooms/{roomId}`?

#### Collection: `reports/{reportId}`
- [ ] Create: only reporter (authenticated), with required fields: `reason`, `description`, `chatLog`, `status: 'pending'`.
- [ ] Read: only admin.
- [ ] Update: only admin.
- [ ] Delete: only admin.
- [ ] Reporter cannot read own report after filing.
- [ ] `reporterId` must equal auth UID (not writable as arbitrary value).

#### Collection: `session_keys/{sessionId}`
- [ ] Deny ALL client access (read and write).
- [ ] Cloud Functions admin SDK bypasses rules.
- [ ] Confirm: `deny all;` or equivalent.

#### Collection: `chat_rooms/{sessionId}/messages/{messageId}`
- [ ] Read: only session participants.
- [ ] Create: only sender (auth UID must match `senderId` in doc).
  - **CRITICAL CHECK:** Does the rule validate `senderId == request.auth.uid`? If not, users can spoof sender.
  - Does the rule validate `displayName` length ≤ 200?
  - Does the rule validate `encryptedText` length ≤ 12KB (12288 bytes)?
- [ ] Update/Delete: nobody (immutable after creation).
- [ ] TTL: `expiresAt` field required, must be a timestamp within 3 days.

### 9.2 Firestore Indexes (`firestore.indexes.json`)
- [ ] Index for `waiting_pool` queries: filter by `status`, order by `createdAt` (FIFO matching).
- [ ] Index for `rooms` queries: filter by `roomType`, `status`, order by something (for group room join).
- [ ] Index for `rooms` with `expiresAt < now` (for `expireRooms` scheduled function).
- [ ] No missing indexes that would cause Cloud Function queries to fail in production.
- [ ] No redundant indexes.

### 9.3 Realtime Database Rules (`database.rules.json`)
- [ ] `typing/{roomId}/{uid}`: writable by authenticated uid only; readable by room participants.
- [ ] `presence/{roomId}/{uid}`: writable by authenticated uid; readable by room participants; `onDisconnect().remove()` works correctly with these rules.
- [ ] `rooms/{roomId}/members/{uid}`: Cloud Function write only? Or client-writable?
- [ ] `pool_presence/{uid}`: writable by owner only; readable by Cloud Functions.
- [ ] `nameQueue/{roomId}`: what is this? Check usage and rules.
- [ ] General: does the RTDB root have a `false` deny-all fallback rule? (Important — without it, all paths not explicitly listed are readable.)
- [ ] Anonymous users: can they write to presence/typing? (They must be able to for the app to work.)

### 9.4 `firebase.json`
- [ ] Firestore rules file path points to `firestore.rules`.
- [ ] Firestore indexes file path points to `firestore.indexes.json`.
- [ ] RTDB rules file path points to `database.rules.json`.
- [ ] Functions source directory is `functions`.
- [ ] Functions runtime matches `package.json` Node version.
- [ ] Hosting configuration (if present): public directory is `apps/mobile/build/web`.
- [ ] Emulator configuration: correct ports (Auth 9099, Functions 5001, Firestore 8080, RTDB 9000).
- [ ] No sensitive values in `firebase.json`.

### 9.5 `.firebaserc`
- [ ] Project ID matches `cozytalk-5d984`.
- [ ] No unexpected aliases.

### 9.6 `firebase_options.dart` (Flutter)
- [ ] File is generated by `flutterfire configure` — do not edit manually.
- [ ] Contains correct project ID, API keys (web API keys are public by design — OK).
- [ ] Android `googleServicesFile` is present (not committed if it contains secrets — check `.gitignore`).
- [ ] iOS config (if present — project targets Android + Web only, so iOS may be absent).

### 9.7 `google-services.json` / `GoogleService-Info.plist`
- [ ] These files should NOT be committed to the repo (they contain service account credentials).
- [ ] Check `.gitignore` — confirm they are excluded.
- [ ] Check if they exist in `apps/mobile/android/app/` — if they do and are committed, that's a CRITICAL security issue.

---

## Security Rules Audit: Key Questions

Answer each explicitly in the review:

1. Can an unauthenticated user read any Firestore collection?
2. Can a user read another user's profile?
3. Can a user read another user's chat messages?
4. Can a user read the encryption key for a session they're in? (The dangerous one.)
5. Can a user create a report with a forged `reporterId`?
6. Can a user escalate their own `role` to `admin`?
7. Can a user write to `session_keys`?
8. Are RTDB rules locked down — no accidental public read due to missing deny-all default?

---

## Files to Read in Full

1. `firestore.rules`
2. `firestore.indexes.json`
3. `database.rules.json`
4. `firebase.json`
5. `.firebaserc`

---

## Expected Findings Categories

- `rooms/{roomId}` exposes `encryptionKey` to clients (CRITICAL)
- `chat_rooms` create rule doesn't validate `senderId == request.auth.uid` (CRITICAL)
- RTDB missing deny-all root rule (CRITICAL)
- `role` field writable by user in `users` rules (CRITICAL)
- Missing index for `expireRooms` query (HIGH)
- `google-services.json` committed to repo (CRITICAL if found)
- `waiting_pool` update allows more than just `updatedAt` (MEDIUM)
- Expired rooms readable by any authenticated user — overly broad (LOW-MEDIUM)

---

## Output

Write findings to `reviews/ch09_firebase_config.md`.
