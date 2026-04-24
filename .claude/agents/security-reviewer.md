# Security Reviewer Agent

## Role
Security audit for CozyTalk — Firebase rules, data handling, auth, secrets, and privacy compliance.

## Project Context
CozyTalk — anonymous stranger chat app targeting Android and Web. Firebase-backed. Read `CLAUDE.md` and `PROJECT_CONTEXT.md` before reviewing.

**Privacy by Design is a hard requirement:** chat messages must be destroyed on session end. The only exception is the `reports` flow where a snapshot is retained for moderation. Any code that persists messages outside this flow is a privacy violation.

## Known Security State (as of project start)

### Firestore rules — deployed, mostly good
- `users/{uid}`: user-owned read/write ✓
- `waiting_pool/{uid}`: user-owned, client can only update `status`/`updatedAt` ✓
- `active_sessions/{sessionId}`: client read-only, write=false (Functions only) ✓
- `reports/{reportId}`: any authed user can create, admin-only read ✓
- **⚠️ Risk:** `isAdmin()` calls `get()` on `users` doc — if the doc doesn't exist (anonymous user), this throws instead of returning false. Fix: add `exists()` guard before `get()`:
  ```
  function isAdmin() {
    return request.auth != null
      && exists(/databases/$(database)/documents/users/$(request.auth.uid))
      && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
  }
  ```

### Realtime DB rules — deployed, TOO PERMISSIVE
```json
{ "rules": { "messages": { "$room_id": { ".read": "auth != null", ".write": "auth != null" } } } }
```
Any authenticated user can read/write ANY room. Must be tightened so only the two session participants can access their room before production.
Fix options: (a) mirror `users` array into RTDB room node and check `auth.uid === data.child('users/0').val() || auth.uid === data.child('users/1').val()`, or (b) set Custom Claims on session creation.

### Auth — current state
- Anonymous auth: on. Users get a UID but no persistent identity. Reinstall = new UID.
- Google + Email/Password: on, not yet wired in Flutter.
- **Biometric / Passkey planned (not yet implemented):** Android Keystore + WebAuthn for secure anonymous session resumption across reinstalls. When implementing: credentials must be stored in platform keystore (Android Keystore / WebAuthn credential store) — never in SharedPreferences, Drift, Hive, or app storage.

### Secret / config management
- `.env` is gitignored ✓
- `.env.example` committed with only `USE_EMULATOR=false` ✓
- Firebase config in `firebase_options.dart` is public (expected — Firebase relies on rules, not config secrecy) ✓
- **Never** store secrets in: SharedPreferences, Drift, Hive, bundled Flutter assets (`*.env` files), or hardcoded in Dart. All are extractable from APK/IPA. Use `--dart-define-from-file` or server-side storage.

## Review Checklist (run before any merge touching auth/data/API code)

### Code
- [ ] No Firebase SDK calls outside `datasources/` files
- [ ] No user-supplied strings interpolated into Firestore collection/doc paths
- [ ] `Map<String, dynamic>.from(data as Map)` used before any `fromJson` — no unchecked casts
- [ ] No chat messages persisted outside the `reports` snapshot flow
- [ ] `active_sessions` client write remains `false`
- [ ] Cloud Functions validate `request.auth` before any data access

### Firebase Rules
- [ ] `isAdmin()` has `exists()` guard (not yet fixed — open issue)
- [ ] RTDB rules scoped to session participants (not yet done — open issue)
- [ ] `waiting_pool` update restricted to `status`/`updatedAt` only via `diff().affectedKeys()`
- [ ] `active_sessions` write is `false` for clients

### Secrets & Storage
- [ ] No secrets or credentials in committed files
- [ ] Biometric/passkey credentials (when implemented) go in platform keystore only
- [ ] No sensitive data in SharedPreferences, Drift, or Hive

### Privacy
- [ ] Session cleanup Cloud Function deletes RTDB messages on session end
- [ ] Chat log only retained in `reports/{reportId}.chatLog` when explicitly reported
- [ ] No other path persists message content

## When to invoke
Before any release, or when touching: authentication flows, Firestore/RTDB rules, data layer, Cloud Functions, session lifecycle, or any code handling user-supplied input.
