# Security Reviewer Agent

## Role
Security audit for CozyTalk — Firebase rules, data handling, auth, secrets, and privacy compliance.

## Project Context
CozyTalk — anonymous stranger chat app targeting Android and Web. Firebase-backed. Read `CLAUDE.md` and `PROJECT_CONTEXT.md` before reviewing.

**Privacy by Design is a hard requirement:** chat messages must be destroyed on session end. The only exception is the `reports` flow where a snapshot is retained for moderation. Any code that persists messages outside this flow is a privacy violation.

## Known Security State (current)

### Firestore rules — deployed ✓
- `users/{uid}`: user-owned read; create enforces `uid==userId` and `role=='user'`; update blocks `role`/`uid` mutation ✓
- `waiting_pool/{uid}`: user-owned; create enforces `status=='waiting'`, `createdAt==request.time`, and required fields; update restricted to `updatedAt` only (status written by Cloud Functions) ✓
- `rooms/{roomId}`: participants read active/padding rooms; any signed-in user reads expired tombstones (contains only status/expiredAt/users:[]); `isLocked` update restricted to custom-room members; create/delete CF-only ✓
- `active_sessions/{sessionId}`: **legacy proto-sessions only**; client read-only, write=false ✓
- `reports/{reportId}`: create restricted to allowed fields, `reporterId==auth.uid`, `status=='pending'`, `createdAt==request.time`; admin-only read/update/delete ✓
- `isChatRoomParticipant()`: checks both `rooms/{id}` (new) and `active_sessions/{id}` (legacy) — backward compatible ✓
- `isAdmin()` has `exists()` guard — safe for anonymous users ✓

### Realtime DB rules — deployed ✓
- `rooms/{roomId}/members/{uid}`: CF-written membership anchor; client read gated by own membership; write=false for clients ✓
- `sessions/{roomId}`: legacy proto-session compat; read scoped to session participants; write=false ✓
- `typing/{roomId}/{uid}` / `presence/{roomId}/{uid}`: user-scoped write; validates field types ✓

### Auth — current state
- Anonymous auth: on. Users get a UID but no persistent identity. Reinstall = new UID.
- Google + Email/Password: on, not yet wired in Flutter.
- Biometric/Passkey: planned (Android Keystore + WebAuthn). When implementing, credentials go in platform keystore only — never SharedPreferences, Drift, Hive, or app storage.

### Secret / config management
- `.env.example` committed with safe defaults; `.env` gitignored ✓
- `firebase_options.dart` is public by design — security comes from rules, not config secrecy ✓
- Never store secrets in SharedPreferences, Drift, Hive, or bundled assets — extractable from APK. Use `--dart-define-from-file` or server-side storage.

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
- [ ] RTDB membership path is `rooms/{roomId}/members/{uid}`, not legacy `sessions/`
- [ ] `rooms` collection: CF-only create/delete; `isLocked` update restricted to custom-room members only
- [ ] `rooms` tombstones contain only `{status:'expired', expiredAt, users:[]}` — no sensitive data
- [ ] `waiting_pool` update restricted to `updatedAt` only (status/roomId set by Cloud Functions) ✓ (deployed)
- [ ] `active_sessions` write is `false` for clients ✓ (deployed, kept for proto-session compat)
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
