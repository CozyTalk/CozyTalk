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
End-to-end clean arch example: `HelloScreen` → `HelloNotifier` → `CallHello` usecase → `HelloRepositoryImpl` → `HelloDatasourceImpl` → `helloWorld` Cloud Function → response flows back. This is the **template** for all future features.

### App bootstrap (`lib/main.dart`)
Loads `.env.example` (the only bundled asset — `.env` is gitignored and not bundled), initialises Firebase, points Functions at local emulator if `USE_EMULATOR=true`, signs in anonymously, wraps in `ProviderScope`.

### Tests (`test/widget_test.dart`)
Three widget tests for `HelloScreen` using `_FakeHelloNotifier` with `callCount` — all passing.

---

## Firebase Configuration

### Authentication — enabled providers
| Provider | Status |
|---|---|
| **Anonymous** | On. Baseline auth. A few test users exist. |
| **Google Sign-In** | On. Not yet wired in Flutter. |
| **Email / Password** | On. Passwordless OFF. Not yet wired in Flutter. |
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
      allow update: if isOwner(userId)
        && request.resource.data.diff(resource.data)
            .affectedKeys().hasOnly(['status', 'updatedAt'])
        && request.resource.data.updatedAt == request.time
        && request.resource.data.status in ['waiting', 'matched'];
    }

    match /active_sessions/{sessionId} {
      allow read: if isSessionParticipant();
      allow write: if false;
    }

    match /reports/{reportId} {
      allow create: if isSignedIn()
        && request.resource.data.keys().hasOnly(['reporterId', 'reportedUserId', 'sessionId', 'reason', 'description', 'chatLog', 'createdAt', 'status'])
        && request.resource.data.reporterId == request.auth.uid
        && request.resource.data.status == 'pending'
        && request.resource.data.createdAt == request.time;
      allow read, update, delete: if isAdmin();
    }
  }
}
```

### Realtime Database Rules — `database.rules.json` (deployed ✓)

```json
{
  "rules": {
    "sessions": {
      "$room_id": {
        ".read": "auth != null && data.child('users').child(auth.uid).exists()",
        ".write": false
      }
    },
    "messages": {
      "$room_id": {
        ".read": "auth != null && root.child('sessions').child($room_id).child('users').child(auth.uid).exists()",
        ".write": false,
        "$messageId": {
          ".write": "!data.exists() && auth != null && root.child('sessions').child($room_id).child('users').child(auth.uid).exists()",
          ".validate": "newData.hasChildren(['senderId', 'text', 'timestamp']) && newData.child('senderId').val() == auth.uid && newData.child('text').isString() && newData.child('text').val().length > 0 && newData.child('timestamp').isNumber()"
        }
      }
    }
  }
}
```

**URL:** `https://cozytalk-5d984-default-rtdb.asia-southeast1.firebasedatabase.app`

**RTDB node structure:**
- `sessions/{roomId}/users/{uid}: true` — written by Cloud Function at session creation; used to scope message access
- `messages/{roomId}/{pushId}: { senderId, text, timestamp }` — live chat, destroyed on session end

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
| `updatedAt` | timestamp | client can update |

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

---

## Development Phases (WBS)

| Phase | Work |
|---|---|
| **1.0 Frontend & UI** | UI/UX design, Landing/Auth screen, Waiting screen, Chat Room UI (bubbles, typing, SVGs, Skip) |
| **2.0 Backend & Matchmaking** | Matchmaking Cloud Function (race-condition safe), RTDB messaging, session cleanup/lifecycle, word censor, reporting |
| **3.0 Logic & Integration** | Session state machine (Idle→Searching→Matched→Disconnected), network drop detection, offline alerts, biometric/passkey auth |
| **4.0 Testing & Management** | Concurrency/race condition tests, cross-platform UI tests (Android + Web), accessibility sweeps, performance profiling |

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
├── apps/mobile/               ← Flutter app (Android + Web)
│   ├── lib/
│   │   ├── main.dart
│   │   └── features/hello/    ← reference implementation (template)
│   ├── test/widget_test.dart
│   ├── .env.example           ← committed, USE_EMULATOR=false
│   └── .env                   ← gitignored
├── functions/src/index.ts     ← helloWorld Cloud Function
├── firestore.rules            ← deployed Firestore security rules
├── database.rules.json        ← deployed RTDB security rules
├── firestore.indexes.json     ← Firestore composite indexes (empty for now)
├── firebase.json              ← Firebase deploy config
├── .claude/agents/            ← specialized agent definitions
├── CLAUDE.md                  ← auto-loaded by Claude Code every session
└── PROJECT_CONTEXT.md         ← this file
```
