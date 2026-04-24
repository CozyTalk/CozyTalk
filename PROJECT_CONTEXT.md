# CozyTalk — Project Context

> Read this before answering any questions about this project. It covers what the app is, what is already built, how everything is set up, and what still needs to be done.

---

## What is CozyTalk?

CozyTalk is a **stranger chat app** (think Omegle / anonymous chat roulette). Users are matched with a random stranger and have a one-on-one text conversation. The key flows are:

1. User opens the app → signs in (or gets anonymous auth)
2. User joins a **waiting pool** to be matched
3. A **Cloud Function** pairs two users from the pool → creates an **active session**
4. Both users are redirected into a **chat room** powered by Firebase Realtime Database
5. Either user can leave → session ends
6. Users can **report** each other for moderation

This is inferred from the Firestore security rules which already define `waiting_pool`, `active_sessions`, `reports`, and `users` collections.

---

## Tech Stack

### Flutter App (`apps/mobile/`)
| Concern | Package |
|---|---|
| State management | `flutter_riverpod` 3.3.1 + `riverpod_annotation` (code-gen) |
| Navigation | `go_router` 17.2.2 |
| Firebase | `firebase_core`, `firebase_auth`, `cloud_functions`, `cloud_firestore`, `firebase_database` |
| Models | `freezed` + `json_serializable` (code-gen) |
| Auth | `google_sign_in` |
| Local storage | `drift` + `flutter_secure_storage` |
| Config | `flutter_dotenv` |

### Cloud Functions (`functions/`)
- TypeScript, Firebase Functions v2
- One function deployed: `helloWorld` (echo, proof-of-concept)
- Max 10 instances (cost control)

### Firebase Project
- **Project ID:** `cozytalk-5d984`
- **Region:** `us-central1` (Functions), `asia-southeast1` (Realtime DB)

---

## Architecture: Clean Architecture (Feature-first)

Every feature lives under `apps/mobile/lib/features/<feature_name>/` with three layers:

```
features/<feature>/
├── domain/           ← Pure Dart. No Flutter, no Firebase.
│   ├── entities/     ← Plain data types (like TypeScript interfaces)
│   ├── repositories/ ← Abstract interfaces (contracts)
│   └── usecases/     ← One class per operation
├── data/             ← Firebase/HTTP/serialization
│   ├── models/       ← DTOs with fromJson/toJson + toEntity()
│   ├── datasources/  ← Raw SDK calls (only place Firebase is touched)
│   └── repositories/ ← Implements domain interface, calls datasource
└── presentation/     ← UI
    ├── providers/     ← Riverpod DI wiring + Notifier (state + actions)
    └── screens/       ← Flutter widgets
```

**Dependency rule:** arrows point inward only. Data imports domain. Domain imports nothing else. Presentation imports domain. Nothing imports presentation.

---

## What Is Already Built

### `hello` feature (complete, working end-to-end)
A proof-of-concept that exercises the full stack:
- User types a message in `HelloScreen`
- Riverpod `HelloNotifier` calls `CallHello` usecase
- `HelloRepositoryImpl` delegates to `HelloDatasourceImpl`
- `HelloDatasourceImpl` calls the `helloWorld` Firebase Cloud Function
- Function validates auth + input, echoes the message back
- Response flows back through the layers, UI updates

**File map:**
```
domain/entities/hello_message.dart          → type HelloMessage = { message: string }
domain/repositories/hello_repository.dart   → abstract interface
domain/usecases/call_hello.dart             → delegates to repo
data/models/hello_message_model.dart        → @freezed DTO + toEntity()
data/datasources/hello_datasource.dart      → FirebaseFunctions.httpsCallable('helloWorld')
data/repositories/hello_repository_impl.dart → impl + DTO→Entity conversion
presentation/providers/hello_provider.dart  → DI wiring + HelloState + HelloNotifier
presentation/screens/hello_screen.dart      → UI (TextField + button + result)
functions/src/index.ts                      → helloWorld Cloud Function
```

### App bootstrap (`lib/main.dart`)
- Loads `.env` on startup (falls back to `.env.example` with a warning if missing)
- Initialises Firebase
- Points Functions at local emulator if `USE_EMULATOR=true`
- Signs in anonymously if no current user
- Wraps app in `ProviderScope` (Riverpod DI root)

### Tests (`test/widget_test.dart`)
Three widget tests for `HelloScreen` using a `_FakeHelloNotifier` that tracks `callCount`:
- Renders TextField + button
- Does NOT call `callHello` on empty input (verified via `callCount == 0`)
- DOES call `callHello` on non-empty input (verified via `callCount == 1`)

---

## Firebase Configuration (Outside the Codebase)

### Authentication — enabled providers:
| Provider | Notes |
|---|---|
| **Anonymous** | On. A few test users already created. |
| **Google Sign-In** | On. Not yet wired in Flutter code. |
| **Email / Password** | On. Passwordless (email link) is OFF. Not yet wired in Flutter. |

### Firestore — rules currently deployed:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAdmin() {
      return request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    match /waiting_pool/{userId} {
      allow read, delete: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null && request.auth.uid == userId
                    && request.resource.data.createdAt == request.time;
      allow update: if request.auth != null && request.auth.uid == userId
                    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'updatedAt']);
    }

    match /active_sessions/{sessionId} {
      allow read: if request.auth != null && request.auth.uid in resource.data.users;
      allow write: if false;  // only Cloud Functions can write
    }

    match /reports/{reportId} {
      allow create: if request.auth != null;
      allow read, update, delete: if isAdmin();
    }
  }
}
```

**Current state:** No collections exist yet in Firestore — only the default empty database. Rules are deployed but there is no data.

### Realtime Database — rules currently deployed:

```json
{
  "rules": {
    "messages": {
      "$room_id": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    }
  }
}
```

**URL:** `https://cozytalk-5d984-default-rtdb.asia-southeast1.firebasedatabase.app`

**Current state:** No data. Rules are deployed.

---

## What the Security Rules Reveal About the Intended Data Model

The rules were written ahead of the schema, so they tell us the intended collections and their shape:

| Collection | Key insight from rules |
|---|---|
| `users/{userId}` | Has at least a `role` field (`'admin'` check). User-owned doc. |
| `waiting_pool/{userId}` | Has `createdAt` (server timestamp), `status`, `updatedAt`. User-owned. Client writes status/updatedAt only. |
| `active_sessions/{sessionId}` | Has a `users` array (UIDs). Client read-only — only Functions write. |
| `reports/{reportId}` | Created by any authed user. Admin-only read/update/delete. |
| `messages/$room_id` (RTDB) | Keyed by room ID. Any authed user can read/write (rules are wide open — needs tightening). |

---

## Pending Task: Database Schema Design

### What needs to be decided and documented

The team needs to define the **exact document shapes** for every collection so Flutter code and Cloud Functions can be written against a stable schema. Specifically:

#### 1. `users/{userId}` (Firestore)
What fields does a user profile have?
- `uid` / `displayName` / `photoUrl` / `email`
- `role` — at minimum `'user'` | `'admin'` (rules already depend on this)
- `createdAt` / `lastSeen`
- Are there preferences? (e.g. language, chat topics)
- Anonymous users: do they get a profile doc? What is in it?

#### 2. `waiting_pool/{userId}` (Firestore)
What does the matchmaking entry look like?
- `createdAt` (already required by rules — must be server timestamp)
- `status` (already required by rules — what are the valid values? `waiting` | `matched` | ?)
- `updatedAt`
- Any matching preferences? (e.g. language filter, topic)
- Does the Cloud Function write the matched partner's UID here, or does it just delete this doc and create an `active_session`?

#### 3. `active_sessions/{sessionId}` (Firestore)
What is in a session doc?
- `users: [uid1, uid2]` (already required by rules)
- `roomId` — the Realtime DB room key for messages
- `createdAt` / `endedAt`
- `status`: `active` | `ended`
- Who can end a session? (rules say client write is `false` — Cloud Function only)
- What triggers session creation? (matching Cloud Function)
- What triggers session end? (user leaves? timeout?)

#### 4. `reports/{reportId}` (Firestore)
What does a report contain?
- `reporterId` (the user who filed it)
- `reportedUserId`
- `sessionId` (the session it happened in)
- `reason` / `description`
- `createdAt`
- `status`: `pending` | `reviewed` | `dismissed`

#### 5. `messages/$room_id` (Realtime Database)
What does a message look like?
- `$messageId` (push key): `{ senderId, text, timestamp }`
- Should messages be read-restricted to only the two users in the session?
- Current rules allow ANY authed user to read/write ANY room — this is too permissive and needs tightening once session IDs are decided.

### Key design decisions to make

1. **Is `sessionId` the same as `roomId` in RTDB?** Simplest if yes — one ID links Firestore session metadata to RTDB messages.
2. **Who generates the `sessionId`?** Cloud Function (most logical — it's the only writer).
3. **Matching flow:** Cloud Function polls / listens to `waiting_pool` → pairs two users → creates `active_sessions` doc + RTDB room → deletes both `waiting_pool` entries → notifies both clients (via Firestore listener on `active_sessions`? or FCM?).
4. **Anonymous users:** Do they get a `users` doc? Without one, the `isAdmin()` function will throw if called on an anonymous user (Firestore `get()` on a missing doc). Needs a guard.
5. **RTDB rules:** Tighten so only the two users in a session can read/write their room. Requires either duplicating the user list into RTDB or calling a Custom Claim.

---

## Local Development Setup

```bash
# 1. Install dependencies
cd apps/mobile && flutter pub get
cd functions && npm install

# 2. Generate Freezed/Riverpod code
cd apps/mobile && dart run build_runner build --delete-conflicting-outputs

# 3. Create local env (fresh clone only)
cp apps/mobile/.env.example apps/mobile/.env
# Edit .env: set USE_EMULATOR=true for local, false for prod

# 4a. Run against Firebase emulator
cd functions && npm run serve   # terminal 1
cd apps/mobile && flutter run   # terminal 2 (USE_EMULATOR=true)

# 4b. Run against live Firebase
# Set USE_EMULATOR=false in .env, then:
cd apps/mobile && flutter run
```

---

## Repository Layout

```
CozyTalk/
├── apps/
│   └── mobile/               ← Flutter app
│       ├── lib/
│       │   ├── main.dart
│       │   └── features/
│       │       └── hello/    ← only feature so far (proof-of-concept)
│       ├── test/
│       │   └── widget_test.dart
│       ├── .env.example      ← committed, USE_EMULATOR=false
│       └── .env              ← gitignored, local overrides
├── functions/
│   └── src/
│       └── index.ts          ← helloWorld Cloud Function
├── packages/                 ← reserved, empty
├── tools/                    ← reserved, empty
├── CLEAN_ARCH_EXPLAINER.md   ← architecture guide (Express/Java analogies)
├── PROJECT_CONTEXT.md        ← this file
└── firebase.json
```

---

## Git History (branch: `feat/example-clean-archi`)

| Commit | What it did |
|---|---|
| `390dd4a` | Added all Flutter dependencies to pubspec.yaml |
| `2f9b3f6` | Fixed type checking in Cloud Functions |
| `b1d162c` | Integrated Firebase with Cloud Functions |
| `1712dac` | Added example files + multi-agent Claude workflow setup |
| `a75b645` | **Replaced example stubs with working `hello` feature (clean arch)** |
| `f13359b` | Added CLEAN_ARCH_EXPLAINER.md |
| `3837ffa` | Fixed 5 code review issues (sentinel copyWith, loading guard, Map type, .env asset, widget test) |
| `07842f9` | Improved .env loading (try .env → fallback .env.example with clear warning) |
