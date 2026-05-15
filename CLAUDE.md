# CozyTalk — Claude Code Project Guide

## Pull Requests

Always use the template at [`.github/pull_request_template.md`](.github/pull_request_template.md) when creating PRs in this repo. Read the file first, then fill every section — do not skip or delete sections, use `N/A` where not applicable. Pass the body via heredoc to `gh pr create` to preserve formatting.

---

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

flutter pub get                    # install deps
dart run build_runner build        # regenerate Freezed + Riverpod code
flutter run                        # run on Android
flutter run -d chrome              # run on Web
flutter test                       # run tests
flutter build apk                  # build Android
flutter build web                  # build Web
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
Edit [`apps/mobile/.env.example`](apps/mobile/.env.example) — set `USE_EMULATOR=true` to point at the local emulator.

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

1. Copy the [`features/hello/`](apps/mobile/lib/features/hello/) folder as a template.
2. Rename every class/file: `Hello` → `YourFeature`.
3. Run `dart run build_runner build`.
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

Every feature's `presentation/providers/<feature>_provider.dart` does two things. See [`features/hello/presentation/providers/hello_provider.dart`](apps/mobile/lib/features/hello/presentation/providers/hello_provider.dart) as the canonical example.

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

All data-layer models use `@freezed`. Never hand-roll `toJson`/`fromJson`. See [`features/hello/data/models/`](apps/mobile/lib/features/hello/data/models/) for a working example.

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
| `waiting_pool/{uid}` | Matchmaking queue. Fields: `createdAt`, `status`, `updatedAt`, `mode`, `roomId?`. |
| `rooms/{roomId}` | All active/padding/expired rooms (1v1 + group). 5-char alphanumeric ID. Write-locked to Cloud Functions only except `isLocked` on custom rooms. |
| `active_sessions/{sessionId}` | **Legacy proto-sessions only.** New rooms use `rooms/{roomId}`. |
| `reports/{reportId}` | Moderation reports. Admin-only read. Chat log retained here if reported. |

Realtime DB: `rooms/{roomId}/members/{uid}` — CF-written membership anchor; `typing/{roomId}/{uid}`, `presence/{roomId}/{uid}` for real-time state.

See [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) for full schema and security rules.

---

## Matchmaking Feature (`features/matchmaking/`)

The `matchmaking` feature is fully implemented as the **third reference implementation** (alongside `hello` and `auth`). See [`features/matchmaking/`](apps/mobile/lib/features/matchmaking/) and [`functions/src/matchmaking/`](functions/src/matchmaking/).

**Cloud Functions (10 total):**
`joinGroupRoom`, `createCustomRoom`, `joinRoomById`, `leaveRoom`, `join1v1Pool`, `cancel1v1Pool`, `match1v1Users` (Firestore trigger), `expireRooms` (cron `*/2 * * * *`), `setRoomLock`, and `_utils` (shared helpers).

**Flutter feature:** full Clean Architecture at `features/matchmaking/`. Backend test entry point: `HelloScreen` → "Test Matchmaking" button (`_useMainUI = false`).

**Key design decisions:**
- `rooms/{roomId}` is the unified collection for all new rooms; 5-char alphanumeric ID is atomically claimed via `create()` with retry
- Slot reservation uses Firestore transactions; expiry uses a scheduled function that re-checks `memberCount == 0` before deleting
- `isLocked` lives in Firestore (queryable for matchmaking); participants update it directly via security rules (custom rooms only)

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

## Code Style

All rules below are enforced by CI. Do not write code that needs a `// ignore:` suppression to pass.

**Dart** — style owned by `dart format`, rules by `flutter_lints`:
- Always use `{}` on `if`/`for`/`while` bodies (`curly_braces_in_flow_control_structures`)
- Single quotes for strings; trailing commas on multi-line arg lists
- No `print()` — use structured logging (`avoid_print` is active)

**TypeScript** — style owned by Prettier ([`functions/.prettierrc`](functions/.prettierrc)), logic by ESLint:
- Double quotes, 2-space indent, trailing commas everywhere, semicolons required, no bracket spacing (`{foo: bar}`)
- Every `function` declaration (including `_`-prefixed helpers) needs a JSDoc block with `@param` + `@return`; `const` arrow functions are exempt
- No implicit `any`; explicit types required

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
| Architect | [`.claude/agents/architect.md`](.claude/agents/architect.md) | System design, schema, cross-cutting decisions |
| Flutter Engineer | [`.claude/agents/flutter-engineer.md`](.claude/agents/flutter-engineer.md) | Feature implementation, UI, tests |
| QA Engineer | [`.claude/agents/qa-engineer.md`](.claude/agents/qa-engineer.md) | Test strategy, quality gates |
| Security Reviewer | [`.claude/agents/security-reviewer.md`](.claude/agents/security-reviewer.md) | Auth, rules, secrets, compliance |

**Rules:**
- For any complex task, output a step-by-step plan for approval before writing code.
- The agent that writes code must NOT be the agent that reviews it.
- Structured handoffs: specify `@agent` + what they should do + what inputs they receive.

---

## Testing

Run: `cd apps/mobile && flutter test`

Test files mirror source structure under `test/features/<feature>/domain/`, `data/`, `presentation/`. See [`test/features/hello/`](apps/mobile/test/features/hello/) and [`test/features/auth/`](apps/mobile/test/features/auth/) for reference.

**When adding a feature, write all of these:**

| Layer | What to test |
|---|---|
| `domain/entities/` | Construction, optional fields default to null |
| `domain/usecases/` | Args forwarded correctly, result returned, exception propagates |
| `data/models/` | `fromJson` with all fields, with nulls, with extra unknown keys; `toEntity()` maps correctly |
| `data/repositories/` | Call counts, arg forwarding, model→entity conversion, exception propagation; stream repos use `Stream.value(...)` |
| `presentation/providers/` | `State.copyWith` preserves fields, sets nullables, **clears nullables with explicit `null`** (sentinel guard) |
| `presentation/screens/` | Renders key widgets, validation errors, valid submit calls notifier, error/loading states |

**Fake patterns:**

```dart
// Use case test — inline and file-private when the interface is only used in one file
class _FakeMyRepository implements MyRepository {
  String? lastArg; MyEntity? returnValue; Exception? error;
  @override Future<MyEntity> doThing(String arg) async {
    lastArg = arg; if (error != null) throw error!; return returnValue!;
  }
  @override Future<void> other() => throw UnimplementedError();
}

// When the same interface is tested across 3+ files, extract to shared_fakes.dart
// in the same domain/ directory (public name, no underscore).
// See: test/features/auth/domain/shared_fakes.dart (FakeAuthRepository)
//      test/features/chat/domain/shared_fakes.dart  (FakeChatRepository)

// Screen widget test — extend Notifier, override build() to avoid Firebase
class _FakeMyNotifier extends MyNotifier {
  final MyState _initial; int callCount = 0;
  _FakeMyNotifier({MyState initial = const MyState()}) : _initial = initial;
  @override MyState build() => _initial;  // never call super.build()
  @override Future<void> doThing() async => callCount++;
}
// Wrap: ProviderScope(overrides: [myProvider.overrideWith(() => fake)], child: ...)
```

**Hard rules:**
- No Firebase SDK in any test file
- No mockito — hand-written fakes only
- `_FakeXxxNotifier` must override `build()` — default `build()` touches Firebase and throws
- Domain tests: no `flutter` or Firebase imports
- Fresh fake in each `setUp` — never share mutable fakes across tests
- Enum tests: one `containsAll` + length assertion, not one test per value

---

## Auth Feature (`features/auth/`)

The `auth` feature is the **second reference implementation** (alongside `hello`). See [`features/auth/`](apps/mobile/lib/features/auth/).

**Use cases:** `SignUp`, `SignIn`, `SignOut`, `SignInAnonymously`, `SignInWithGoogle`

**`AuthStatus` enum:** `idle | loading | authenticated | unauthenticated` — never infer auth state from nullable fields.

**`AuthState` fields:** `status`, `user` (`AuthUser?`), `error` (`String?`) — both nullable fields use the sentinel pattern.

**`AuthNotifier.build()`** subscribes to `authRepository.watchAuthState()` (wraps `FirebaseAuth.authStateChanges()`). The stream listener skips state updates while `status == loading` to avoid races with in-flight sign-in actions.

**Platform split in `AuthDatasourceImpl.signInWithGoogle()`:** web uses `signInWithPopup(GoogleAuthProvider())`, native uses `GoogleSignIn.instance.authenticate()` + `GoogleAuthProvider.credential(idToken:)`. Checked via `kIsWeb`.

**Firestore user doc creation:** written by the datasource on `signUp` and on first-time Google sign-in (`additionalUserInfo.isNewUser == true`). Anonymous users do not get a Firestore doc.

**`_AuthRouter`** (in [`main.dart`](apps/mobile/lib/main.dart)) watches `authNotifierProvider` and routes: `authenticated` → `HelloScreen`, `idle` → loading spinner, anything else → `LoginScreen`.

---

## Environment Config

[`main.dart`](apps/mobile/lib/main.dart) reads `USE_EMULATOR` via `bool.fromEnvironment` (compile-time constant, default `true`). Set it in [`.env.example`](apps/mobile/.env.example) or pass `--dart-define=USE_EMULATOR=false` for production builds. Never put real secrets here. Use `--dart-define-from-file` for secrets.

---

## AI Behavior Rules (Claude Code)

These rules apply to **all contributors** using Claude Code in this repo.

### Authorship

Write all output — code, comments, commit messages, PR descriptions, docs — as a human developer would. No AI signatures, no "generated with" footers, no co-author tags, no attribution lines of any kind. This applies everywhere: source files, git commits, pull requests, markdown files, config files, changelogs.

Commit messages must read like a developer wrote them: concise, past-tense or imperative, focused on what changed and why. No boilerplate, no meta-commentary about the AI tool that produced them.

### Lock Files

Never manually edit lock files (`pubspec.lock`, `package-lock.json`, `yarn.lock`, etc.).

If a lock file needs updating:
1. Edit the manifest (`pubspec.yaml`, `package.json`, etc.)
2. Run the package manager to regenerate it:
   - Dart/Flutter: `flutter pub get`
   - Node: `npm install`

The lock file is always a derived artifact of the manifest. Editing it directly creates drift that CI will reject.
