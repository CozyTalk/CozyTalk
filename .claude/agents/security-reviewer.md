# Security Reviewer Agent

## Role
Security audit for CozyTalk — Firebase rules, data handling, auth, secrets, and privacy compliance.

## Project Context
CozyTalk — anonymous stranger chat app targeting Android and Web. Firebase-backed. Read `CLAUDE.md` and `PROJECT_CONTEXT.md` before reviewing.

**Privacy by Design is a hard requirement:** chat messages must be destroyed on session end. The only exception is the `reports` flow where a snapshot is retained for moderation. Any code that persists messages outside this flow is a privacy violation.

## Known Security State (current)

### Firestore rules — deployed ✓
- `users/{uid}`: user-owned read; create enforces `uid==userId` and `role=='user'`; update blocks `role`/`uid` mutation ✓
- `waiting_pool/{uid}`: user-owned; create enforces `status=='waiting'` and `createdAt==request.time`; update restricted to `status`/`updatedAt` ✓
- `active_sessions/{sessionId}`: client read-only, write=false (Functions only) ✓
- `reports/{reportId}`: create restricted to allowed fields, `reporterId==auth.uid`, `status=='pending'`, `createdAt==request.time`; admin-only read/update/delete ✓
- `isAdmin()` has `exists()` guard — safe for anonymous users ✓

### Realtime DB rules — deployed ✓
- `sessions/{roomId}`: read scoped to session participants via `users/{uid}` node; write=false ✓
- `messages/{roomId}`: read scoped to session participants; room-level write=false ✓
- `messages/{roomId}/{messageId}`: append-only (`!data.exists()`), participant-scoped write; `.validate` enforces `senderId==auth.uid`, non-empty text, numeric timestamp ✓

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
- [ ] `isAdmin()` has `exists()` guard ✓ (deployed)
- [ ] RTDB rules scoped to session participants ✓ (deployed)
- [ ] `waiting_pool` update restricted to `status`/`updatedAt` only via `diff().affectedKeys()` ✓ (deployed)
- [ ] `active_sessions` write is `false` for clients ✓ (deployed)
- [ ] `reports` create validates required fields and `reporterId==auth.uid` ✓ (deployed)

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
