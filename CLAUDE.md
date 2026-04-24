# CozyTalk — Claude Code Project Guide

## What is this project?

CozyTalk is a **stranger chat app** (anonymous 1-on-1 matching, like Omegle). Users join a waiting pool, a Cloud Function matches two of them, and they chat via Firebase Realtime Database. See `PROJECT_CONTEXT.md` for full detail.

**Stack:** Flutter + Riverpod + Firebase (Auth, Firestore, RTDB, Functions) + TypeScript Cloud Functions.

---

## Monorepo Layout

```
apps/mobile/      ← Flutter app
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
flutter run                                                  # run app (uses .env)
flutter test                                                 # run tests
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

### Fresh clone setup
```bash
cp apps/mobile/.env.example apps/mobile/.env
# Edit .env: USE_EMULATOR=true for emulator, false for prod
```

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

All data-layer models use `@freezed`:
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
| Auth providers | Anonymous, Google, Email/Password (no passwordless) |

Emulator: `USE_EMULATOR=true` in `.env`. Functions emulator runs on `127.0.0.1:5001`.

---

## Firestore Collections

| Collection | Purpose |
|---|---|
| `users/{uid}` | User profile. Has `role` field (`user` \| `admin`). |
| `waiting_pool/{uid}` | Matchmaking queue. Fields: `createdAt`, `status`, `updatedAt`. |
| `active_sessions/{sessionId}` | Active chat. Has `users: [uid1, uid2]`. Write-locked to Cloud Functions only. |
| `reports/{reportId}` | Moderation reports. Admin-only read. |

Realtime DB: `messages/{roomId}/{messageId}` — chat messages.

Schema not yet finalized — see `PROJECT_CONTEXT.md` section "Pending Task: Database Schema Design".

---

## Code Conventions

- **No comments explaining what code does.** Only comment non-obvious WHY (workarounds, constraints, invariants).
- **Freezed `copyWith` sentinel pattern** — nullable fields must use `_sentinel` so callers can explicitly pass `null` to clear them. Never use `??` for clearable fields.
- **`Map` from Firebase** — always normalize via `Map<String, dynamic>.from(data as Map)` before `fromJson`. Never check `data is! Map<String, dynamic>` directly.
- **Loading guards** — check `isLoading` at the top of every submit handler before proceeding.
- **Test fakes** — `_FakeXxxNotifier` must track invocations (`callCount`) so tests assert behavior, not just rendered UI.

---

## Testing

- Widget tests: `apps/mobile/test/`
- Use `_FakeXxxNotifier extends XxxNotifier` + `overrideWith(() => fake)`
- No real Firebase in tests
- Run: `cd apps/mobile && flutter test`

---

## Environment Config

| File | Committed | Purpose |
|---|---|---|
| `.env.example` | Yes | Safe defaults (`USE_EMULATOR=false`) |
| `.env` | No (gitignored) | Local overrides |

App tries `.env` first; falls back to `.env.example` with a console warning. Both listed in `pubspec.yaml` assets. Never bundle real secrets — use `--dart-define-from-file` for those.
