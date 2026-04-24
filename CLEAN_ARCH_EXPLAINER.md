# Flutter Clean Architecture — Explained for Express/Hono/Java Devs

## 1. What is Clean Architecture in one sentence?

It's the same separation-of-concerns pattern you already do in a big Express app — just made **mandatory and enforced by folder structure** instead of left up to you.

---

## 2. The Concept Map (Flutter → TypeScript/Java)

| Flutter Term | TypeScript Equivalent | Java Equivalent | What it actually is |
|---|---|---|---|
| **Entity** | `type` / `interface` / Zod schema | POJO / plain Java class | Pure data shape. No framework, no DB, no HTTP. Just a type. |
| **Model (DTO)** | DTO class with `fromJson()` / `toJson()` | Jackson `@JsonProperty` class | Raw shape of what comes back from Firebase/API. Has serialization logic. |
| **Repository (abstract)** | `interface IHelloRepository` | Java `interface HelloRepository` | A contract. Defines WHAT operations exist. Not HOW. |
| **Repository Impl** | `class HelloRepo implements IHelloRepository` | `class HelloRepoImpl implements HelloRepository` | The actual Firebase/DB/HTTP call. Swappable. |
| **Datasource** | DAL / raw DB client calls | DAO (Data Access Object) | Lowest level. Direct SDK call. No business logic. |
| **UseCase** | A single service method / controller handler | `@Service` method | One unit of business logic. e.g. "call the hello function". |
| **Provider (Riverpod)** | Dependency injection container + `useState` combined | Spring `@Autowired` + React state | Wires deps together AND holds UI-facing state. |
| **Notifier** | `class` with state + actions (like Zustand store) | ViewModel / Controller class | Holds the current UI state, exposes methods to mutate it. |
| **Screen** | React page component / Express route renderer | JSP / Thymeleaf view | The UI. Reads state from provider, renders it. Calls notifier methods on user action. |

---

## 3. The Three Layers

```
┌─────────────────────────────────────────┐
│           PRESENTATION LAYER            │  ← UI lives here (Screen + Provider/Notifier)
│   Knows about: domain only              │
├─────────────────────────────────────────┤
│             DOMAIN LAYER                │  ← Business rules live here (Entity + Repository interface + UseCase)
│   Knows about: nothing else             │  ← Pure Dart. Zero Flutter. Zero Firebase.
├─────────────────────────────────────────┤
│              DATA LAYER                 │  ← External world lives here (Model/DTO + Datasource + Repository Impl)
│   Knows about: domain + Firebase SDK    │
└─────────────────────────────────────────┘
```

**The rule:** arrows only point inward. Data layer can import domain. Domain cannot import data. Presentation can import domain. Nobody imports presentation.

> Java analogy: like the classic Controller → Service → Repository pattern, but domain (Service layer) has zero knowledge of how data is fetched.

---

## 4. The Full File Tree with Plain English

```
apps/mobile/
├── lib/
│   ├── main.dart                                   ← App entry point. Boots Firebase, wires ProviderScope.
│   └── features/
│       └── hello/
│           ├── domain/                             ← DOMAIN LAYER (pure logic, no frameworks)
│           │   ├── entities/
│           │   │   └── hello_message.dart          ← The "type". Just: { message: string }
│           │   ├── repositories/
│           │   │   └── hello_repository.dart       ← The "interface". Defines callHello(msg).
│           │   └── usecases/
│           │       └── call_hello.dart             ← Calls repo.callHello(). One job only.
│           │
│           ├── data/                               ← DATA LAYER (Firebase, HTTP, serialization)
│           │   ├── models/
│           │   │   └── hello_message_model.dart    ← The "DTO". Parses JSON. Converts to Entity.
│           │   ├── datasources/
│           │   │   └── hello_datasource.dart       ← Raw Firebase Functions SDK call lives here.
│           │   └── repositories/
│           │       └── hello_repository_impl.dart  ← Implements the interface. Calls datasource.
│           │
│           └── presentation/                       ← PRESENTATION LAYER (UI + state)
│               ├── providers/
│               │   └── hello_provider.dart         ← DI wiring + state (Notifier + HelloState)
│               └── screens/
│                   └── hello_screen.dart           ← The Flutter UI page.
│
functions/
└── src/
    └── index.ts                                    ← Firebase Cloud Function (the actual server)
```

---

## 5. Every File Explained — Exactly What It Is and Does

---

### `domain/entities/hello_message.dart`
**TypeScript equivalent:** `type HelloMessage = { message: string }`
**Java equivalent:** `class HelloMessage { String message; }`

```dart
class HelloMessage {
  final String message;
  const HelloMessage({required this.message});
}
```

- The purest thing in the codebase.
- No Firebase. No Flutter. No JSON parsing. Just a type.
- Used by: UseCase, Repository interface, Notifier state, and the Screen (to display `state.result.message`).
- Think of it as the "business object" — what the app cares about internally.

---

### `domain/repositories/hello_repository.dart`
**TypeScript equivalent:** `interface IHelloRepository { callHello(msg: string): Promise<HelloMessage> }`
**Java equivalent:** `interface HelloRepository { HelloMessage callHello(String message); }`

```dart
abstract class HelloRepository {
  Future<HelloMessage> callHello(String message);
}
```

- A contract. Defines WHAT operation exists, not HOW it works.
- The domain layer doesn't care if data comes from Firebase, a REST API, or a mock.
- Used by: `CallHello` usecase (accepts this interface as a dependency).
- Implemented by: `HelloRepositoryImpl` in the data layer.

---

### `domain/usecases/call_hello.dart`
**TypeScript equivalent:** A single service function: `async function callHello(msg) { return repo.callHello(msg) }`
**Java equivalent:** `@Service class CallHelloUseCase { public HelloMessage execute(String msg) { ... } }`

```dart
class CallHello {
  final HelloRepository _repository;
  const CallHello(this._repository);
  Future<HelloMessage> call(String message) => _repository.callHello(message);
}
```

- One class, one job: execute the "call hello" business operation.
- It only knows about the repository interface. Not the implementation.
- This is the boundary between "I want to do X" and "here's how X is done".
- Used by: `HelloNotifier` in the presentation layer (`ref.read(_callHelloProvider)(message)`).

---

### `data/models/hello_message_model.dart`
**TypeScript equivalent:** A DTO class with `fromJson()` / `toJson()` — like what you'd write for an Axios response type.
**Java equivalent:** Jackson-annotated DTO class.

```dart
@freezed
abstract class HelloMessageModel with _$HelloMessageModel {
  const factory HelloMessageModel({ required String message }) = _HelloMessageModel;
  factory HelloMessageModel.fromJson(Map<String, dynamic> json) => _$HelloMessageModelFromJson(json);
}

extension HelloMessageModelX on HelloMessageModel {
  HelloMessage toEntity() => HelloMessage(message: message);
}
```

- `@freezed` is a code generator that gives you immutability + `copyWith` + equality for free (like Kotlin data classes or Java Lombok `@Value`).
- `fromJson()` parses the raw Firebase response `{ "message": "..." }`.
- `toEntity()` converts this DTO into the clean domain `HelloMessage` type.
- The model lives in data layer. The entity lives in domain. The `.toEntity()` bridge is intentional — the rest of the app never sees the raw Firebase shape.
- Used by: `HelloDatasourceImpl` (creates it from Firebase response), `HelloRepositoryImpl` (calls `.toEntity()` on it).

---

### `data/datasources/hello_datasource.dart`
**TypeScript equivalent:** The raw `fetch()` or Axios call in your service file — the lowest-level network call.
**Java equivalent:** DAO class with direct JDBC/JPA calls.

```dart
abstract class HelloDatasource {
  Future<HelloMessageModel> callHello(String message);
}

class HelloDatasourceImpl implements HelloDatasource {
  final FirebaseFunctions _functions;
  HelloDatasourceImpl(this._functions);

  @override
  Future<HelloMessageModel> callHello(String message) async {
    final result = await _functions
        .httpsCallable('helloWorld')
        .call({'message': message});
    return HelloMessageModel.fromJson(result.data);
  }
}
```

- Only file allowed to touch the Firebase Functions SDK directly.
- Calls the `helloWorld` Cloud Function with `{ message: "..." }`.
- Parses the raw response into `HelloMessageModel` (DTO).
- Returns a typed model, not raw JSON.
- Used by: `HelloRepositoryImpl`.

---

### `data/repositories/hello_repository_impl.dart`
**TypeScript equivalent:** `class HelloRepository implements IHelloRepository { constructor(private datasource: HelloDatasource) {} }`
**Java equivalent:** `@Repository class HelloRepositoryImpl implements HelloRepository`

```dart
class HelloRepositoryImpl implements HelloRepository {
  final HelloDatasource _datasource;
  HelloRepositoryImpl(this._datasource);

  @override
  Future<HelloMessage> callHello(String message) async {
    final model = await _datasource.callHello(message);
    return model.toEntity();
  }
}
```

- Implements the domain's `HelloRepository` interface.
- Delegates the actual call to `HelloDatasource`.
- Converts the returned `HelloMessageModel` (DTO) → `HelloMessage` (Entity) via `.toEntity()`.
- This is the "adapter" between the dirty data world and the clean domain world.
- Could call multiple datasources here (e.g. check local cache first, then hit network).
- Used by: `CallHello` usecase (via the abstract interface).

---

### `presentation/providers/hello_provider.dart`
**TypeScript equivalent:** A Zustand store + DI container in one file. Or: tRPC context setup + React Query hook.
**Java equivalent:** Spring `@Configuration` class for wiring beans + a ViewModel.

This file does two things:

**Part 1 — Dependency Injection wiring (like a DI container / `container.ts` in tsyringe):**
```dart
final _helloDatasourceProvider = Provider<HelloDatasource>(
  (ref) => HelloDatasourceImpl(FirebaseFunctions.instance),
);

final _helloRepositoryProvider = Provider<HelloRepository>(
  (ref) => HelloRepositoryImpl(ref.watch(_helloDatasourceProvider)),
);

final _callHelloProvider = Provider<CallHello>(
  (ref) => CallHello(ref.watch(_helloRepositoryProvider)),
);
```
- Builds the dependency chain: `Datasource → Repository → UseCase`.
- `ref.watch()` is like calling `container.resolve()` — it gets the dependency and re-runs if it changes.

**Part 2 — State + actions (like a Zustand store or Redux slice):**
```dart
class HelloState {
  final HelloMessage? result;
  final bool isLoading;
  final String? error;
}

class HelloNotifier extends Notifier<HelloState> {
  Future<void> callHello(String message) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await ref.read(_callHelloProvider)(message);
      state = state.copyWith(isLoading: false, result: result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
```
- `HelloState` is immutable state (like Redux state shape).
- `HelloNotifier` has the `callHello` action method (like a Redux thunk or Zustand action).
- `state = state.copyWith(...)` is like `setState()` in React or `set()` in Zustand.
- Used by: `HelloScreen` — it watches `helloNotifierProvider` to read state and calls `notifier.callHello()` on button press.

---

### `presentation/screens/hello_screen.dart`
**TypeScript equivalent:** A React page component.
**Java equivalent:** A Spring MVC `@Controller` with a Thymeleaf view.

```dart
class HelloScreen extends ConsumerStatefulWidget { ... }

class _HelloScreenState extends ConsumerState<HelloScreen> {
  Widget build(BuildContext context) {
    final state = ref.watch(helloNotifierProvider);      // like useSelector / useStore
    final notifier = ref.read(helloNotifierProvider.notifier); // like useDispatch / store actions

    // Renders: TextField + Button + loading/error/result display
    // On button press: notifier.callHello(text)
  }
}
```

- `ConsumerStatefulWidget` = a Flutter widget that can read Riverpod providers. Like a React component using hooks.
- `ref.watch(...)` = subscribes to state. Re-renders when state changes. Exactly like `useSelector` in Redux or `useStore` in Zustand.
- `ref.read(...notifier)` = gets the notifier to call actions. Like `useDispatch` in Redux.
- Only knows about `HelloState` (domain entity inside it) and `HelloNotifier`. Knows nothing about Firebase.

---

### `main.dart`
**TypeScript equivalent:** Your `index.ts` server bootstrap — `app.listen()`, middleware setup.
**Java equivalent:** `@SpringBootApplication` main class.

```dart
void main() async {
  await dotenv.load();                             // load .env (USE_EMULATOR=true/false)
  await Firebase.initializeApp(...);               // boot Firebase
  if (USE_EMULATOR) { ... useFunctionsEmulator() } // point to local emulator if dev
  await FirebaseAuth.signInAnonymously();          // auto sign-in
  runApp(ProviderScope(child: MyApp()));           // ProviderScope = the DI root container
}
```

- `ProviderScope` is the root of the Riverpod DI system. Every provider lives inside it.
- Think of it like `app.use(container.middleware())` in a DI-enabled Express app, or the Spring application context root.

---

### `functions/src/index.ts` (the actual server)
This IS a regular TypeScript backend — specifically a Firebase Cloud Function:

```typescript
export const helloWorld = onCall({ invoker: "public" }, (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");

  const input = request.data?.message;
  if (typeof input !== "string" || input.trim() === "")
    throw new HttpsError("invalid-argument", "A non-empty message string is required.");

  logger.info("Echo request", { message: input });
  return { message: input };
});
```

- `onCall` = an HTTPS-callable function. Not a REST endpoint — Firebase handles auth token passing automatically.
- `request.auth` = automatically decoded Firebase Auth token. Free auth guard with zero middleware.
- `request.data` = the payload (`{ message: "..." }`).
- Returns `{ message: input }` which becomes `result.data` on the Flutter side.
- Equivalent to an Express POST route: `app.post('/hello', authMiddleware, validateBody, handler)`.

---

## 6. End-to-End Data Flow — Every Step

User types "hi" and presses **Send to server**.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ FLUTTER APP                                                                 │
│                                                                             │
│  1. HelloScreen._submit()                                                   │
│     notifier.callHello("hi")                                                │
│     │                                                                       │
│  2. HelloNotifier.callHello("hi")          [presentation/providers]         │
│     state = { isLoading: true }  ──────────────► UI shows spinner          │
│     await ref.read(_callHelloProvider)("hi")                                │
│     │                                                                       │
│  3. CallHello.call("hi")                   [domain/usecases]                │
│     return _repository.callHello("hi")                                      │
│     │                                                                       │
│  4. HelloRepositoryImpl.callHello("hi")    [data/repositories]              │
│     final model = await _datasource.callHello("hi")                         │
│     │                                                                       │
│  5. HelloDatasourceImpl.callHello("hi")    [data/datasources]               │
│     FirebaseFunctions.httpsCallable('helloWorld').call({ message: "hi" })  │
│     │                                                                       │
│  ───────────────── NETWORK CALL ─────────────────────────────────────────  │
│                                                                             │
│                              FIREBASE CLOUD FUNCTIONS (functions/src/)      │
│                                                                             │
│  6. helloWorld handler runs                                                 │
│     checks request.auth ✓                                                   │
│     validates request.data.message ✓                                        │
│     return { message: "hi" }                                                │
│                                                                             │
│  ───────────────── RESPONSE ─────────────────────────────────────────────  │
│                                                                             │
│  5b. result.data = { "message": "hi" }     [data/datasources]              │
│      HelloMessageModel.fromJson(result.data)                                │
│      returns HelloMessageModel { message: "hi" }                            │
│      │                                                                      │
│  4b. model.toEntity()                      [data/repositories]              │
│      returns HelloMessage { message: "hi" }   ← clean domain entity        │
│      │                                                                      │
│  3b. returns HelloMessage to UseCase       [domain/usecases]                │
│      │                                                                      │
│  2b. HelloNotifier receives HelloMessage                                    │
│      state = { isLoading: false, result: HelloMessage("hi") }               │
│      │                                                                      │
│  1b. HelloScreen rebuilds                  [presentation/screens]           │
│      state.result.message = "hi"  ──────────► UI shows "hi"               │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Every file touched in one request/response cycle:**

| Step | File | Role |
|---|---|---|
| 1 | `hello_screen.dart` | User action → calls notifier |
| 2 | `hello_provider.dart` | Sets loading state, calls usecase |
| 3 | `call_hello.dart` | Delegates to repository |
| 4 | `hello_repository_impl.dart` | Calls datasource, converts DTO → Entity |
| 5 | `hello_datasource.dart` | Fires Firebase Functions SDK call |
| 6 | `functions/src/index.ts` | Server validates + echoes back |
| 5b | `hello_datasource.dart` | Parses raw response into `HelloMessageModel` |
| 4b | `hello_repository_impl.dart` | Calls `.toEntity()` to get clean `HelloMessage` |
| 2b | `hello_provider.dart` | Updates state with result |
| 1b | `hello_screen.dart` | Riverpod triggers UI rebuild, shows result |

---

## 7. Why Bother? (The Pitch)

| Without Clean Arch | With Clean Arch |
|---|---|
| Firebase SDK call inside the UI widget | Firebase only touched in one file (datasource) |
| To test UI you need Firebase running | Swap `HelloRepositoryImpl` for a mock, test UI in isolation |
| Changing from Firebase to REST breaks everything | Only change the datasource file |
| Business logic scattered across widgets | UseCase is a plain class, unit-testable with zero Flutter setup |

The tradeoff: more files upfront, but each file is tiny, single-purpose, and independently testable. Same reason you split Express routes → controllers → services → DAOs.

---

## 8. Quick Reference Cheat Sheet

```
FLUTTER              EXPRESS/HONO            JAVA
─────────────────────────────────────────────────
Entity               type / interface        POJO
Model (DTO)          DTO class + fromJson    @JsonProperty class
Repository (abs)     interface IRepo         interface Repo
Repository Impl      class RepoImpl          @Repository RepoImpl
Datasource           raw fetch/axios call    DAO
UseCase              service method          @Service method
Notifier             Zustand store           ViewModel
Provider (DI part)   DI container config     @Configuration / @Autowired
Screen               React page component    @Controller + view
ProviderScope        DI root container       Spring ApplicationContext
ref.watch()          useSelector / useStore  @Autowired field
ref.read()           store.getState()        applicationContext.getBean()
state.copyWith()     setState / spread       new Builder().from(state).build()
```

---

> All code snippets are taken directly from `/apps/mobile/lib/features/hello/` and `/functions/src/index.ts`.
