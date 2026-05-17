# Chapter 10 Plan — Flutter Tests

## Scope

```
apps/mobile/test/
├── features/auth/        (all test files)
├── features/avatar/      (all test files)
├── features/chat/        (all test files)
├── features/hello/       (all test files)
├── features/home/        (all test files)
├── features/matchmaking/ (all test files)
├── features/profile/     (all test files)
└── widget_test.dart
```

---

## Goals

This chapter audits the **quality** of the tests, not just their existence. The question is not "does this file exist?" — it's "does this test actually catch bugs?"

---

## Checks to Perform

### 10.1 Test Count & Coverage Baseline
- [ ] Run `flutter test --coverage` — note total test count and coverage %.
- [ ] Per-feature test counts — cross-check with CLAUDE.md claim of "347 tests".
- [ ] Coverage report: which files are <80% covered? (Requirement: >80% for domain layer.)
- [ ] Coverage report: presentation and data layers — are they >50%?

### 10.2 Structural Rules (All Test Files)
- [ ] No Firebase SDK imported anywhere in test files.
- [ ] No mockito imported anywhere.
- [ ] Each `setUp` creates a fresh fake — no shared mutable state between tests.
- [ ] Every `_FakeXxxNotifier` overrides `build()` — default `build()` would touch Firebase.
- [ ] Screen tests use `ProviderScope(overrides: [...])` with fake notifiers.
- [ ] Domain tests have no `flutter` or Firebase imports.

### 10.3 Sentinel Pattern Tests (Per Feature)

For each feature state (`AuthState`, `ChatState`, `MatchmakingState`, `ProfileState`, `AvatarDecorationState`, `HelloState`):
- [ ] Test that `copyWith` with no args preserves all fields.
- [ ] Test that `copyWith` with an explicit non-null value updates that field.
- [ ] Test that `copyWith` with an explicit `null` CLEARS the nullable field (sentinel guard — the most commonly missed case).
- [ ] Log any state class that is missing the third case (clear-with-null).

### 10.4 Enum Tests (Per Feature)
- [ ] Each enum has exactly ONE test: `containsAll` assertion + `length` assertion.
- [ ] No individual `expect(MyEnum.value, ...)` tests per value.
- [ ] Check: `AuthStatus`, `SessionStatus`, `MatchmakingStatus`, `AvatarDecorationStatus`.

### 10.5 Entity Tests (Per Feature)
- [ ] Construction test with all required fields.
- [ ] Optional fields default to null.
- [ ] No behavior in entity — no logic tests needed.

### 10.6 Use Case Tests (Per Feature)
- [ ] Positive path: args forwarded correctly to repository fake.
- [ ] Positive path: result returned from repository propagated to caller.
- [ ] Negative path: exception from repository propagates.
- [ ] `lastArg` (or equivalent) asserted — not just "no error thrown".

### 10.7 Repository Impl Tests (Per Feature)
- [ ] Call counts asserted (e.g., `expect(fake.callCount, 1)`).
- [ ] Args forwarded from method signature to datasource fake.
- [ ] Model→entity conversion applied.
- [ ] Stream repos: `Stream.value(...)` used for stream tests.
- [ ] Exception from datasource propagates unchanged.

### 10.8 Model Tests (Per Feature)
- [ ] `fromJson` with ALL fields present.
- [ ] `fromJson` with nullable/optional fields missing (null handling).
- [ ] `fromJson` with extra unknown keys (should not throw — json_serializable ignores extras).
- [ ] `toEntity()` maps every field correctly.
- [ ] No hand-rolled JSON — check that generated files exist.

### 10.9 Screen Tests (Per Feature)
- [ ] Key widgets rendered in initial state.
- [ ] Validation errors shown when invalid input submitted.
- [ ] Valid submit calls notifier action (via callCount).
- [ ] Loading state: widgets disabled / loading spinner shown.
- [ ] Error state: error message displayed.
- [ ] No Firebase SDK used in test (always via fake notifier).

### 10.10 Shared Fakes (Per Feature)
- [ ] Each `shared_fakes.dart` exports a public fake (not underscore-prefixed).
- [ ] Fake implements ALL methods of the interface (`UnimplementedError` for unused is acceptable IF used in fewer than 3 test files — if in 3+, it should have a real implementation).
- [ ] Fake has `callCount` and `lastArg` / `lastArgs` for assertion.
- [ ] Fake has configurable `returnValue` and `error` fields.

### 10.11 `widget_test.dart`
- [ ] Is it the default Flutter widget test? (Usually tests `MyApp` renders without error.)
- [ ] If it tests `MyApp`, it must use fake Firebase or mock providers — not real Firebase.
- [ ] If it's empty/stub: flag as INFO (should be removed or updated).

### 10.12 Missing Test Files (Cross-check)
Cross-check each source file against the expected test file:

| Source | Expected Test | Exists? |
|--------|---------------|---------|
| `auth/domain/entities/auth_user.dart` | `auth_user_test.dart` | ? |
| `auth/data/models/auth_user_model.dart` | `auth_user_model_test.dart` | ? |
| `avatar/presentation/screens/avatar_picker_screen.dart` | screen test DEFERRED — confirm explicitly | ? |
| `chat/domain/entities/typing_user.dart` | `typing_user_test.dart` | ? |
| `matchmaking/usecases/watch_1v1_match.dart` | `watch_1v1_match_test.dart` | ? |
| `home/presentation/screens/home_screen.dart` | `home_screen_test.dart` | ? |

(Expand this table for all source files during the review.)

### 10.13 Test Quality Anti-Patterns
Search for and flag:
- [ ] `expect(true, true)` or `expect(result, result)` — vacuous assertions.
- [ ] Tests that only assert "no exception thrown" without checking result.
- [ ] Multiple `setUp`-mutating operations inside a single `test()`.
- [ ] Hard-coded UIDs or displayNames in tests that should come from the fake.
- [ ] `await Future.delayed(...)` used to wait for async operations (should use `pump` for widget tests).

---

## Files to Review

Read ALL files in `apps/mobile/test/features/` — every test file needs at least a structural scan. Read in full (for detailed analysis):
- All `shared_fakes.dart` files
- All `*_state_test.dart` files (sentinel coverage is most critical)
- All `*_screen_test.dart` files
- `widget_test.dart`

---

## Expected Findings Categories

- Missing sentinel test (clear nullable with null) in one or more state tests (HIGH — systematic)
- Screen test missing loading state assertions (MEDIUM)
- Shared fake `UnimplementedError` on a method that IS tested (MEDIUM)
- `widget_test.dart` uses real Firebase (CRITICAL if found)
- Test count mismatch vs CLAUDE.md claim of 347 (INFO — update docs)
- Coverage <80% for domain layer of any feature (HIGH per DoD)
- Vacuous assertions (MEDIUM)

---

## Output

Write findings to `reviews/ch10_flutter_tests.md` including:
- Actual test count per feature
- Coverage percentages (if `flutter test --coverage` is run)
- Sentinel coverage table (feature → state → has clear-null test: yes/no)
- Missing test files list
