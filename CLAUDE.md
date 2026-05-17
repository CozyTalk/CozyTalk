# CozyTalk — Claude Code Project Guide

> Read fully before every session. Single source of truth for rules, conventions, and standards.
> Deep reference: [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) (schema, rules) · [`MATCHMAKING_CONTEXT_AWARE.md`](MATCHMAKING_CONTEXT_AWARE.md) (interest matching)

---

## 1. Pull Requests

Always use [`.github/pull_request_template.md`](.github/pull_request_template.md). Read it first, fill every section (`N/A` where not applicable), pass the body via heredoc to `gh pr create`.

---

## 2. Project

Anonymous 1-on-1 stranger chat — Flutter (Android + Web) + Firebase.

**Privacy by Design (non-negotiable):** On session end, `chat_rooms/{id}/messages` is destroyed, RTDB presence/typing wiped, `rooms/{id}` tombstoned (`status: expired`). Only `reportSession` CF retains messages for moderation. Never suggest persisting messages outside this flow.

| Concern | Choice |
|---|---|
| Framework | Flutter 3.41+ · Dart 3.x |
| State | Riverpod 2.x + `Notifier` pattern |
| Backend | Firebase Auth, Firestore, RTDB, Cloud Functions v2 (TypeScript) |
| Models | Freezed + json_serializable |
| Navigation | `MaterialApp.routes` + `AppRoutes` constants (`theme/app_routes.dart`) |
| Observability | Firebase Crashlytics + structured CF logging |

Firebase project: `cozytalk-5d984` · RTDB region: `asia-southeast1` · Functions: `us-central1`

---

## 3. Architecture

**Clean Architecture, feature-first.** Three strict layers:

```
features/<feature>/
├── domain/           ← PURE DART. Zero Flutter/Firebase imports.
│   ├── entities/     ← plain data types, no JSON
│   ├── repositories/ ← abstract interfaces only
│   └── usecases/     ← one class per operation
├── data/             ← Firebase/HTTP only
│   ├── models/       ← @freezed DTOs + toEntity()
│   ├── datasources/  ← ONLY place Firebase SDK is called
│   └── repositories/ ← implements domain interface
└── presentation/
    ├── providers/    ← Riverpod DI + Notifier + State
    └── screens/      ← ConsumerStatefulWidget pages
```

**Import rule:** domain imports nothing. Data imports domain. Presentation imports domain. Nothing imports presentation.

**New feature:** copy `features/hello/` → rename → `dart run build_runner build`. Never put Firebase calls outside `datasources/` or business logic inside a Screen/Notifier.

---

## 4. Monorepo & Commands

```
apps/mobile/   ← Flutter app (Android + Web)
functions/     ← Cloud Functions (TypeScript)
tools/         ← check-prod-config.sh (run after every firebase deploy)
```

```bash
# Flutter (from apps/mobile/)
flutter pub get && dart run build_runner build --delete-conflicting-outputs
flutter test && flutter analyze

# Functions (from functions/)
npm install && npm run build && npm test   # npm test requires emulators first
./dev.sh --emulator-only                  # start emulators only

# Dev
./dev.sh [--web|--prod|--emulator-only]   # Linux/macOS
.\dev.ps1 [...]                           # Windows
```

Jest: 93 unit (matchmaking 60, embeddingService 21, chat 12) + 7 Vertex AI integration = 100 total.
Flutter: 347 unit + widget tests.

---

## 5. Features

| Feature | Provider | Key state enum / fields | Status |
|---|---|---|---|
| `hello` | `helloNotifierProvider` | — | Complete · ref impl #1 |
| `auth` | `authNotifierProvider` | `AuthStatus`: idle\|loading\|authenticated\|unauthenticated | Complete · ref impl #2 |
| `matchmaking` | `matchmakingNotifierProvider` | 6 states: idle\|searching\|waiting1v1\|matched\|creating\|error | Complete · ref impl #3 |
| `chat` | `chatNotifierProvider` | `SessionStatus`: idle\|searching\|chatting\|disconnected | Complete |
| `profile` | `profileNotifierProvider` | `successField`: 'username'\|'interest'\|'thoughts' | Complete |
| `avatar` | `avatarDecorationNotifierProvider` | `AvatarDecorationStatus`: idle\|loading\|saving\|error | Complete |
| `home` | — | Thin nav hub, no domain/data | Complete |

**State pattern (all features):** Nullable fields in `FooState.copyWith` use `_sentinel` so callers can explicitly pass `null` to clear them. Never use `??` for clearable fields.

**DI wiring** (in `providers/<feature>_provider.dart` — see `features/hello/` as canonical example):
```dart
final _datasourceProvider = Provider((ref) => FooDatasourceImpl(FirebaseFirestore.instance));
final _repositoryProvider  = Provider((ref) => FooRepositoryImpl(ref.watch(_datasourceProvider)));
final _usecaseProvider     = Provider((ref) => CallFoo(ref.watch(_repositoryProvider)));
```

In screens: `ref.watch(fooNotifierProvider)` for state · `ref.read(fooNotifierProvider.notifier)` for actions.

---

## 6. Key Feature Notes

**Auth:** `AuthNotifier.build()` subscribes to `watchAuthState()`. Stream skips updates while `status == loading`. Google: web uses `signInWithPopup`, native uses `GoogleSignIn.instance.authenticate()`. Firestore user doc written on first sign-in for all auth methods; use `set(merge: true)` for profile updates. `_anonymousName(uid)`: UID-seeded djb2 → adjective+animal (225 combos) in `auth_datasource.dart` — extract if a third caller appears.

**Matchmaking (11 exported CFs):** `cancel1v1Pool` returns `{success: false, reason: "matching_in_progress"}` when status is already `"matching"` — Flutter must handle this. `match1v1Users` deployed to `asia-southeast1` (co-located with RTDB — intentional). Interest matching: Vertex AI `text-multilingual-embedding-002`, 256 dims, cosine threshold 0.65. `onProtoPresenceDeleted.ts` is a disabled stub (`export {};`) — re-enable after proto-session cleanup is fully wired.

**Chat:** `ChatDatasourceImpl` splits on `sessionId.startsWith('proto-')`: proto uses SHA256-derived key + direct Firestore writes; 1v1 calls `sendMessage`/`endSession` CFs. `ChatNotifier.enterSession()` is the entry point. RTDB: `typing/{id}/{uid}`, `presence/{id}/{uid}` (with `onDisconnect().remove()`). `setTyping.ts` is dead code — ignore it.

**Profile:** Validates client-side before calling notifier: username ≤ 20, interest ≤ 200, thoughts ≤ 50. Pre-fills controllers on mount and each successful save via `ref.listen`.

**Avatar:** `FieldValue.delete()` for null fields. Syncs to shared `avatarProvider` via `_syncToSharedProvider()`.

---

## 7. Firestore & RTDB

| Collection | Key fields |
|---|---|
| `users/{uid}` | uid, email, role (user\|admin), displayName?, photoUrl?, hatKey?, moodKey?, interest?, thoughts? |
| `waiting_pool/{uid}` | status, mode, interestText?, interestVector? (256-dim) |
| `rooms/{roomId}` | 5-char ID; mode (1v1\|group), roomType (public\|custom), status (active\|padding\|expired), encryptionKey, paddingUntil? |
| `active_sessions/{id}` | Legacy proto-sessions only — new code uses `rooms/` |
| `chat_rooms/{id}/messages/{id}` | AES-256-GCM: encryptedText, iv, authTag; expiresAt TTL (3 days) |
| `session_keys/{id}` | Archived keys; expiresAt TTL |
| `reports/{id}` | Admin-only read; chatLog is CF-written only (not client-writable) |

RTDB paths: `rooms/{id}/members/{uid}`, `typing/{id}/{uid}`, `presence/{id}/{uid}`, `nameQueue/{id}`, `pool_presence/{uid}`. Full schema + security rules: [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md).

---

## 8. Environment & App Mode

`USE_EMULATOR` — compile-time constant (default `true`). Pass `--dart-define=USE_EMULATOR=false` for production. Emulators: Auth 9099, Functions 5001, Firestore 8080, RTDB 9000.

**`_useMainUI` toggle (main.dart line 35):**
- `false` (default) → dev/test mode: `_AuthRouter` → `LoginScreen` (features/auth) → `HelloScreen`
- `true` → production mode: `HomeScreen` (screens/) + full `AppRoutes` navigation

`_AuthRouter` routes: `authenticated → HelloScreen` · `idle → spinner` · others → `LoginScreen`.

---

## 9. Integration Rules

Integration = wiring `screens/` (the real production frontend) to `features/` (CA backend). `screens/` are not "legacy" — they are the designed production UI. `_useMainUI = true` is the production mode.

**Hard rules:**
- Convert screen: `StatefulWidget` → `ConsumerStatefulWidget`, add `ref.watch/read` calls for real data
- **Zero visual changes during integration** — padding, colors, widget tree, fonts are frozen. Design changes go in a separate PR.
- **Never remove or modify `_useMainUI`** — keeps dev/test path alive for the whole team
- No Firebase SDK calls in screens — only through providers
- No business logic in screens — UseCase/Notifier only
- Auth state: `ref.watch(authNotifierProvider).user`, never `FirebaseAuth.instance.currentUser`
- Data between screens: notifier state machine, not Navigator arguments
- One screen per PR; all existing `flutter test` must pass after integration

**Progression** (dependency order): auth → finding room → choose room type / join by ID → chat → group chat → profile edit → dress up → deferred (notifications, friends, blocked, admin)

**Pattern:**
```dart
// Convert the screen class; widget tree and design stay identical
class FindingRoomScreen extends ConsumerStatefulWidget { ... }
class _FindingRoomScreenState extends ConsumerState<FindingRoomScreen> {
  @override Widget build(BuildContext context) {
    final state = ref.watch(matchmakingNotifierProvider);
    // same widget tree — replace hardcoded values + wire onPressed callbacks
  }
}
```

---

## 10. Testing

| Suite | Command | Requires |
|---|---|---|
| Flutter unit + widget | `cd apps/mobile && flutter test` | Nothing |
| CF Jest | `cd functions && npm test` | Emulators |
| Flutter integration | `flutter test integration_test/matchmaking_advanced_test.dart` | Emulators + device |

Test files mirror source under `test/features/<feature>/`. Reference: `test/features/hello/` and `test/features/auth/`.

**Per-layer requirements:** entities (construction, null defaults) · usecases (args forwarded, return, exception) · models (fromJson all/null/unknown fields, toEntity) · repositories (call counts, stream via `Stream.value`) · providers (`copyWith` preserves/sets/clears nullables) · screens (renders, validation, submit calls notifier, loading/error states).

**Screen fake pattern:**
```dart
class _FakeMyNotifier extends MyNotifier {
  final MyState _initial; int callCount = 0;
  _FakeMyNotifier({MyState initial = const MyState()}) : _initial = initial;
  @override MyState build() => _initial;   // never call super.build()
  @override Future<void> doThing() async => callCount++;
}
// ProviderScope(overrides: [myProvider.overrideWith(() => fake)], child: ...)
```

**Hard rules:** No Firebase SDK in tests · no mockito · `_FakeXxxNotifier` must override `build()` · domain tests: no flutter/Firebase imports · fresh fake per `setUp` · enum tests: one `containsAll` + length check.

---

## 11. Code Conventions & Style

- **No comments explaining what code does.** Comment only non-obvious WHY.
- **`Map` from Firebase:** `Map<String, dynamic>.from(data as Map)` before `fromJson` — never cast directly.
- **Loading guard:** check `isLoading` at the top of every submit handler.
- **Models:** `@freezed` always. Never hand-roll `toJson`/`fromJson`.
- **Lists:** `ListView.builder` or `SliverList`. Never `children: [...]` for dynamic data.

**Dart** (enforced by CI): `{}` on all control flow bodies · single quotes · trailing commas · no `print()`.

**TypeScript** (Prettier + ESLint): double quotes · 2-space indent · trailing commas · semicolons · no bracket spacing. Every `function` declaration needs JSDoc (`@param` + `@return`); `const` arrows exempt.

---

## 12. Agent Workflow

| Agent | Scope | Notes |
|---|---|---|
| Architect | System design, schema, cross-cutting decisions | Plan mode for anything cross-module |
| Flutter Engineer | Dart code — features, UI, tests | Implements; never self-reviews |
| QA Engineer | Test strategy, quality gates, coverage | Reviews independently after impl |
| Security Reviewer | Auth, rules, secrets, compliance | **Read-only — no Edit tool** |

**Plan mode:** required for any task crossing more than one feature module or ~1 hour of work. The agent that writes code must not be the agent that reviews it.

**Task prompt template:**
```
Goal:        <one sentence>
Out of scope: <what NOT to change>
Constraints: <CA boundaries, style, security>
Inputs:      <file paths>
Deliverable: <patch | report | diff>
Done when:   <specific acceptance criteria>
```

**Handoff template:**
```
FROM: @<agent>   TO: @<agent>
TASK: <what to do>
INTERFACE: <relevant paths>
NOTES: <constraints — flag issues, never patch around them>
DONE WHEN: <criteria>
```

---

## 13. Quality Gates

| Gate | Requirement |
|---|---|
| **Correctness** | >80% domain unit test coverage; widget tests on all screens; integration tests passing |
| **Security** | Zero High/Critical findings; dep scan clean; no secrets in code |
| **Accessibility** | WCAG 2.2 AA: semantic labels, contrast ≥ 4.5:1, dynamic type |
| **Performance** | No unbounded ListViews; SVGs cached/compressed; no jank on message list |

---

## 14. Do Not Do

| ❌ | Reason |
|---|---|
| Firebase/Flutter imports in domain | Breaks CA |
| Matchmaking logic on client | Race conditions — must be CF |
| Persist chat messages | Privacy by Design |
| Hand-roll `toJson`/`fromJson` | Use Freezed |
| Secrets in SharedPreferences / Hive / assets | APK-extractable |
| Edit `*.g.dart` / `*.freezed.dart` | Run `build_runner` |
| `ListView(children: [...])` for dynamic data | Performance |
| Remove or modify `_useMainUI` | Breaks dev/test workflow for whole team |
| Visual changes (padding, color, layout) during integration | Separate design PR |
| Firebase SDK directly in a Screen | Through providers only |
| Auth state from `FirebaseAuth.instance.currentUser` in screen | Use `authNotifierProvider` |
| Business logic in Screen or Notifier | UseCase only |
| New packages during integration PR | Architect approval required |
| Edit lock files manually | Run package manager to regenerate |
| `git push --force` to main | Hard block |
| `print()` in production code | Use structured logging |

---

## 15. AI Authorship

Write all output — code, comments, commits, PRs, docs — as a human developer. No AI signatures, "generated with" footers, co-author tags, or attribution lines anywhere. Commit messages: concise, imperative, focused on what changed and why.
