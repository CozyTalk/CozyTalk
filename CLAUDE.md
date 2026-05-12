# CozyTalk — Claude Code Project Guide

## What is this project?

CozyTalk is a **cross-platform stranger chat app** (anonymous 1-on-1 matching, like Omegle) targeting **Android and Web**. Users join a waiting pool, a Cloud Function matches two of them, and they chat via Firebase Realtime Database. The core purpose is to provide a low-pressure, authentic interaction space to combat social media performance fatigue.

**Stack:** Flutter (Android + Web) + Riverpod + Firebase (Auth, Firestore, RTDB, Functions, Crashlytics) + TypeScript Cloud Functions.

---

## Core Principle: Privacy by Design

**Chat history is ephemeral.** When a user leaves a room or presses Skip:
- The RTDB `messages/{roomId}` data is **immediately destroyed** by a Cloud Function.
- The `active_sessions` Firestore doc is deleted.

**The only exception:** if a report is filed, the Cloud Function retains the chat log for moderation review before destroying it.

This is a hard product requirement — never suggest persisting chat messages outside the report flow.

---

## Monorepo Layout

```
apps/mobile/      ← Flutter app (Android + Web)
functions/        ← Firebase Cloud Functions (TypeScript)
packages/         ← shared packages (reserved, empty)
tools/            ← CLI tools (reserved, empty)
```

---

## Essential Commands

### Flutter app
```bash
cd apps/mobile

flutter pub get                                              # install deps
dart run build_runner build --delete-conflicting-outputs    # regenerate Freezed + Riverpod code
flutter run                                                  # run on Android
flutter run -d chrome                                        # run on Web
flutter test                                                 # run tests
flutter build apk                                            # build Android
flutter build web                                            # build Web
```

### Cloud Functions
```bash
cd functions

npm install          # install deps
npm run build        # compile TypeScript
npm run lint         # lint
npm run serve        # start local emulator (port 5001)
npm run deploy       # deploy to Firebase (lint + build run first via predeploy hooks)
```

### Dev scripts
Run `./setup.sh` (Linux/macOS) or `.\setup.ps1` (Windows) to install all dependencies and run code generation in one step.

Run `./dev.sh` (Linux/macOS) or `.\dev.ps1` (Windows) to start emulators and Flutter together. Both accept `--web` and `--prod` flags.

### Fresh clone setup
Edit `apps/mobile/.env.example` — set `USE_EMULATOR=true` to point at the local emulator.

---

## Architecture: Clean Architecture (feature-first)

Every feature lives under `apps/mobile/lib/features/<feature>/` with three mandatory layers:

```
features/<feature>/
├── domain/             ← PURE DART. No Flutter, no Firebase, no packages.
│   ├── entities/       ← plain data types (no JSON, no serialization)
│   ├── repositories/   ← abstract interfaces (contracts only)
│   └── usecases/       ← one class per operation, depends on repo interface
├── data/               ← Firebase / HTTP / serialization
│   ├── models/         ← @freezed DTOs with fromJson + toEntity()
│   ├── datasources/    ← ONLY place that touches Firebase SDK directly
│   └── repositories/   ← implements domain interface, converts DTO→Entity
└── presentation/       ← UI
    ├── providers/       ← Riverpod DI wiring + Notifier + State class
    └── screens/         ← ConsumerStatefulWidget pages
```

**Import rule:** domain imports nothing else. Data imports domain. Presentation imports domain. Nothing imports presentation.

### Adding a new feature

1. Copy the `hello` feature folder as a template.
2. Rename every class/file: `Hello` → `YourFeature`.
3. Run `dart run build_runner build --delete-conflicting-outputs`.
4. Never put Firebase SDK calls outside `datasources/`.
5. Never put business logic inside a `Screen` or `Notifier` — that belongs in a UseCase.

---

## App Screens & Session States

**Screens (in flow order):**
1. **Login / Auth** — entry point; email+password, Google Sign-In, or anonymous (Continue as Guest)
2. **Sign Up** — email+password registration; navigated to from Login
3. **Waiting / Searching** — user in `waiting_pool`, spinner, cancel option
4. **Chat Room** — message bubbles, typing indicator, Moods/Drinks SVG icebreakers, prominent **Skip / Next Person** button
5. **Disconnected** — shown when partner leaves or connection drops

**Session state machine:**
```
Idle → Searching → Matched/Chatting → Disconnected
                                    ↘ (Skip) → Searching
```

The Notifier for the chat feature must model all four states explicitly — never infer state from nullable fields.

---

## State Management Pattern (Riverpod)

Every feature's `presentation/providers/<feature>_provider.dart` does two things:

**1. DI wiring** — builds the dependency chain bottom-up:
```dart
final _datasourceProvider = Provider((ref) => FooDatasourceImpl(FirebaseFirestore.instance));
final _repositoryProvider  = Provider((ref) => FooRepositoryImpl(ref.watch(_datasourceProvider)));
final _usecaseProvider     = Provider((ref) => CallFoo(ref.watch(_repositoryProvider)));
```

**2. State + actions:**
```dart
class FooState {
  final SomeEntity? result;
  final bool isLoading;
  final String? error;
  // copyWith MUST use sentinel pattern for nullable fields — see HelloState
}

class FooNotifier extends Notifier<FooState> {
  @override FooState build() => const FooState();
  Future<void> doSomething() async { ... }
}
```

**In screens:** `ref.watch(fooNotifierProvider)` for state, `ref.read(fooNotifierProvider.notifier)` for actions.

---

## Models: Freezed + JSON Serializable

All data-layer models use `@freezed`. Never hand-roll `toJson`/`fromJson`.

```dart
@freezed
abstract class FooModel with _$FooModel {
  const factory FooModel({ required String id }) = _FooModel;
  factory FooModel.fromJson(Map<String, dynamic> json) => _$FooModelFromJson(json);
}

extension FooModelX on FooModel {
  FooEntity toEntity() => FooEntity(id: id);
}
```

After editing any `@freezed` class or `@riverpod` provider, always run build_runner.

---

## Firebase Project

| Service | Detail |
|---|---|
| Project ID | `cozytalk-5d984` |
| Functions region | `us-central1` |
| Realtime DB URL | `https://cozytalk-5d984-default-rtdb.asia-southeast1.firebasedatabase.app` |
| Auth providers | Anonymous, Google, Email/Password (no passwordless) — all wired in Flutter |
| Observability | Firebase Crashlytics + structured Cloud Function logging |

Emulator ports: Auth `9099`, Functions `5001`, Firestore `8080`, RTDB `9000`. Set `USE_EMULATOR=true` in `.env.example` to enable all four.

---

## Firestore Collections

| Collection | Purpose |
|---|---|
| `users/{uid}` | User profile. Fields: `uid`, `email`, `role` (`user`\|`admin`), `createdAt`, `lastSeen`, `displayName?`, `photoUrl?`. |
| `waiting_pool/{uid}` | Matchmaking queue. Fields: `createdAt`, `status`, `updatedAt`. |
| `active_sessions/{sessionId}` | Active chat. Has `users: [uid1, uid2]`. Write-locked to Cloud Functions only. |
| `reports/{reportId}` | Moderation reports. Admin-only read. Chat log retained here if reported. |

Realtime DB: `messages/{roomId}/{messageId}` — live chat messages (ephemeral, destroyed on session end).

See `PROJECT_CONTEXT.md` for full schema and security rules.

---

## Code Conventions

- **No comments explaining what code does.** Only comment non-obvious WHY (workarounds, constraints, invariants).
- **Freezed `copyWith` sentinel pattern** — nullable fields must use `_sentinel` so callers can explicitly pass `null` to clear them. Never use `??` for clearable fields.
- **`Map` from Firebase** — always normalize via `Map<String, dynamic>.from(data as Map)` before `fromJson`. Never check `data is! Map<String, dynamic>` directly.
- **Loading guards** — check `isLoading` at the top of every submit handler before proceeding.
- **Test fakes** — `_FakeXxxNotifier` must track invocations (`callCount`) so tests assert behavior, not just rendered UI.
- **No unbounded ListViews** — all lists must use `ListView.builder` or `SliverList` with item count. No `children: [...]` for dynamic lists.
- **SVG assets (Moods/Drinks icebreakers)** — must be cached and compressed. Use `flutter_svg` with asset precaching.

---

## The Do-Not-Do List

| ❌ Do NOT | Reason |
|---|---|
| Import Flutter or Firebase into the domain layer | Breaks Clean Architecture — domain must be pure Dart |
| Write matchmaking logic on the client | Race conditions — must be a Cloud Function |
| Persist chat messages | Privacy by Design — destroy immediately on session end |
| Hand-roll `toJson`/`fromJson` | Use Freezed + json_serializable |
| Store API keys or secrets in SharedPreferences, Drift, Hive, or bundled assets | Extractable from APK/IPA |
| Edit generated files (`*.g.dart`, `*.freezed.dart`) | Always run `build_runner` instead |
| Use unbounded `ListView` with `children: [...]` for dynamic data | Performance violation |

---

## Quality Gates (Definition of Done)

| Gate | Requirement |
|---|---|
| **Correctness** | >80% unit test coverage for domain layer; widget tests for all screens; integration tests passing on Android and Web |
| **Security** | Zero High/Critical vulnerabilities; dependency scan clean; no secrets in code |
| **Accessibility** | All screens pass WCAG 2.2 AA (semantic labels, contrast ratio, dynamic type support) |
| **Performance** | No unbounded ListViews; Moods/Drinks SVGs cached and compressed; no jank on message list scroll |

---

## Multi-Agent Workflow

This codebase is developed by specialized agents orchestrated by a lead:

| Agent | File | Responsibility |
|---|---|---|
| Architect | `.claude/agents/architect.md` | System design, schema, cross-cutting decisions |
| Flutter Engineer | `.claude/agents/flutter-engineer.md` | Feature implementation, UI, tests |
| QA Engineer | `.claude/agents/qa-engineer.md` | Test strategy, quality gates |
| Security Reviewer | `.claude/agents/security-reviewer.md` | Auth, rules, secrets, compliance |

**Rules:**
- For any complex task, output a step-by-step plan for approval before writing code.
- The agent that writes code must NOT be the agent that reviews it.
- Structured handoffs: specify `@agent` + what they should do + what inputs they receive.

---

## Testing

- Widget tests: `apps/mobile/test/`
- Use `_FakeXxxNotifier extends XxxNotifier` + `overrideWith(() => fake)`
- No real Firebase in tests
- Run: `cd apps/mobile && flutter test`

---

## Auth Feature (`features/auth/`)

The `auth` feature is fully implemented and is the **second reference implementation** (alongside `hello`).

**Use cases:** `SignUp`, `SignIn`, `SignOut`, `SignInAnonymously`, `SignInWithGoogle`

**`AuthStatus` enum:** `idle | loading | authenticated | unauthenticated` — never infer auth state from nullable fields.

**`AuthState` fields:** `status`, `user` (`AuthUser?`), `error` (`String?`) — both nullable fields use the sentinel pattern.

**`AuthNotifier.build()`** subscribes to `authRepository.watchAuthState()` (wraps `FirebaseAuth.authStateChanges()`). The stream listener skips state updates while `status == loading` to avoid races with in-flight sign-in actions.

**Platform split in `AuthDatasourceImpl.signInWithGoogle()`:** web uses `signInWithPopup(GoogleAuthProvider())`, native uses `GoogleSignIn.instance.authenticate()` + `GoogleAuthProvider.credential(idToken:)`. Checked via `kIsWeb`.

**Firestore user doc creation:** written by the datasource on `signUp` and on first-time Google sign-in (`additionalUserInfo.isNewUser == true`). Anonymous users do not get a Firestore doc.

**`_AuthRouter`** (in `main.dart`) watches `authNotifierProvider` and routes: `authenticated` → `HelloScreen`, `idle` → loading spinner, anything else → `LoginScreen`.

---

## Environment Config

`main.dart` reads `USE_EMULATOR` via `bool.fromEnvironment` (compile-time constant, default `true`). Set it in `.env.example` or pass `--dart-define=USE_EMULATOR=false` for production builds. Never put real secrets here. Use `--dart-define-from-file` for secrets.
