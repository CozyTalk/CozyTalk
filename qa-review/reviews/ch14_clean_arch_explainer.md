# Chapter 14 — CLEAN_ARCH_EXPLAINER.md QA Review

> Status: COMPLETE
> Reviewer: qa-agent-supplemental
> Date: 2026-05-17

## Summary

Reviewed `CLEAN_ARCH_EXPLAINER.md` (445 lines), a developer explainer for the `hello` feature Clean Architecture implementation, against every file in `apps/mobile/lib/features/hello/` and the supporting files `apps/mobile/lib/main.dart` and `functions/src/index.ts`. The doc is largely accurate: all file paths exist, all class and method names are correct, the layer diagram is valid, and the end-to-end flow table is accurate. Three findings were identified — all LOW severity. Two relate to code snippet omissions (the datasource snippet omits a response-validation guard present in the real code, and the `HelloState.copyWith` snippet omits the sentinel pattern entirely), and one is an outdated depiction of `main.dart` that describes auto `signInAnonymously` and `dotenv.load()` that are not present in the actual bootstrap. No CRITICAL, HIGH, or MEDIUM issues were found. The `hello` feature remains a valid and accurate template for new features.

---

## Findings

### F-001 — `HelloDatasourceImpl.callHello()` snippet omits response-validation guard

- **Severity:** LOW
- **File:** `CLEAN_ARCH_EXPLAINER.md` line 178
- **Category:** Doc-Drift
- **Description:** The doc's code snippet for `HelloDatasourceImpl.callHello()` shows `return HelloMessageModel.fromJson(result.data)` directly, implying the raw `result.data` is passed straight to `fromJson`. The real implementation first checks that the response is a `Map` and normalises it with `Map<String, dynamic>.from(data)` before passing to `fromJson`. The code convention in CLAUDE.md (`Map from Firebase — always normalize via Map<String, dynamic>.from(data as Map)`) makes this guard load-bearing, not optional.
- **Evidence (actual `hello_datasource.dart` lines 18–23):**
  ```dart
  final data = result.data;
  if (data is! Map) {
    throw Exception('Unexpected response format from helloWorld');
  }
  return HelloMessageModel.fromJson(Map<String, dynamic>.from(data));
  ```
  Doc shows (line 183):
  ```dart
  return HelloMessageModel.fromJson(result.data);
  ```
- **Recommendation:** Update the datasource snippet to include the `is! Map` guard and `Map<String, dynamic>.from(data)` call. This is a required pattern per project conventions and should be visible in the canonical template example.

---

### F-002 — `HelloState.copyWith` snippet omits the sentinel pattern

- **Severity:** LOW
- **File:** `CLEAN_ARCH_EXPLAINER.md` lines 247–263
- **Category:** Doc-Drift
- **Description:** The `HelloState` snippet shown for `hello_provider.dart` presents a bare `HelloState` class and a `copyWith` call but omits the `_sentinel` constant and the sentinel-based nullable-field handling that the actual class uses. The project's code conventions (CLAUDE.md: "Freezed copyWith sentinel pattern — nullable fields must use `_sentinel` so callers can explicitly pass `null` to clear them") make this pattern mandatory. The template example should demonstrate it, since any developer copying the hello feature as a template would miss this requirement.
- **Evidence (actual `hello_provider.dart` lines 26–43):**
  ```dart
  const _sentinel = Object();

  class HelloState {
    final HelloMessage? result;
    final bool isLoading;
    final String? error;

    const HelloState({this.result, this.isLoading = false, this.error});

    HelloState copyWith({
      Object? result = _sentinel,
      bool? isLoading,
      Object? error = _sentinel,
    }) => HelloState(
      result: result == _sentinel ? this.result : result as HelloMessage?,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
  ```
  Doc shows only:
  ```dart
  class HelloState {
    final HelloMessage? result;
    final bool isLoading;
    final String? error;
  }
  ```
  with no `copyWith` definition at all — the snippet jumps straight to `HelloNotifier`.
- **Recommendation:** Add the `_sentinel` declaration and full `copyWith` body to the `HelloState` snippet. This is the single most important convention new contributors must absorb from the template.

---

### F-003 — `main.dart` snippet describes bootstrap that does not exist

- **Severity:** LOW
- **File:** `CLEAN_ARCH_EXPLAINER.md` lines 302–312
- **Category:** Doc-Drift
- **Description:** The `main.dart` pseudo-code snippet in section 5 shows three things that are not present in the actual `main.dart`:
  1. `await dotenv.load()` — no dotenv package is used; `USE_EMULATOR` is a compile-time constant via `bool.fromEnvironment`.
  2. `await FirebaseAuth.signInAnonymously()` — main() does not call `signInAnonymously`. Auth is handled entirely by the auth feature's `AuthNotifier`.
  3. `if (USE_EMULATOR) { ... useFunctionsEmulator() }` — the actual code only calls `useFunctionsEmulator` for the `us-central1`-region instance, and also sets up Auth, Firestore, and RTDB emulators, which the snippet omits.

  The snippet is labelled "pseudo-code" implicitly, but the surrounding text says "All code snippets are taken directly from `/apps/mobile/lib/features/hello/` and `/functions/src/index.ts`" (line 444), which makes this appear to be actual code.
- **Evidence (actual `main.dart` lines 32–51):**
  ```dart
  const _useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    if (_useEmulator) {
      await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
      FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator('127.0.0.1', 5001);
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
      FirebaseDatabase.instance.useDatabaseEmulator('127.0.0.1', 9000);
    }

    runApp(const ProviderScope(child: MyApp()));
  }
  ```
- **Recommendation:** Replace the `main.dart` snippet with one that reflects the actual bootstrap: `bool.fromEnvironment` constant, four emulator wires (Auth, Functions, Firestore, RTDB), and `ProviderScope` wrap. Remove the non-existent `dotenv.load()` and `signInAnonymously()` calls. Either label the snippet clearly as illustrative pseudo-code, or update it to be accurate — given the footer on line 444 claims snippets are taken directly from the source, the latter is correct.

---

### F-004 — `helloWorld` Cloud Function snippet omits `cors: true` option

- **Severity:** LOW
- **File:** `CLEAN_ARCH_EXPLAINER.md` line 320
- **Category:** Doc-Drift
- **Description:** The `functions/src/index.ts` snippet shows `onCall({ invoker: "public" }, ...)` but the actual function declaration is `onCall({invoker: "public", cors: true}, ...)`. The `cors: true` flag is required for the Web target (Flutter Web) to call the function from a browser origin. Omitting it from the template example could mislead a developer adding a new callable function that targets the web platform.
- **Evidence (actual `functions/src/index.ts` line 32):**
  ```typescript
  export const helloWorld = onCall({invoker: "public", cors: true}, (request) => {
  ```
  Doc shows (line 320):
  ```typescript
  export const helloWorld = onCall({ invoker: "public" }, (request) => {
  ```
- **Recommendation:** Add `cors: true` to the `onCall` options object in the snippet. Add a comment noting that this is required for Flutter Web callers.

---

### F-005 — `logger.info` call omits `structuredData: true` flag

- **Severity:** INFO
- **File:** `CLEAN_ARCH_EXPLAINER.md` line 328
- **Category:** Doc-Drift
- **Description:** The `helloWorld` snippet shows `logger.info("Echo request", { message: input })` but the actual call is `logger.info("Echo request", {message: input, structuredData: true})`. This is a minor omission with no functional impact for developers following the example for structured Cloud Logging integration.
- **Evidence (actual `functions/src/index.ts` line 43):**
  ```typescript
  logger.info("Echo request", {message: input, structuredData: true});
  ```
- **Recommendation:** Update the snippet to include `structuredData: true` for completeness, since the explainer claims snippets are taken directly from the source.
