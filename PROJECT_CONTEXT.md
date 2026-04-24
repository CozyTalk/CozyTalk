# CozyTalk — Project Context

> Full project reference. Read before answering any questions about this project.

---

## What is CozyTalk?

CozyTalk is a **cross-platform stranger chat app** targeting **Android and Web**. Users are matched anonymously with a random stranger for a one-on-one text conversation. The goal is to provide a safe, low-pressure space for authentic interactions — combating social media performance fatigue.

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
- Deployed: `helloWorld` (echo, proof-of-concept — to be replaced)
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
Landing (anon auth)
    ↓
Waiting / Searching  ←──────────────────────────┐
    ↓  [matched by Cloud Function]               │
Chat Room                                        │
    ├── [Skip / Next Person] ────────────────────┘
    ├── [Leave] → session destroyed
    └── [Report] → chat log retained, session destroyed
```

### Chat Room UI Components
- Message bubbles (sent / received)
- Typing indicator
- **Moods / Drinks SVG icebreakers** — tappable stickers to break the ice
- **Skip / Next Person** button (prominent — core UX)
- Connection status indicator

### Session State Machine
```
Idle → Searching → Matched/Chatting → Disconnected
                                    ↘ (Skip) → Searching
```
The chat Notifier must model all four states explicitly as an enum, never infer them from nullable fields.

---

## What Is Already Built

### `hello` feature (proof-of-concept, complete)
End-to-end clean arch example:
- `HelloScreen` → `HelloNotifier` → `CallHello` usecase → `HelloRepositoryImpl` → `HelloDatasourceImpl` → `helloWorld` Cloud Function → response flows back

This is the **template** for all future features.

### App bootstrap (`lib/main.dart`)
- Loads `.env` (falls back to `.env.example` with a warning)
- Initialises Firebase
- Points Functions at local emulator if `USE_EMULATOR=true`
- Signs in anonymously if no current user
- Wraps in `ProviderScope`

### Tests (`test/widget_test.dart`)
Three widget tests for `HelloScreen` using `_FakeHelloNotifier` with `callCount`.

---

## Firebase Configuration

### Authentication — enabled providers
| Provider | Notes |
|---|---|
| **Anonymous** | On. Baseline auth. A few test users exist. |
| **Google Sign-In** | On. Not yet wired in Flutter. |
| **Email / Password** | On. Passwordless OFF. Not yet wired in Flutter. |
| **Biometric / Passkey** | Planned — Android Keystore + WebAuthn for secure session resumption. Not yet implemented. |

### Firestore Security Rules (deployed)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAdmin() {
      return request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    // ⚠️ isAdmin() will throw if the users doc doesn't exist (e.g. anonymous user)
    // Needs: exists(...) guard before the get()

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
      allow write: if false;  // Cloud Functions only
    }

    match /reports/{reportId} {
      allow create: if request.auth != null;
      allow read, update, delete: if isAdmin();
    }
  }
}
```

**Current state:** No collections exist yet — rules deployed, database empty.

### Realtime Database Rules (deployed)
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

**⚠️ RTDB rules are too permissive** — any authed user can read/write any room. Must be tightened before production so only session participants can access their room.

---

## Pending Task: Database Schema Design

The team needs to define the exact document shapes. Key open questions:

### `users/{uid}`
- Fields: `uid`, `displayName`, `photoUrl`, `email`, `role` (`user` | `admin`), `createdAt`, `lastSeen`
- Do anonymous users get a doc? (Without one, `isAdmin()` throws on their requests)
- Any user preferences? (language, chat topics)

### `waiting_pool/{uid}`
- Fields: `createdAt` (server timestamp — rules require it), `status` (`waiting` | `matched`?), `updatedAt`
- Any matching preferences? (language filter)
- Does Cloud Function write matched partner UID here, or just delete the doc and create a session?

### `active_sessions/{sessionId}`
- Fields: `users: [uid1, uid2]` (required by rules), `roomId` (RTDB key), `createdAt`, `endedAt`, `status` (`active` | `ended`)
- Should `sessionId === roomId`? Simplest if yes.
- Session cleanup: destroyed by Cloud Function on leave/skip. Chat log retained only if reported.

### `reports/{reportId}`
- Fields: `reporterId`, `reportedUserId`, `sessionId`, `chatLog` (snapshot retained here), `reason`, `description`, `createdAt`, `status` (`pending` | `reviewed` | `dismissed`)

### `messages/$room_id` (RTDB)
- `$messageId` (push key): `{ senderId, text, timestamp }`
- Destroyed immediately on session end (Cloud Function)
- Retained as snapshot in `reports` doc if user is reported before destruction

### Key design decisions
1. `sessionId === roomId` — one ID links Firestore session to RTDB messages
2. Cloud Function generates `sessionId` (only writer to `active_sessions`)
3. Anonymous users need a minimal `users` doc created on first sign-in to prevent `isAdmin()` from throwing
4. RTDB rules tightening: mirror `users` array into RTDB session node, or use Custom Claims

---

## Development Phases (WBS)

| Phase | Work |
|---|---|
| **1.0 Frontend & UI** | Flutter project setup, UI/UX design (Moods/Drinks icebreakers), Landing/Auth UI, Waiting screen, Chat Room UI |
| **2.0 Backend & Matchmaking** | Finalize NoSQL schema, matchmaking Cloud Function (race-condition safe), Realtime messaging API, session cleanup/lifecycle, word censor, reporting feature |
| **3.0 Logic & Integration** | Complex UI state machine (Idle→Searching→Matched→Disconnected), network drop detection, offline alerts, biometric/passkey auth |
| **4.0 Testing & Management** | Concurrency/race condition tests, cross-platform UI tests (Android + Web), accessibility sweeps, performance profiling |

---

## Quality Gates (Definition of Done)

| Gate | Requirement |
|---|---|
| **Correctness** | >80% unit test coverage for domain layer; widget tests for all screens; integration tests on Android + Web |
| **Security** | Zero High/Critical vulnerabilities; secret scan clean; no plaintext secrets anywhere |
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
| Store secrets in SharedPreferences, Drift, Hive, or assets | Extractable |
| Edit `*.g.dart` / `*.freezed.dart` | Run build_runner instead |
| Unbounded ListView with children for dynamic data | Performance |

---

## Repository Layout

```
CozyTalk/
├── apps/mobile/               ← Flutter app (Android + Web)
│   ├── lib/
│   │   ├── main.dart
│   │   └── features/
│   │       └── hello/         ← reference implementation (template)
│   ├── test/widget_test.dart
│   ├── .env.example           ← committed, USE_EMULATOR=false
│   └── .env                   ← gitignored
├── functions/src/index.ts     ← helloWorld Cloud Function
├── .claude/agents/            ← specialized agent definitions
├── CLAUDE.md                  ← auto-loaded by Claude Code every session
├── PROJECT_CONTEXT.md         ← this file
└── firebase.json
```
