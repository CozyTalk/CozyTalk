# Chapter 12 — CI/CD, Scripts & DevOps QA Review

> Status: COMPLETE
> Reviewer: qa-agent-phase4
> Date: 2026-05-17

## Summary

Reviewed `.github/workflows/ci.yml`, `.github/workflows/build.yml`, `.github/pull_request_template.md`, `setup.sh`, `dev.sh`, `logs.sh`, `setup.ps1`, `dev.ps1`, `functions/package.json`, and `tools/check-prod-config.sh`. The CI infrastructure is well-structured with concurrency groups, pinned action SHAs, and separate quality vs. build workflows. Two HIGH findings: a Flutter version mismatch between CI and build workflows, and a missing `google-services.json` injection step that will break the Android build CI job once Phase 1 changes (gitignore + `git rm --cached`) are committed. Shell scripts are solid — proper `set -euo pipefail`, correct port cleanup, attach mode for already-running emulators, log rotation. The PR template covers security, privacy, and Clean Architecture checklists explicitly.

**Findings by severity:** HIGH 2 · MEDIUM 2 · LOW 2 · INFO 3

---

## Findings

### F-001 — Flutter version mismatch: ci.yml uses 3.41.7, build.yml uses 3.41.6
- **Severity:** HIGH
- **File:** `.github/workflows/ci.yml` line 39, `.github/workflows/build.yml` lines 33 and 53
- **Category:** Bug
- **Description:** `flutter-quality` in `ci.yml` installs Flutter 3.41.7. Both `build-android` and `build-web` in `build.yml` install 3.41.7. Tests pass on 3.41.7 but APK and web artifacts are built on 3.41.6. If any code relies on a behavior introduced in 3.41.7, CI tests pass but the build artifact would silently ship the old behavior. Conversely, any 3.41.7 regression caught by tests is not caught by the build.
- **Evidence:** `ci.yml:39` — `flutter-version: '3.41.7'`; `build.yml:33,53` — `flutter-version: '3.41.6'`
- **Recommendation:** Align all three jobs to the same version. Use 3.41.7 (the higher version already used in CI tests) to bring build.yml up to match.

---

### F-002 — `build-android` has no `google-services.json` injection step
- **Severity:** HIGH
- **File:** `.github/workflows/build.yml` lines 15–42
- **Category:** Bug
- **Description:** Phase 1 of this QA added `apps/mobile/android/app/google-services.json` to `.gitignore` and ran `git rm --cached` to stop tracking it. Once those changes are committed, the `build-android` CI job will fail because the file won't be present in the checkout. Flutter's Firebase Gradle plugin requires `google-services.json` at build time to generate `R.java` constants; without it, compilation aborts. The `build-web` job is unaffected (web uses `firebase_options.dart`, not `google-services.json`).
- **Evidence:** `build.yml` has no step that writes or decodes `google-services.json` before `flutter build apk`. The file is now gitignored (`.gitignore` contains `apps/mobile/android/app/google-services.json`).
- **Recommendation:** Add a decode step in the `build-android` job:
  ```yaml
  - name: Inject google-services.json
    env:
      GOOGLE_SERVICES_JSON: ${{ secrets.GOOGLE_SERVICES_JSON }}
    run: echo "$GOOGLE_SERVICES_JSON" | base64 --decode > apps/mobile/android/app/google-services.json
  ```
  Then add `GOOGLE_SERVICES_JSON` as a base64-encoded repository secret in GitHub → Settings → Secrets. Generate the value with: `base64 -w 0 apps/mobile/android/app/google-services.json`.

---

### F-003 — Java version mismatch: ci.yml uses Java 21, build.yml uses Java 17
- **Severity:** MEDIUM
- **File:** `.github/workflows/ci.yml` line 33, `.github/workflows/build.yml` line 29
- **Category:** Style
- **Description:** `ci.yml` (`flutter-quality` and `functions-quality`) installs Java 21. `build.yml` (`build-android`) installs Java 17. Firebase emulators require Java 21+ (`setup.sh` warns on < 21). Android Gradle Plugin 8.x supports Java 17 as minimum but recommends 21+. The mismatch is low-risk today (Android builds work with 17) but will become a build failure when AGP drops Java 17 support. The web build job does not set up Java at all — no issue there.
- **Evidence:** `ci.yml:33` — `java-version: '21'`; `build.yml:29` — `java-version: '17'`
- **Recommendation:** Update `build.yml` to use Java 21 to match `ci.yml` and `setup.sh`.

---

### F-004 — `check-prod-config.sh` only verifies 10 of 15 deployed functions
- **Severity:** MEDIUM
- **File:** `tools/check-prod-config.sh` lines 146–153
- **Category:** Missing Coverage
- **Description:** The script's `check_fn` calls cover: `expireRooms`, `match1v1Users`, `cleanupMember`, `cleanupPoolMember`, `sendMessage`, `endSession`, `reportSession`, `leaveRoom`, `join1v1Pool`, `joinGroupRoom` — 10 functions. Missing from verification: `helloWorld`, `createCustomRoom`, `joinRoomById`, `setRoomLock`, `cancel1v1Pool`. If any of the missing five fail to deploy, the script exits green.
- **Evidence:** Lines 146–153 of `check-prod-config.sh` — no `check_fn` call for the five missing functions.
- **Recommendation:** Add five lines after line 153:
  ```sh
  check_fn "helloWorld"       "us-central1"
  check_fn "createCustomRoom" "us-central1"
  check_fn "joinRoomById"     "us-central1"
  check_fn "setRoomLock"      "us-central1"
  check_fn "cancel1v1Pool"    "us-central1"
  ```

---

### F-005 — `functions/package.json` `serve` script missing pubsub
- **Severity:** LOW
- **File:** `functions/package.json` line 8
- **Category:** Bug
- **Description:** `"serve": "npm run build && firebase emulators:start --only functions,auth,firestore,database"` omits `pubsub`. The integration test suite waits for port 8085 (pubsub). A developer running `npm run serve` instead of `./dev.sh` to start the emulators for testing will see Jest hang waiting for pubsub, or tests will fail if the scheduled CF tests require it.
- **Evidence:** `package.json:8` — `--only functions,auth,firestore,database`; `dev.sh` uses `--only functions,auth,firestore,database,pubsub`.
- **Recommendation:** Change to `--only functions,auth,firestore,database,pubsub`.

---

### F-006 — `build-web` does not pass `--dart-define=USE_EMULATOR=false`
- **Severity:** LOW
- **File:** `.github/workflows/build.yml` lines 57–63
- **Category:** Style
- **Description:** The web build job runs `flutter build web` without `--dart-define=USE_EMULATOR=false`. Because `USE_EMULATOR` defaults to `true`, the compiled web artifact has `localhost:9099/8080/9000/5001` baked in as the Firebase endpoint. A developer downloading this artifact from CI to test would see it try to connect to local emulators. This is a debug build so the impact is low, but it differs from the prod web build.
- **Evidence:** `build.yml:63` — `flutter build web` with no `--dart-define` flag.
- **Recommendation:** Change to `flutter build web --dart-define=USE_EMULATOR=false` to match production intent. Or accept as-is and document that the CI artifact is emulator-mode only.

---

### F-007 — `flutter-quality` auto-format step uses `github-actions[bot]` committer
- **Severity:** INFO
- **File:** `.github/workflows/ci.yml` lines 51–60
- **Category:** Style
- **Description:** The auto-format step commits with `user.name "github-actions[bot]"`. This is a GitHub system actor and is standard practice. The `[skip ci]` tag in the commit message correctly prevents CI loops. No action needed — noting for awareness.
- **Evidence:** `ci.yml:55–56` — `git config user.name "github-actions[bot]"`.
- **Recommendation:** None.

---

### F-008 — README says "All 16 Cloud Functions" but actual count is 15
- **Severity:** INFO
- **File:** `README.md` line 117
- **Category:** Doc-Drift
- **Description:** The `check-prod-config.sh` section of README says "All 16 Cloud Functions are deployed". PROJECT_CONTEXT.md and CLAUDE.md both document 15 exported functions. This discrepancy is addressed in Ch13 doc-sync.
- **Evidence:** `README.md:117` — "All 16 Cloud Functions are deployed."
- **Recommendation:** Fix in Ch13 doc-sync pass.

---

### F-009 — CLAUDE.md `tools/` described as "reserved, empty"
- **Severity:** INFO
- **File:** `CLAUDE.md` — Monorepo Layout section
- **Category:** Doc-Drift
- **Description:** CLAUDE.md lists `tools/ ← CLI tools (reserved, empty)` but `tools/check-prod-config.sh` exists and is documented in README. Addressed in Ch13.
- **Evidence:** CLAUDE.md Monorepo Layout section.
- **Recommendation:** Fix in Ch13 doc-sync pass.

---

## CI Pipeline Audit

| Check | `ci.yml` (flutter-quality) | `ci.yml` (functions-quality) | `build.yml` (build-android) | `build.yml` (build-web) |
|---|---|---|---|---|
| Action SHAs pinned | ✅ | ✅ | ✅ | ✅ |
| Concurrency group | ✅ | ✅ | ✅ | ✅ |
| Timeout set | ✅ 20 min | ✅ 20 min | ✅ 30 min | ✅ 20 min |
| Flutter version | `3.41.7` | — | `3.41.6` ⚠️ | `3.41.6` ⚠️ |
| Java version | `21` | `21` | `17` ⚠️ | — |
| `flutter pub get` | ✅ | — | ✅ | ✅ |
| `build_runner build` | ✅ | — | ✅ | ✅ |
| Generated file check | ✅ (git diff) | — | ❌ | ❌ |
| `dart format` gate | ✅ | — | ❌ | ❌ |
| `flutter analyze` | ✅ | — | ❌ | ❌ |
| `flutter test` | ✅ | — | ❌ | ❌ |
| `google-services.json` present | via git (until Phase 1 commit) | — | ❌ after Phase 1 commit | N/A |
| Pubsub emulator started | — | ✅ port 8085 | — | — |
| Jest test run | — | ✅ | — | — |
| USE_EMULATOR=false | — | — | N/A (apk) | ❌ |

---

## Script Health Audit

| Script | `set -euo pipefail` | Port cleanup | Emulator attach mode | Log rotation | Arg validation | Windows parity |
|---|---|---|---|---|---|---|
| `setup.sh` | ✅ | N/A | N/A | N/A | N/A | ✅ (`setup.ps1`) |
| `dev.sh` | ✅ | ✅ all 8 ports | ✅ (emulators_already_up) | ✅ keep last 10 | ✅ (fail on unknown) | ✅ (`dev.ps1`) |
| `logs.sh` | ✅ | N/A | N/A | N/A | ✅ | N/A (bash only) |

All scripts are well-written. No hardcoded credentials. No unsafe `eval` or unquoted variables. `dev.sh` correctly uses `EMULATOR_PID` tracking and a `cleanup` trap to ensure graceful shutdown on Ctrl+C.

---

## What Is Working Well

- All GitHub Actions use pinned SHA digests — no floating tags ✅
- Concurrency groups cancel in-progress PR runs but never cancel main-branch runs ✅
- `functions-quality` starts Firebase emulators in CI and runs Jest against them ✅
- `functions-quality` waits for all 5 emulator ports (including pubsub 8085) before running tests ✅
- `flutter-quality` auto-formats and pushes a fix commit on PRs (avoids lint-only failures blocking devs) ✅
- PR template includes explicit Security & Privacy and Clean Architecture checklists ✅
- `dev.sh` handles crash-recovery (kills stale processes on ports before starting) ✅
- `dev.sh` detect-and-attach mode prevents two terminals from fighting over emulator ownership ✅
- `logs.sh` supports `--prod`, `--fn=<name>` filter, and `--follow` — real operational tooling ✅
- `setup.sh` / `setup.ps1` check Java version and warn if < 21 ✅
- `dev.sh` / `dev.ps1` check Vertex AI ADC and warn if absent ✅
