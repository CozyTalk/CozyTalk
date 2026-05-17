# Chapter 17 — Integration Tests & Gap Analysis QA Review

> Status: COMPLETE
> Reviewer: qa-agent-supplemental
> Date: 2026-05-17

## Summary

Reviewed all three Flutter integration test files (`matchmaking_test.dart`, `matchmaking_advanced_test.dart`, `firebase_test_helper.dart`) and cross-checked against the full feature inventory (auth, chat, matchmaking, profile, avatar, hello, home). The integration test suite is exclusively matchmaking-scoped — it covers Cloud Function behavior at the Firebase/emulator boundary but contains zero coverage for auth flows, chat messaging end-to-end, profile persistence, or avatar updates. Within the matchmaking scope, the tests are thorough (58 total tests: 43 advanced + 15 basic). One structural defect exists in `firebase_test_helper.dart` that causes all tests to fail on Android emulator. The CLAUDE.md unit test count (347) is accurate, but the chat test file count claim (13) conflates test files with the `shared_fakes.dart` helper. The Jest unit test count in `qa-engineer.md` is confirmed stale (see ch16 F-003).

## Findings

### F-001 — Auth/Functions emulator hardcodes `127.0.0.1` instead of `_emulatorHost` on all SDK-level connections
- **Severity:** HIGH
- **File:** `apps/mobile/integration_test/firebase_test_helper.dart` lines 32–37
- **Category:** Test-Infrastructure-Bug
- **Description:** `setupFirebaseForTest()` calls `useAuthEmulator('127.0.0.1', 9099)`, `useFunctionsEmulator('127.0.0.1', 5001)`, `useFirestoreEmulator('127.0.0.1', 8080)`, and `useDatabaseEmulator('127.0.0.1', 9000)` — all with hardcoded `'127.0.0.1'`. The file defines `_emulatorHost` getter (line 17) that returns `'10.0.2.2'` on Android and `'127.0.0.1'` elsewhere — but `_emulatorHost` is only used for HTTP calls (`resetEmulatorData`, `adminFirestoreDoc`). CLAUDE.md says the Flutter integration tests require "Emulators + Android device." On an Android emulator, `127.0.0.1` routes to the AVD's own loopback, not the host machine, so all four emulator SDK connections will time out or refuse.
- **Evidence:** Lines 32–37 of `firebase_test_helper.dart`; line 17 defines the correct platform-conditional host but it is not applied to `useXxxEmulator` calls. `resetEmulatorData` at line 87 correctly uses `final host = _emulatorHost`.
- **Recommendation:** Replace all four hardcoded `'127.0.0.1'` strings in `setupFirebaseForTest()` with `_emulatorHost`. Since `_emulatorHost` is a getter (not a `const`), it cannot be used in field initializers but is safe in an `async` function body.

### F-002 — `matchmaking_test.dart` sendMessage test directly imports Firebase SDK (bypasses helper pattern)
- **Severity:** MEDIUM
- **File:** `apps/mobile/integration_test/matchmaking_test.dart` lines 1–2, 245–268
- **Category:** Test-Architecture
- **Description:** `matchmaking_test.dart` imports `cloud_firestore` and `firebase_database` directly (lines 1–2) and calls `FirebaseDatabase.instance.ref(...).set(...)` (line 245) and `FirebaseFirestore.instance.collection(...).get()` (line 263) inline in the `sendMessage` test. This duplicates SDK plumbing that should go through helpers and makes the test fragile — it re-derives the member UID via a raw RTDB tree walk (lines 254–258) rather than using `adminFirestoreDoc`. If the RTDB tree structure changes the member lookup silently returns an empty string and the test passes vacuously.
- **Evidence:** `matchmaking_test.dart` lines 254–258: the member UID lookup via `.children.map((s) => s.key).firstWhere(...)` with `orElse: () => null` — if `uidB` resolves to `''` the subsequent `sendMessage` call still fires and the assertion on `senderId` passes on whatever user is signed in.
- **Recommendation:** Move the sendMessage test to `matchmaking_advanced_test.dart` (which uses the admin helper pattern). Replace the RTDB tree walk with `adminFirestoreDoc('rooms/$roomId')` to get the users array, then pick the non-uidA member.

### F-003 — Integration tests have no coverage for `sendMessage` encryption correctness
- **Severity:** MEDIUM
- **File:** `apps/mobile/integration_test/matchmaking_test.dart` lines 229–283
- **Category:** Missing-Test
- **Description:** The one `sendMessage` integration test checks that `encryptedText` is non-empty and `displayName` is non-null. It does not verify that: (1) the `iv` and `authTag` fields are present and non-empty, (2) the ciphertext is different from the plaintext, (3) a 1v1 room uses the CF-managed key (not the client-derived proto key). The test also does not exercise `endSession` or `reportSession` end-to-end from the Flutter side — those are only covered by Jest tests.
- **Evidence:** `matchmaking_test.dart` lines 268–276: only `encryptedText`, `senderId`, and `displayName` are asserted. `iv` and `authTag` (the AES-GCM authentication tag) are not checked.
- **Recommendation:** Extend the sendMessage test to assert `msg['iv'] != null && (msg['iv'] as String).isNotEmpty` and `msg['authTag'] != null`. Add a separate integration test for `endSession` that verifies `chat_rooms/{sessionId}/messages` is empty after the call.

### F-004 — No integration test for `expireRooms` scheduled function
- **Severity:** MEDIUM
- **File:** `apps/mobile/integration_test/`
- **Category:** Missing-Test
- **Description:** The `expireRooms` cron function (runs every 2 minutes in production) is not exercised by any Flutter integration test. `matchmaking_advanced_test.dart` tests the _padding state_ but never calls `expireRooms` directly or via `callScheduledFn`. The Jest helpers.ts has `callScheduledFn` but `matchmaking.test.ts` does not use it either. The entire expiry-tombstone path (padding → expired, RTDB re-verification, message destruction) has no automated end-to-end test.
- **Evidence:** `grep -r "expireRooms" apps/mobile/integration_test/` → no results. `grep "expireRooms\|callScheduledFn" functions/src/matchmaking/__tests__/matchmaking.test.ts` → no results. `helpers.ts` exports `callScheduledFn` but it is unused.
- **Recommendation:** Add one integration test (either Dart or Jest) that: creates a room, has all users leave (triggering padding), calls `expireRooms` via the emulator trigger endpoint, then asserts the room doc has `status: "expired"` and `users: []`.

### F-005 — `matchmaking_test.dart` does not call `resetEmulatorData` in `setUp`
- **Severity:** MEDIUM
- **File:** `apps/mobile/integration_test/matchmaking_test.dart` line 12
- **Category:** Test-Infrastructure
- **Description:** `matchmaking_test.dart` calls only `signOut()` in its `setUp`. It does not call `resetEmulatorData()`, unlike `matchmaking_advanced_test.dart` (line 15) which calls both. If tests in `matchmaking_test.dart` run after other tests that left rooms or pool entries in place, the state leaks. For example, the `leaveRoom: last member causes room to enter padding status` test assumes a freshly created room with a single user — pre-existing padding rooms from a prior run could interfere.
- **Evidence:** `matchmaking_test.dart` line 12: `setUp(signOut)` only. `matchmaking_advanced_test.dart` line 15: `setUp(() async { await signOut(); await resetEmulatorData(); })`.
- **Recommendation:** Change `matchmaking_test.dart`'s `setUp` to also call `resetEmulatorData()` for deterministic test isolation.

### F-006 — No integration test file for `test_driver/integration_test.dart` (Web integration tests unreachable)
- **Severity:** MEDIUM
- **File:** `.claude/agents/qa-engineer.md` line 133
- **Category:** Missing-Infrastructure
- **Description:** `qa-engineer.md` documents a web integration test run command: `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d chrome`. Neither `test_driver/` nor `integration_test/app_test.dart` exists. Web integration testing is entirely unimplemented. The quality gate in `qa-engineer.md` says "integration tests passing on both Android and Web" but only an Android/Linux path exists.
- **Evidence:** `ls apps/mobile/test_driver/` → directory does not exist. `ls apps/mobile/integration_test/` → `firebase_test_helper.dart`, `matchmaking_advanced_test.dart`, `matchmaking_test.dart` only.
- **Recommendation:** Either (a) create `test_driver/integration_test.dart` and `integration_test/app_test.dart` as the Web entry points, or (b) update `qa-engineer.md` and the quality gate to reflect that web integration testing is aspirational and tracked as a known gap.

### F-007 — `CLAUDE.md` states chat feature has "13 test files" — ambiguous counting
- **Severity:** LOW
- **File:** `CLAUDE.md` Chat Feature section
- **Category:** Doc-Drift
- **Description:** CLAUDE.md states "Tests: 13 test files covering all three layers." The `test/features/chat/` directory contains 13 `.dart` files, but one of them (`shared_fakes.dart`) is a helper, not a test file. There are 12 files ending in `_test.dart`. The 13-file count is technically correct if counting all `.dart` files in the directory but mixes test files with support files. The same counting convention is not used for other features.
- **Evidence:** `find test/features/chat -name "*.dart" | wc -l` → 13. `find test/features/chat -name "*_test.dart" | wc -l` → 12.
- **Recommendation:** Clarify: "12 test files + 1 `shared_fakes.dart` helper." Apply consistent counting across all feature descriptions.

### F-008 — `CLAUDE.md` claims chat.test.ts has 11 tests; actual count is 12
- **Severity:** LOW
- **File:** `CLAUDE.md` Essential Commands section (Jest test counts)
- **Category:** Doc-Drift
- **Description:** CLAUDE.md states "chat.test.ts (11 tests)." The file now contains 12 tests. The 12th test — "endSession tombstones new-style room and archives session_keys" — was added in the QA Phase 2 fix commit (`bc38665`) to cover the `rooms/` path in `endSession`. The cumulative count in CLAUDE.md therefore also needs updating: 60 + 21 + 12 = 93 unit tests, not 92. Grand total with integration tests: 93 + 7 = 100.
- **Evidence:** `grep -c "^\s*test(" functions/src/chat/__tests__/chat.test.ts` → 12. Git log shows `bc38665`: "chat.test.ts: add endSession test for rooms/ path."
- **Recommendation:** Update CLAUDE.md: "chat.test.ts (12 tests)" and totals accordingly: "93 unit tests... Grand total: 100."

## Test Coverage Assessment

| Feature | Unit tests (domain) | Widget tests (screens) | Integration tests | Key gaps |
|---|---|---|---|---|
| `hello` | ✅ entity, usecase, model, repo | ✅ HelloScreen | ❌ none | Non-critical: smoke CF covered by matchmaking tests |
| `auth` | ✅ all 5 usecases, entity, model, repo | ✅ LoginScreen, SignupScreen | ❌ none | Anonymous sign-in smoke-tested indirectly by matchmaking integration tests; Google/email flows have no integration test |
| `matchmaking` | ✅ all 9 usecases, entity, model, repo | ✅ MatchmakingTestScreen | ✅ 58 Dart + 60 Jest | Missing: `expireRooms` E2E (F-004) |
| `chat` | ✅ all 5 usecases, 3 entities, model, repo | ✅ ChatScreen | ❌ none (basic sendMessage test in `matchmaking_test.dart` only) | No E2E encrypt/decrypt round-trip; no `endSession` Dart integration test |
| `profile` | ✅ all 4 usecases, entity, model, repo | ✅ ProfileScreen | ❌ none | Profile read/write flow unverified against real Firestore |
| `avatar` | ✅ all 4 usecases, entity, model, repo | ❌ No `AvatarPickerScreen` widget test | ❌ none | Widget test gap identified in ch10 F-001 (now unblocked); no integration test |
| `home` | N/A (no domain layer) | ✅ HomeScreen | ❌ none | Non-critical: HomeScreen is a navigation stub |

### Coverage notes

- **Matchmaking** has the strongest coverage by far: 58 Dart integration tests against the emulator and 60 Jest tests. The tests cover priority selection, secondary randomness, padding lifecycle, RTDB paths, 1v1 triggers, leave/requeue, and multi-user flows.
- **Auth** is indirectly smoke-tested by every integration test (all tests call `signInAnon()`), but the Google and Email/Password flows have zero integration test coverage.
- **Chat** is the most critical coverage gap. The entire encrypt/decrypt round-trip (CF `sendMessage` → `ChatDatasourceImpl.watchMessages()` decrypt) has no Dart integration test. The Jest tests cover CF behavior at the server side but the Flutter-side decryption path is untested end-to-end.
- **Profile** and **avatar** have no integration tests. Updates to `users/{uid}` fields are only verified by unit tests with fake datasources.
- The `expireRooms` scheduled function has no integration test in either Dart or Jest suites despite being a critical cleanup path.

### Unit test count verification

| Feature | `test()` count | `testWidgets()` count | Files (`_test.dart`) | Total |
|---|---|---|---|---|
| `auth` | ~52 | ~8 | 11 | 60 |
| `avatar` | ~38 | ~4 | 8 | 42 |
| `chat` | ~51 | ~7 | 12 | 58 |
| `hello` | ~22 | ~6 | 6 | 28 |
| `home` | ~2 | ~2 | 1 | 4 |
| `matchmaking` | ~95 | ~8 | 15 | 103 |
| `profile` | ~43 | ~6 | 9 | 49 |
| `widget_test.dart` | 0 | 3 | 1 | 3 |
| **Total** | **~303** | **~44** | **63** | **347** |

_347 total confirmed by `grep -rh "^\s*test\b\|^\s*testWidgets\b" test/ --include="*_test.dart" | wc -l` → 347. Matches CLAUDE.md claim._

The `shared_fakes.dart` files (one per feature: auth, avatar, chat, matchmaking, profile) are not counted as test files and are excluded from the 63 `_test.dart` file count. CLAUDE.md's claim of "347 unit+widget tests" is accurate.
