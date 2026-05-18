# CozyTalk â€” Project Context

> Full project reference. Read before answering any questions about this project.

---

## What is CozyTalk?

CozyTalk is a **cross-platform stranger chat app** targeting **Android and Web**. Users are matched anonymously with a random stranger for a one-on-one text conversation. The goal is to provide a low-pressure space for authentic interactions â€” combating social media performance fatigue.

**Core Privacy Principle:** Chats are ephemeral. When a user leaves or presses Skip, the room and all messages are immediately destroyed by a Cloud Function. The only exception is when a user files a report â€” in that case the chat log is retained for moderation.

---

## Tech Stack

### Flutter App (`apps/mobile/`) â€” Android + Web
| Concern | Package |
|---|---|
| State management | `flutter_riverpod` 3.3.1 + `riverpod_annotation` (code-gen) |
| Navigation | `MaterialApp.routes` + `AppRoutes` constants (`theme/app_routes.dart`). `go_router` is in `pubspec.yaml` but never imported or used. |
| Firebase | `firebase_core`, `firebase_auth`, `cloud_functions`, `cloud_firestore`, `firebase_database` |
| Observability | Structured CF logging (`firebase-functions/logger`) |
| Models | `freezed` + `json_serializable` (code-gen) |
| Auth | `google_sign_in` |
| Local caching | `flutter_secure_storage` |

### Cloud Functions (`functions/`)
- TypeScript, Firebase Functions v2
- 15 functions exported across two regions (see Cloud Functions table in Firebase Configuration)
- Max 10 instances (cost control)
- Matchmaking and chat logic **must** live here â€” never on client

### Firebase Project
- **Project ID:** `cozytalk-5d984`
- **Region:** `us-central1` (Functions), `asia-southeast1` (Realtime DB)

---

## Architecture: Clean Architecture (feature-first)

```
features/<feature>/
â”œâ”€â”€ domain/           â† Pure Dart. No Flutter, no Firebase.
â”‚   â”œâ”€â”€ entities/     â† Plain data types
â”‚   â”œâ”€â”€ repositories/ â† Abstract interfaces
â”‚   â””â”€â”€ usecases/     â† One class per operation
â”œâ”€â”€ data/             â† Firebase/HTTP/serialization
â”‚   â”œâ”€â”€ models/       â† @freezed DTOs + toEntity()
â”‚   â”œâ”€â”€ datasources/  â† Raw SDK calls only
â”‚   â””â”€â”€ repositories/ â† Interface impl + DTOâ†’Entity
â””â”€â”€ presentation/     â† UI
    â”œâ”€â”€ providers/     â† Riverpod DI + Notifier + State
    â””â”€â”€ screens/       â† ConsumerStatefulWidget pages
```

See `CLAUDE.md` for full conventions and code patterns.

---

## App Screens & User Flow

```
Login Screen
    â”œâ”€â”€ [Email + Password] â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
    â”œâ”€â”€ [Sign in with Google] â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
    â”œâ”€â”€ [Continue as Guest] â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ authenticated
    â””â”€â”€ [Don't have an account?] â†’ Sign Up Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
            â†“
Waiting / Searching  â†â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
    â†“  [matched by Cloud Function]               â”‚
Chat Room                                        â”‚
    â”œâ”€â”€ [Skip / Next Person] â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
    â”œâ”€â”€ [Leave] â†’ session destroyed
    â””â”€â”€ [Report] â†’ chat log retained, session destroyed
Profile / Settings (planned)
    â”œâ”€â”€ Edit display name
    â”œâ”€â”€ Upgrade from anonymous â†’ Google / Email
    â””â”€â”€ Sign out
```

### Chat Room UI Components
- Message bubbles (sent / received)
- Typing indicator
- **Moods / Drinks SVG icebreakers** â€” tappable stickers
- **Skip / Next Person** button (prominent â€” core UX)
- Connection status indicator

### Session State Machine
```
Idle â†’ Searching â†’ Matched/Chatting â†’ Disconnected
                                    â†˜ (Skip) â†’ Searching
```
The chat Notifier must model all four states explicitly as an enum â€” never infer from nullable fields.

---

## What Is Already Built

### `hello` feature (proof-of-concept, complete)
End-to-end clean arch example: `HelloScreen` â†’ `HelloNotifier` â†’ `CallHello` usecase â†’ `HelloRepositoryImpl` â†’ `HelloDatasourceImpl` â†’ `helloWorld` Cloud Function â†’ response flows back. This is the **primary template** for all future features.

### `auth` feature (complete)
Full authentication flow following the same Clean Architecture pattern.

**Domain:** `AuthUser` entity, `AuthRepository` interface, use cases: `SignUp`, `SignIn`, `SignOut`, `SignInAnonymously`, `SignInWithGoogle`.

**Data:** `AuthUserModel` (`@freezed` DTO), `AuthDatasourceImpl` (Firebase Auth + Firestore writes), `AuthRepositoryImpl`. Platform-specific Google sign-in: `signInWithPopup` on web, `google_sign_in` SDK on native.

**Presentation:**
- `AuthStatus` enum: `idle | loading | authenticated | unauthenticated`
- `AuthState` with sentinel `copyWith` for `user` and `error`
- `AuthNotifier` watching `FirebaseAuth.authStateChanges()` via the repository stream
- `LoginScreen` â€” email/password form + "Sign in with Google" + "Continue as Guest"
- `SignupScreen` â€” email/password/confirm form; pops to root on success

**Firestore user doc** is created by the datasource on `signUp` and on first-time Google sign-in (`additionalUserInfo.isNewUser == true`). Anonymous users get a minimal doc on first sign-in (uid, role, createdAt, lastSeen).

### `matchmaking` feature (complete)
Full Clean Architecture feature for joining the waiting pool, creating/joining rooms, and watching for a match. See [`CLAUDE.md` Matchmaking section](CLAUDE.md) and [`MATCHMAKING_CONTEXT_AWARE.md`](MATCHMAKING_CONTEXT_AWARE.md) for details.

### `chat` feature (complete)
In-session messaging layer. Handles AES-256-GCM message decryption, streaming messages and typing indicators, and session teardown. Works with both proto-sessions (client-side encryption) and 1v1 sessions (Cloud Function encryption). See [`CLAUDE.md` Chat Feature section](CLAUDE.md).

### `profile` feature (complete)
Read and update user profile fields (`displayName`, `interest`, `thoughts`) in `users/{uid}`. See [`CLAUDE.md` Profile Feature section](CLAUDE.md).

### `avatar` feature (complete)
Hat and mood overlay selection for the in-chat avatar. Reads/writes `hatKey` and `moodKey` fields in `users/{uid}`. See [`CLAUDE.md` Avatar Feature section](CLAUDE.md).

### `home` feature (stub)
Navigation hub `HomeScreen`. Used only when `_useMainUI = true`. No domain/data layers â€” intentionally thin.

### App bootstrap (`lib/main.dart`)
Initialises Firebase, points to emulators (Auth `9099`, Functions `5001`, Firestore `8080`) when `USE_EMULATOR=true`. No automatic sign-in â€” `_AuthRouter` widget watches `authNotifierProvider` and routes to `LoginScreen` or `HelloScreen`.

### Tests
515 Flutter unit + widget tests across auth, chat, matchmaking, profile, hello, and admin features. See [Test Coverage](#quality-gates-definition-of-done) for the full breakdown.

---

## Firebase Configuration

### Authentication â€” enabled providers
| Provider | Status |
|---|---|
| **Anonymous** | On. Wired in Flutter â€” "Continue as Guest" button on `LoginScreen`. |
| **Google Sign-In** | On. Wired in Flutter â€” web uses `signInWithPopup`, native uses `google_sign_in` SDK. |
| **Email / Password** | On. Passwordless OFF. Wired in Flutter â€” `LoginScreen` + `SignupScreen`. |
| **Biometric / Passkey** | Planned â€” Android Keystore + WebAuthn. Not yet implemented. |

### Firestore Security Rules â€” `firestore.rules` (deployed âœ“)

See `firestore.rules` for the canonical source. Key helper functions and per-collection rules:

**Helper functions:**
- `isSignedIn()` â€” `request.auth != null`
- `isOwner(uid)` â€” signed in and `request.auth.uid == uid`
- `isAdmin()` â€” signed in + `users/{uid}.role == 'admin'`
- `_isRoomsParticipant(sessionId)` â€” uid in `rooms/{sessionId}.users`
- `_isActiveSessionParticipant(sessionId)` â€” uid in `active_sessions/{sessionId}.users`
- `isChatRoomParticipant(sessionId)` â€” either of the above (spans new rooms + legacy sessions)

**Per-collection rules summary:**

| Collection | read | create | update | delete |
|---|---|---|---|---|
| `users/{userId}` | owner only | owner; `role=='user'`, `uid==userId`, known-field allowlist | owner; `role`, `uid`, `createdAt` immutable; only `hatKey`, `moodKey`, `displayName`, `photoUrl`, `lastSeen`, `email`; `hatKey`/`moodKey` must be strings | â€” |
| `waiting_pool/{userId}` | owner | owner; `createdAt==request.time`, `status=='waiting'`, required keys present | owner; only `updatedAt` field, must equal `request.time` | owner |
| `rooms/{roomId}` | member or expired tombstone (any signed-in) | false (CF only) | member on custom room; only `isLocked` field | false |
| `active_sessions/{sessionId}` | member or `proto-*` prefix (any signed-in) | false | false | false |
| `reports/{reportId}` | admin only | signed-in; `reporterId==uid`, `status=='pending'`, required fields | admin only | admin only |
| `chat_rooms/{sessionId}/messages/{messageId}` | participant or `proto-*` | participant; required encrypted fields, `senderId==uid`, text â‰¤12 KB | false | false |

### Realtime Database â€” `database.rules.json` (deployed âœ“)

**URL:** `https://cozytalk-5d984-default-rtdb.asia-southeast1.firebasedatabase.app`

See `database.rules.json` for the canonical source. All nodes require `auth != null` at minimum.

| Node | Value | Access | Notes |
|---|---|---|---|
| `rooms/{roomId}/members/{uid}` | boolean | Read: room member; Write: owner | CF-written membership anchor for new rooms |
| `typing/{roomId}/{uid}` | `{ isTyping: bool, displayName: string }` | Read: any signed-in; Write: owner | `displayName` max 100 chars |
| `presence/{roomId}/{uid}` | string (displayName) | Read: any signed-in; Write: owner | Max 30 chars; `onDisconnect().remove()` |
| `nameQueue/{roomId}` | any | Read/Write: room member only | Transient display name exchange on room join |
| `pool_presence/{uid}` | boolean | Read/Write: owner | Tracks whether user is actively in the waiting pool |

### Firestore Indexes â€” `firestore.indexes.json` (deployed âœ“)

| Collection | Fields | Query |
|---|---|---|
| `waiting_pool` | `status ASC, createdAt ASC` | Legacy: oldest waiting user (no mode filter) |
| `waiting_pool` | `mode ASC, status ASC, createdAt ASC` | Matchmaking: oldest waiting user by mode |
| `waiting_pool` | `mode ASC, status ASC, updatedAt ASC` | Matchmaking: most-recently-updated waiting user by mode |
| `reports` | `status ASC, createdAt DESC` | Admin dashboard: pending reports by time |
| `rooms` | `mode ASC, status ASC, isLocked ASC, memberCount ASC` | Group room picker: available unlocked rooms by fill level |
| `rooms` | `status ASC, paddingUntil ASC` | `expireRooms` cron: find rooms past their padding window |

### Cloud Functions â€” deployed (15 total)

| Function | Trigger | Region | Module |
|---|---|---|---|
| `helloWorld` | callable | us-central1 | â€” |
| `joinGroupRoom` | callable | us-central1 | matchmaking |
| `createCustomRoom` | callable | us-central1 | matchmaking |
| `joinRoomById` | callable | us-central1 | matchmaking |
| `leaveRoom` | callable | us-central1 | matchmaking |
| `join1v1Pool` | callable | us-central1 | matchmaking |
| `cancel1v1Pool` | callable | us-central1 | matchmaking |
| `setRoomLock` | callable | us-central1 | matchmaking |
| `expireRooms` | scheduled (`*/2 * * * *`) | us-central1 | matchmaking |
| `match1v1Users` | Firestore onCreate `waiting_pool/{uid}` | asia-southeast1 | matchmaking |
| `cleanupMember` | RTDB onDelete `rooms/{roomId}/members/{uid}` | asia-southeast1 | matchmaking |
| `cleanupPoolMember` | RTDB onDelete `pool_presence/{uid}` | asia-southeast1 | matchmaking |
| `sendMessage` | callable | us-central1 | chat |
| `endSession` | callable | us-central1 | chat |
| `reportSession` | callable | us-central1 | chat |
No CF needed for typing â€” clients write `typing/{roomId}/{uid}` directly via RTDB SDK.

`seedTtlCollections` (`functions/src/dev/`) is a one-time dev HTTP helper; not included in the exported count above.

`onProtoPresenceDeleted` (`functions/src/chat/`) is an RTDB trigger for proto-session presence cleanup; internal, not exported.

### Feature Flags â€” Firebase Remote Config

`icebreakers_enabled` (boolean, default `true`) â€” gates the Moods/Drinks SVG sticker panel.
Rollback: set to `false` in Remote Config console; clients pick it up within 12 hours.

---

## Database Schema (Finalized)

### `users/{uid}` (Firestore)
| Field | Type | Notes |
|---|---|---|
| `uid` | string | matches auth UID; immutable |
| `displayName` | string? | null for anonymous |
| `photoUrl` | string? | null for anonymous |
| `email` | string? | null for anonymous |
| `role` | string | `'user'` \| `'admin'`; immutable after creation |
| `createdAt` | timestamp | immutable after creation |
| `lastSeen` | timestamp | updated on profile refresh |
| `hatKey` | string? | avatar hat decoration key; absent = no hat |
| `moodKey` | string? | avatar mood decoration key; absent = no mood |
| `interest` | string? | user's free-text interest (used for embedding-based matchmaking) |
| `thoughts` | string? | short status/mood text; max 50 chars |

Anonymous users get a minimal doc on first sign-in (`uid`, `role: 'user'`, `createdAt`, `lastSeen`) to prevent `isAdmin()` from throwing. The avatar datasource will also create this minimal doc (plus the decoration field) if it doesn't exist yet.

### `waiting_pool/{uid}` (Firestore)
| Field | Type | Notes |
|---|---|---|
| `createdAt` | timestamp | must be `request.time` (rules enforced) |
| `status` | string | `'waiting'` â†’ `'matching'` â†’ `'matched'` (CF-managed) |
| `updatedAt` | timestamp | client-updatable only |
| `mode` | string | `'1v1'` \| `'group'` |
| `roomId` | string? | set by CF when matched (1v1 only) |

### `rooms/{roomId}` (Firestore) â€” Primary Room Collection
All new rooms (1v1 + group). Doc ID is the 5-char user-facing room ID. CF-only writer except `isLocked` on custom rooms. Expired rooms keep a tombstone forever to prevent ID reuse.

| Field | Type | Notes |
|---|---|---|
| `roomId` | string | 5-char alphanumeric, matches doc ID |
| `roomType` | string | `'public'` \| `'custom'` |
| `mode` | string | `'1v1'` \| `'group'` |
| `status` | string | `'active'` \| `'padding'` \| `'expired'` |
| `maxUsers` | number | `2` for 1v1, `5` for group |
| `memberCount` | number | 0â€“maxUsers |
| `users` | string[] | current member UIDs |
| `isLocked` | boolean | custom rooms only; participants update directly via rules |
| `createdAt` | timestamp | server timestamp |
| `paddingUntil` | timestamp? | set when last user leaves; `expireRooms` cron cleans up after |
| `encryptionKey` | string | hex AES-256 key, generated at room creation |

Expired tombstone shape: `{ status: 'expired', expiredAt: Timestamp, users: [] }`

### `active_sessions/{sessionId}` (Firestore) â€” Legacy
**Proto-session backward compat only.** New sessions use `rooms/{roomId}`.

| Field | Type | Notes |
|---|---|---|
| `users` | string[] | `[uid1, uid2]` â€” used by Firestore rules |
| `roomId` | string | equals `sessionId` |
| `createdAt` | timestamp | |
| `endedAt` | timestamp? | set on session end |
| `status` | string | `'active'` \| `'ended'` |

### `reports/{reportId}` (Firestore)
| Field | Type | Notes |
|---|---|---|
| `reporterId` | string | UID of reporting user |
| `reportedUserId` | string | UID of reported user |
| `sessionId` | string | session where it occurred |
| `encryptionKey` | string | hex AES-256 key stored for moderator decryption; CF-written via admin SDK only |
| `reason` | string | max 500 chars |
| `description` | string? | max 2000 chars |
| `createdAt` | timestamp | |
| `status` | string | `'pending'` \| `'reviewed'` \| `'dismissed'` |

### `chat_rooms/{sessionId}/messages/{messageId}` (Firestore)
Encrypted message store. Written by the `sendMessage` CF. TTL policy on `expiresAt` auto-deletes messages after the retention window (3 days). Destroyed immediately by `leaveRoom`/`endSession` unless a report is pending.

| Field | Type | Notes |
|---|---|---|
| `senderId` | string | UID of sender |
| `displayName` | string | display name at time of send; max 200 chars |
| `encryptedText` | string | base64 AES-256-GCM ciphertext; max 12 KB |
| `iv` | string | base64 GCM IV; max 24 chars |
| `authTag` | string | base64 GCM auth tag; max 32 chars |
| `timestamp` | timestamp | server timestamp |
| `expiresAt` | timestamp | TTL field â€” Firestore auto-deletes after this |
| `flagged` | boolean | always `false` at creation; set by `reportSession` CF |

### `session_keys/{sessionId}` (Firestore)
Archives the AES-256 room encryption key so moderators can decrypt flagged messages within the 3-day retention window. Created by `endSession` CF. TTL policy on `expiresAt`.

| Field | Type | Notes |
|---|---|---|
| `sessionId` | string | matches doc ID |
| `encryptionKey` | string | hex AES-256 key |
| `users` | string[] | `[uid1, uid2]` |
| `createdAt` | timestamp | original session creation time |
| `expiresAt` | timestamp | 3 days after session end; TTL field |
| `flagged` | boolean | set to `true` by `reportSession` to prevent premature TTL deletion |

### RTDB Real-time Paths
See the RTDB rules table above (under Firebase Configuration) for the full path list with access controls. Summary:

| Path | Purpose |
|---|---|
| `rooms/{roomId}/members/{uid}` | CF-written membership anchor (new rooms) |
| `typing/{roomId}/{uid}` | Real-time typing indicator |
| `presence/{roomId}/{uid}` | Real-time presence; `onDisconnect().remove()` |
| `nameQueue/{roomId}` | Transient display name exchange on room join |
| `pool_presence/{uid}` | Whether user is actively in the waiting pool |

Presence, typing, and nameQueue data are removed by `leaveRoom` CF on explicit leave and by `expireRooms` on room expiry. `cleanupMember` (RTDB trigger) fires when a `rooms/{roomId}/members/{uid}` node is deleted to handle abrupt disconnects.

---

## Development Phases (WBS)

| Phase | Work | Status |
|---|---|---|
| **1.0 Frontend & UI** | UI/UX design, Auth screens, Waiting screen, Chat Room UI (bubbles, typing, SVGs, Skip) | Auth complete; main UI screens complete (not yet wired to backend) |
| **2.0 Backend & Matchmaking** | Matchmaking Cloud Functions (race-condition safe), session cleanup/lifecycle, word censor, reporting | **Largely complete** â€” 15 CFs exported (matchmaking + chat); Flutter matchmaking + chat + avatar + profile features complete; 99 Jest unit tests + 43 Flutter integration tests passing; word censor + group reporting deferred |
| **3.0 Logic & Integration** | Wire main UI to matchmaking backend, session state machine, network drop detection, biometric/passkey auth | Not started |
| **4.0 Testing & Management** | Cross-platform UI tests (Android + Web), accessibility sweeps, performance profiling | Not started |

---

## Quality Gates (Definition of Done)

| Gate | Requirement |
|---|---|
| **Correctness** | >80% unit test coverage for domain layer; widget tests for all screens; integration tests on Android + Web |
| **Security** | Zero High/Critical vulnerabilities; secret scan clean; no plaintext secrets |
| **Accessibility** | WCAG 2.2 AA on all screens (semantic labels, contrast, dynamic type) |
| **Performance** | No unbounded ListViews; SVGs cached/compressed; no jank on message scroll |

### Test Coverage (~450+ tests total)

| Suite | Count | Location | Requires |
|---|---|---|---|
| Flutter unit + widget | 515 tests | `apps/mobile/test/` | Nothing |
| Cloud Functions Jest | 93 unit tests | `functions/src/**/__tests__/*.test.ts` | `./dev.sh --emulator-only` |
| Cloud Functions Jest (integration) | 7 live tests | `functions/src/matchmaking/__tests__/embeddingService.integration.test.ts` | Vertex AI credentials + `npm run test:embedding` |
| Flutter integration | 43 tests | `apps/mobile/integration_test/matchmaking_advanced_test.dart` | Emulators + Android device |

**CF Jest unit test breakdown:** `matchmaking.test.ts` (60 tests, 14 describe groups â€” priority selection, distribution, padding lifecycle, RTDB cleanup, 1v1/group flows, interest matching), `embeddingService.test.ts` (21 tests â€” cosine similarity, mean vector, mocked Vertex AI), `chat.test.ts` (12 tests â€” sendMessage, message destruction, TTL, rooms/ path, reportSession). Plus 7 integration tests in `embeddingService.integration.test.ts` (live Vertex AI, requires `npm run test:embedding`). Grand total: 100.

**Jest vs Flutter integration:** Jest tests run on the host (no Android clock skew) so timing bounds are tight (â‰¤35s padding). Flutter integration tests use â‰¤60s bounds to account for Android emulator clock offset.

---

## The Do-Not-Do List

| âŒ Never | Reason |
|---|---|
| Import Flutter/Firebase into domain layer | Clean arch violation |
| Matchmaking on client | Race conditions |
| Persist chat messages | Privacy by Design |
| Hand-roll toJson/fromJson | Use Freezed |
| Store secrets in SharedPreferences, Drift, Hive, or assets | Extractable from APK/IPA |
| Edit `*.g.dart` / `*.freezed.dart` | Run build_runner instead |
| Unbounded `ListView(children: [...])` for dynamic data | Performance |

---

## Repository Layout

```
CozyTalk/
â”œâ”€â”€ apps/mobile/                      â† Flutter app (Android + Web)
â”‚   â”œâ”€â”€ lib/
â”‚   â”‚   â”œâ”€â”€ main.dart                 â† Firebase init, emulator setup, _AuthRouter
â”‚   â”‚   â”œâ”€â”€ features/
â”‚   â”‚   â”‚   â”œâ”€â”€ hello/                â† proof-of-concept template (complete)
â”‚   â”‚   â”‚   â”œâ”€â”€ auth/                 â† authentication (complete; LoginScreen, SignupScreen)
â”‚   â”‚   â”‚   â”œâ”€â”€ matchmaking/          â† room joining + 1v1 pool (complete; 9 use cases)
â”‚   â”‚   â”‚   â”œâ”€â”€ chat/                 â† in-session messaging + typing (complete; 5 use cases)
â”‚   â”‚   â”‚   â”œâ”€â”€ profile/              â† display name, interest, thoughts (complete; 4 use cases)
â”‚   â”‚   â”‚   â”œâ”€â”€ avatar/               â† hat + mood decoration (complete; 4 use cases; screen widget test pending)
â”‚   â”‚   â”‚   â””â”€â”€ home/                 â† navigation hub stub (presentation only)
â”‚   â”‚   â””â”€â”€ screens/                  â† legacy design-preview UI (not wired to features layer)
â”‚   â”œâ”€â”€ test/                         â† 515 unit + widget tests
â”‚   â””â”€â”€ .env.example                  â† committed; USE_EMULATOR=true by default
â”œâ”€â”€ functions/src/
â”‚   â”œâ”€â”€ index.ts                      â† exports all 15 functions
â”‚   â”œâ”€â”€ matchmaking/                  â† 11 exported CFs + embeddingService.ts + _utils.ts + __tests__/
â”‚   â”œâ”€â”€ chat/                         â† sendMessage, endSession, reportSession (exported); onProtoPresenceDeleted (internal stub)
â”‚   â””â”€â”€ dev/                          â† seedTtlCollections (one-time HTTP dev helper)
â”œâ”€â”€ firestore.rules                   â† deployed Firestore security rules
â”œâ”€â”€ database.rules.json               â† deployed RTDB security rules
â”œâ”€â”€ firestore.indexes.json            â† Firestore composite indexes (6 indexes)
â”œâ”€â”€ firebase.json                     â† Firebase deploy config (predeploy: npm --prefix functions)
â”œâ”€â”€ .gitattributes                    â† enforces LF line endings repo-wide
â”œâ”€â”€ .claude/agents/                   â† specialized agent definitions
â”œâ”€â”€ CLAUDE.md                         â† auto-loaded by Claude Code every session
â””â”€â”€ PROJECT_CONTEXT.md                â† this file
```


