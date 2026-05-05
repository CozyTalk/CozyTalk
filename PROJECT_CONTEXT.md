# CozyTalk — Project Context

> Full project reference. Read before answering any questions about this project.

---

## What is CozyTalk?

CozyTalk is a **cross-platform stranger chat app** targeting **Android and Web**. Users are matched anonymously with a random stranger for a one-on-one text conversation. The goal is to provide a low-pressure space for authentic interactions — combating social media performance fatigue.

**Core Privacy Principle:** Chats are ephemeral. When a user leaves or presses Skip, the room and all messages are immediately destroyed by a Cloud Function. The only exception is when a user files a report — in that case the chat log is retained for moderation.

---

## Tech Stack

### Flutter App (`apps/mobile/`) — Android + Web
| Concern | Package |
|---|---|
| State management | `flutter_riverpod` 3.3.1 + `riverpod_annotation` (code-gen) |
| Navigation | `go_router` 17.2.2 with auth guards |
| Firebase | `firebase_core`, `firebase_auth`, `cloud_functions`, `cloud_firestore`, `firebase_database` |
| Observability | Firebase Crashlytics + structured logging |
| Models | `freezed` + `json_serializable` (code-gen) |
| Auth | `google_sign_in` |
| Local caching | `drift` + `flutter_secure_storage` (offline-first degradation) |
| Config | `flutter_dotenv` |

### Cloud Functions (`functions/`)
- TypeScript, Firebase Functions v2
- Deployed: `helloWorld` (echo, proof-of-concept — to be replaced by matchmaking)
- Max 10 instances (cost control)
- Matchmaking logic **must** live here — never on client

### Firebase Project
- **Project ID:** `cozytalk-5d984`
- **Region:** `us-central1` (Functions), `asia-southeast1` (Realtime DB)

---

## Architecture: Clean Architecture (feature-first)

```
features/<feature>/
├── domain/           ← Pure Dart. No Flutter, no Firebase.
│   ├── entities/     ← Plain data types
│   ├── repositories/ ← Abstract interfaces
│   └── usecases/     ← One class per operation
├── data/             ← Firebase/HTTP/serialization
│   ├── models/       ← @freezed DTOs + toEntity()
│   ├── datasources/  ← Raw SDK calls only
│   └── repositories/ ← Interface impl + DTO→Entity
└── presentation/     ← UI
    ├── providers/     ← Riverpod DI + Notifier + State
    └── screens/       ← ConsumerStatefulWidget pages
```

See `CLAUDE.md` for full conventions and code patterns.

---

## App Screens & User Flow

```
Login Screen
    ├── [Email + Password] ──────────────────────────────────┐
    ├── [Sign in with Google] ───────────────────────────────┤
    ├── [Continue as Guest] ───────────────────────────────── authenticated
    └── [Don't have an account?] → Sign Up Screen ───────────┘
            ↓
Waiting / Searching  ←──────────────────────────┐
    ↓  [matched by Cloud Function]               │
Chat Room                                        │
    ├── [Skip / Next Person] ────────────────────┘
    ├── [Leave] → session destroyed
    └── [Report] → chat log retained, session destroyed
Profile / Settings (planned)
    ├── Edit display name
    ├── Upgrade from anonymous → Google / Email
    └── Sign out
```

### Chat Room UI Components
- Message bubbles (sent / received)
- Typing indicator
- **Moods / Drinks SVG icebreakers** — tappable stickers
- **Skip / Next Person** button (prominent — core UX)
- Connection status indicator

### Session State Machine
```
Idle → Searching → Matched/Chatting → Disconnected
                                    ↘ (Skip) → Searching
```
The chat Notifier must model all four states explicitly as an enum — never infer from nullable fields.

---

## What Is Already Built

### `hello` feature (proof-of-concept, complete)
End-to-end clean arch example: `HelloScreen` → `HelloNotifier` → `CallHello` usecase → `HelloRepositoryImpl` → `HelloDatasourceImpl` → `helloWorld` Cloud Function → response flows back. This is the **primary template** for all future features.

### `auth` feature (complete)
Full authentication flow following the same Clean Architecture pattern.

**Domain:** `AuthUser` entity, `AuthRepository` interface, use cases: `SignUp`, `SignIn`, `SignOut`, `SignInAnonymously`, `SignInWithGoogle`.

**Data:** `AuthUserModel` (`@freezed` DTO), `AuthDatasourceImpl` (Firebase Auth + Firestore writes), `AuthRepositoryImpl`. Platform-specific Google sign-in: `signInWithPopup` on web, `google_sign_in` SDK on native.

**Presentation:**
- `AuthStatus` enum: `idle | loading | authenticated | unauthenticated`
- `AuthState` with sentinel `copyWith` for `user` and `error`
- `AuthNotifier` watching `FirebaseAuth.authStateChanges()` via the repository stream
- `LoginScreen` — email/password form + "Sign in with Google" + "Continue as Guest"
- `SignupScreen` — email/password/confirm form; pops to root on success

**Firestore user doc** is created by the datasource on `signUp` and on first-time Google sign-in (`additionalUserInfo.isNewUser == true`). Anonymous users do not get a Firestore doc.

### App bootstrap (`lib/main.dart`)
Initialises Firebase, points to emulators (Auth `9099`, Functions `5001`, Firestore `8080`) when `USE_EMULATOR=true`. No automatic sign-in — `_AuthRouter` widget watches `authNotifierProvider` and routes to `LoginScreen` or `HelloScreen`.

### Tests (`test/widget_test.dart`)
Three widget tests for `HelloScreen` using `_FakeHelloNotifier` with `callCount` — all passing.

---

## Firebase Configuration

### Authentication — enabled providers
| Provider | Status |
|---|---|
| **Anonymous** | On. Wired in Flutter — "Continue as Guest" button on `LoginScreen`. |
| **Google Sign-In** | On. Wired in Flutter — web uses `signInWithPopup`, native uses `google_sign_in` SDK. |
| **Email / Password** | On. Passwordless OFF. Wired in Flutter — `LoginScreen` + `SignupScreen`. |
| **Biometric / Passkey** | Planned — Android Keystore + WebAuthn. Not yet implemented. |

### Firestore Security Rules — `firestore.rules` (deployed ✓)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(uid) {
      return isSignedIn() && request.auth.uid == uid;
    }

    function isAdmin() {
      return isSignedIn()
        && exists(/databases/$(database)/documents/users/$(request.auth.uid))
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    function isSessionParticipant() {
      return isSignedIn() && request.auth.uid in resource.data.users;
    }

    match /users/{userId} {
      allow read: if isOwner(userId);
      allow create: if isOwner(userId)
        && request.resource.data.uid == userId
        && request.resource.data.role == 'user';
      allow update: if isOwner(userId)
        && !request.resource.data.diff(resource.data)
            .affectedKeys().hasAny(['role', 'uid']);
    }

    match /waiting_pool/{userId} {
      allow read, delete: if isOwner(userId);
      allow create: if isOwner(userId)
        && request.resource.data.createdAt == request.time
        && request.resource.data.status == 'waiting';
      // clients can only touch updatedAt — Cloud Functions set status='matched'
      allow update: if isOwner(userId)
        && request.resource.data.diff(resource.data)
            .affectedKeys().hasOnly(['updatedAt'])
        && request.resource.data.updatedAt == request.time;
    }

    match /active_sessions/{sessionId} {
      allow read: if isSessionParticipant();
      allow write: if false;
    }

    match /reports/{reportId} {
      allow create: if isSignedIn()
        && request.resource.data.keys().hasOnly(['reporterId', 'reportedUserId', 'sessionId', 'reason', 'description', 'chatLog', 'createdAt', 'status'])
        && request.resource.data.keys().hasAll(['reporterId', 'reportedUserId', 'sessionId', 'reason', 'chatLog', 'createdAt', 'status'])
        && request.resource.data.reporterId == request.auth.uid
        && request.resource.data.status == 'pending'
        && request.resource.data.createdAt == request.time;
      allow read, update, delete: if isAdmin();
    }
  }
}
```

### Realtime Database — `database.rules.json` (deployed ✓)

**URL:** `https://cozytalk-5d984-default-rtdb.asia-southeast1.firebasedatabase.app`

All nodes are participant-scoped — access gates on `sessions/{roomId}/users/{uid}` membership. See `database.rules.json` for full rules.

| Node | Value | Notes |
|---|---|---|
| `sessions/{roomId}/users/{uid}` | `true` | Written by Cloud Function; auth anchor for all other nodes |
| `messages/{roomId}/{messageId}` | `{ senderId, text, timestamp }` | Append-only, max 1000 chars; destroyed on session end |
| `typing/{roomId}/{uid}` | `true` | Set while typing, deleted when done |
| `presence/{roomId}/{uid}` | `true` | Set on connect; `onDisconnect().remove()` handles drops |

### Firestore Indexes — `firestore.indexes.json` (deployed ✓)

| Collection | Fields | Query |
|---|---|---|
| `waiting_pool` | `status ASC, createdAt ASC` | Matchmaking: oldest waiting user |
| `reports` | `status ASC, createdAt DESC` | Admin dashboard: pending reports by time |

### Feature Flags — Firebase Remote Config

`icebreakers_enabled` (boolean, default `true`) — gates the Moods/Drinks SVG sticker panel.
Rollback: set to `false` in Remote Config console; clients pick it up within 12 hours.

---

## Database Schema (Finalized)

### `users/{uid}` (Firestore)
| Field | Type | Notes |
|---|---|---|
| `uid` | string | matches auth UID |
| `displayName` | string? | null for anonymous |
| `photoUrl` | string? | null for anonymous |
| `email` | string? | null for anonymous |
| `role` | string | `'user'` \| `'admin'` |
| `createdAt` | timestamp | |
| `lastSeen` | timestamp | |

Anonymous users get a minimal doc on first sign-in (`uid`, `role: 'user'`, `createdAt`, `lastSeen`) to prevent `isAdmin()` from throwing.

### `waiting_pool/{uid}` (Firestore)
| Field | Type | Notes |
|---|---|---|
| `createdAt` | timestamp | must be `request.time` (rules enforced) |
| `status` | string | `'waiting'` on create (rules enforced) |
| `updatedAt` | timestamp | client-updatable only; Cloud Function sets `status` |

### `active_sessions/{sessionId}` (Firestore)
| Field | Type | Notes |
|---|---|---|
| `users` | string[] | `[uid1, uid2]` — used by Firestore rules |
| `roomId` | string | equals `sessionId` (same ID in RTDB) |
| `createdAt` | timestamp | |
| `endedAt` | timestamp? | set on session end |
| `status` | string | `'active'` \| `'ended'` |

`sessionId === roomId` — one ID links Firestore metadata to RTDB messages. Cloud Function is the only writer.

### `reports/{reportId}` (Firestore)
| Field | Type | Notes |
|---|---|---|
| `reporterId` | string | UID of reporting user |
| `reportedUserId` | string | UID of reported user |
| `sessionId` | string | session where it occurred |
| `chatLog` | map[] | snapshot of messages retained for review |
| `reason` | string | |
| `description` | string? | |
| `createdAt` | timestamp | |
| `status` | string | `'pending'` \| `'reviewed'` \| `'dismissed'` |

### `messages/{roomId}/{messageId}` (RTDB)
| Field | Type |
|---|---|
| `senderId` | string |
| `text` | string |
| `timestamp` | number (ms) |

Destroyed by Cloud Function on session end. Snapshot saved to `reports.chatLog` if reported.

### Local Cache (Drift)

| Table | Columns | Purpose |
|---|---|---|
| `cached_users` | `uid, displayName, photoUrl, email, role, lastSeen` | Current user's own profile — shown while offline |

Profile data is the only thing worth caching — live chat is inherently online-only.

---

## Development Phases (WBS)

| Phase | Work | Status |
|---|---|---|
| **1.0 Frontend & UI** | UI/UX design, Auth screens, Waiting screen, Chat Room UI (bubbles, typing, SVGs, Skip) | Auth screens done; remaining screens not yet built |
| **2.0 Backend & Matchmaking** | Matchmaking Cloud Function (race-condition safe), RTDB messaging, session cleanup/lifecycle, word censor, reporting | Not started |
| **3.0 Logic & Integration** | Session state machine (Idle→Searching→Matched→Disconnected), network drop detection, offline alerts, biometric/passkey auth | Not started |
| **4.0 Testing & Management** | Concurrency/race condition tests, cross-platform UI tests (Android + Web), accessibility sweeps, performance profiling | Not started |

---

## Quality Gates (Definition of Done)

| Gate | Requirement |
|---|---|
| **Correctness** | >80% unit test coverage for domain layer; widget tests for all screens; integration tests on Android + Web |
| **Security** | Zero High/Critical vulnerabilities; secret scan clean; no plaintext secrets |
| **Accessibility** | WCAG 2.2 AA on all screens (semantic labels, contrast, dynamic type) |
| **Performance** | No unbounded ListViews; SVGs cached/compressed; no jank on message scroll |

---

## The Do-Not-Do List

| ❌ Never | Reason |
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
├── apps/mobile/                      ← Flutter app (Android + Web)
│   ├── lib/
│   │   ├── main.dart                 ← Firebase init, emulator setup, _AuthRouter
│   │   └── features/
│   │       ├── hello/                ← proof-of-concept (template)
│   │       └── auth/                 ← authentication feature (complete)
│   │           ├── domain/
│   │           │   ├── entities/auth_user.dart
│   │           │   ├── repositories/auth_repository.dart
│   │           │   └── usecases/     ← SignUp, SignIn, SignOut, SignInAnonymously, SignInWithGoogle
│   │           ├── data/
│   │           │   ├── models/auth_user_model.dart  (@freezed)
│   │           │   ├── datasources/auth_datasource.dart
│   │           │   └── repositories/auth_repository_impl.dart
│   │           └── presentation/
│   │               ├── providers/auth_provider.dart  ← AuthState, AuthNotifier, DI
│   │               └── screens/      ← LoginScreen, SignupScreen
│   ├── test/widget_test.dart
│   └── .env.example                  ← committed; USE_EMULATOR=true by default
├── functions/src/index.ts            ← helloWorld Cloud Function
├── firestore.rules                   ← deployed Firestore security rules
├── database.rules.json               ← deployed RTDB security rules
├── firestore.indexes.json            ← Firestore composite indexes
├── firebase.json                     ← Firebase deploy config (predeploy: npm --prefix functions)
├── .gitattributes                    ← enforces LF line endings repo-wide
├── .claude/agents/                   ← specialized agent definitions
├── CLAUDE.md                         ← auto-loaded by Claude Code every session
└── PROJECT_CONTEXT.md                ← this file
```
