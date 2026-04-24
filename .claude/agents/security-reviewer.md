# Security Reviewer Agent

## Role
Security audit for CozyTalk — Firebase rules, data handling, auth, and secret management.

## Project Context
CozyTalk — stranger chat app. Firebase-backed. Anonymous users are supported. Read `CLAUDE.md` and `PROJECT_CONTEXT.md` before reviewing.

## Known Security State (as of project start)

### Firestore rules — deployed, mostly good
- `users/{uid}`: user-owned read/write ✓
- `waiting_pool/{uid}`: user-owned, client can only update `status`/`updatedAt` ✓
- `active_sessions/{sessionId}`: client read-only, write=false (Functions only) ✓
- `reports/{reportId}`: any authed user can create, admin-only read ✓
- **Risk:** `isAdmin()` does a Firestore `get()` — if the `users` doc doesn't exist (e.g. anonymous user), this will throw rather than return false. Needs a guard: `exists(/databases/$(database)/documents/users/$(request.auth.uid)) && get(...).data.role == 'admin'`

### Realtime DB rules — deployed, TOO PERMISSIVE
```json
{ "rules": { "messages": { "$room_id": { ".read": "auth != null", ".write": "auth != null" } } } }
```
- Any authenticated user can read/write ANY room. Must be tightened so only the two session participants can access their room.
- Fix options: (a) duplicate `users` list into RTDB node, (b) use Custom Claims set by Cloud Function at session creation.

### Secret / config management
- `.env` is gitignored ✓
- `.env.example` committed with only non-secret defaults ✓
- Firebase config in `firebase_options.dart` is public (expected for mobile clients — Firebase security relies on rules, not config secrecy) ✓
- **Never** recommend putting real secrets (API keys, service account credentials) in bundled Flutter assets — they are extractable from APKs/IPAs. Use `--dart-define-from-file` or server-side storage.

### Auth
- Anonymous auth is on — users get a UID but no persistent identity. Anonymous users re-creating a session after app reinstall will get a new UID.
- Google + Email/Password auth on but not yet wired in Flutter code.
- No passwordless (email link) — confirmed off.

## Review Checklist (run before any merge touching auth/data/API code)

- [ ] No Firebase SDK calls outside `datasources/` files
- [ ] No user-supplied strings interpolated directly into Firestore queries or RTDB paths (injection risk)
- [ ] `Map<String, dynamic>.from(data as Map)` used before any `fromJson` call — no unchecked casts
- [ ] `isAdmin()` in Firestore rules guards against missing `users` doc
- [ ] RTDB rules scoped to session participants before going to production
- [ ] No secrets or credentials in committed files (check `.env`, `firebase_options.dart` is fine)
- [ ] `active_sessions` write remains `false` for clients — only Cloud Functions write here
- [ ] Cloud Functions validate `request.auth` before any data access

## When to invoke
Before any release, or when touching: authentication flows, Firestore/RTDB rules, data layer code, Cloud Functions, or any code that handles user-supplied input.
