# Chapter 12 Plan — CI/CD, Scripts & DevOps

## Scope

```
.github/workflows/ci.yml
.github/workflows/build.yml
.github/pull_request_template.md
setup.sh
setup.ps1
dev.sh
dev.ps1
logs.sh
firebase.json         (emulator config portion — full review in ch09)
apps/mobile/pubspec.yaml   (Flutter SDK version constraint — cross-ref)
functions/package.json    (Node version, scripts)
```

---

## Checks to Perform

### 12.1 CI Workflow (`ci.yml`)

#### Flutter Quality Job
- [ ] Triggers: `push` to main, `pull_request` to main — correct.
- [ ] Flutter version: `3.41.7` (pinned). Is this the same version developers use locally? Check vs `setup.sh`.
- [ ] Java version: `21` — required for Android toolchain.
- [ ] Steps in order:
  1. Checkout
  2. Setup Flutter
  3. `flutter pub get`
  4. `dart run build_runner build` — generates Freezed/Riverpod code
  5. `dart format --output=none --set-exit-if-changed .` — format check (not format + write)
  6. `flutter analyze` — static analysis
  7. `flutter test --coverage`
  8. Upload coverage to Codecov
- [ ] Does step 4 (build_runner) come BEFORE steps 5-7? It must — otherwise analyze fails on generated code.
- [ ] `--set-exit-if-changed` flag on format check — CI should fail if code is not pre-formatted.
- [ ] Coverage upload: `codecov/codecov-action` with correct flags?
- [ ] Does CI run on `ubuntu-latest` or a pinned Ubuntu version? Pinned is more stable.
- [ ] Is there a cache for pub cache? (`actions/cache` with `~/.pub-cache`) — speeds up CI.
- [ ] Are secrets (Firebase config, Codecov token) stored in GitHub Secrets, not hardcoded?

#### Functions Quality Job
- [ ] Node version: `24` (matches `engines.node` in `package.json`).
- [ ] Steps in order:
  1. Checkout
  2. Setup Node 24
  3. `npm install` in `functions/`
  4. `npm run lint` — ESLint check
  5. `npm run build` — TypeScript compilation
  6. Start Firebase emulator
  7. `npm test` — Jest unit tests (with emulators running)
- [ ] Emulator startup: uses `firebase emulators:start --only auth,firestore,functions,database` or similar.
- [ ] Emulator wait: health check before running tests (not just `sleep 30`).
- [ ] Emulator ports used in CI match those in `functions/__tests__/helpers.ts`.
- [ ] Integration tests (`embeddingService.integration.test.ts`) are excluded from CI (require Vertex AI credentials).
- [ ] Does CI fail on lint errors? (Should — lint is in `predeploy` and CI.)
- [ ] Does CI fail on TypeScript errors? (Should — `tsc --noEmit` or build fails.)

### 12.2 Build Workflow (`build.yml`)
- [ ] Triggers: `pull_request` to main, excluding `**.md` files.
- [ ] Jobs: `build-android` and `build-web`.
- [ ] Flutter version: `3.41.6` — **different from CI job's `3.41.7`**. This is a discrepancy — flag it.
- [ ] `build-android`: produces a debug APK? Or release? If release, requires signing keys.
- [ ] `build-web`: `flutter build web` — confirm it uses `--dart-define=USE_EMULATOR=false` for prod build.
- [ ] Java version for Android build: `17` (different from CI's `21`) — flag.
- [ ] Gradle cache configured?
- [ ] Build artifacts uploaded? Or just build-verify?
- [ ] `google-services.json` — Android build needs this. How is it provided in CI? From GitHub Secrets?

### 12.3 Pull Request Template (`.github/pull_request_template.md`)
- [ ] Template sections match CLAUDE.md description: Summary, Change type, Related issues, Testing, Security & Privacy checklist, Clean Architecture checklist, Screenshots, Reviewer notes.
- [ ] No sections missing.
- [ ] Change type checkboxes: bug fix, feature, breaking, refactor, chore, docs — all present.
- [ ] Clean Architecture checklist includes: no Firebase in domain, no business logic in screen, build_runner run after changes.
- [ ] Security checklist includes: no secrets in code, dependency scan.
- [ ] Instructions are clear: "use N/A where not applicable."
- [ ] Template is professional — no AI-signature footers.

### 12.4 `setup.sh` (Linux/macOS)
- [ ] Installs Flutter dependencies: `flutter pub get`.
- [ ] Runs code generation: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] Installs functions dependencies: `npm install` in `functions/`.
- [ ] Runs build_runner correctly — confirm `--delete-conflicting-outputs` flag is used.
- [ ] Handles missing tools gracefully (flutter not in PATH → useful error message, not cryptic failure).
- [ ] Does NOT install Flutter itself (that's the developer's responsibility) — just documents the requirement.
- [ ] Flutter version pinning: does it check or enforce the Flutter version?
- [ ] No hardcoded paths (e.g., `/home/username/flutter`).
- [ ] `set -e` or `set -euo pipefail` at top (fail fast on error).
- [ ] Does it seed test data? CLAUDE.md mentions `./dev.sh --emulator-only` for tests — does `setup.sh` do anything with emulators?

### 12.5 `dev.sh` (Linux/macOS)
- [ ] Flags supported: `--web`, `--prod`, `--emulator-only` (per CLAUDE.md).
- [ ] `--emulator-only`: starts Firebase emulators but NOT Flutter.
- [ ] `--web`: runs `flutter run -d chrome`.
- [ ] `--prod`: sets `USE_EMULATOR=false`.
- [ ] Default (no flags): starts emulators + `flutter run` (Android).
- [ ] Emulator startup command includes all four services: auth, firestore, functions, database.
- [ ] Checks if emulators are already running before starting again.
- [ ] Background process management: emulators in background, Flutter in foreground.
- [ ] Cleanup on exit: `trap` to kill emulators when script exits.
- [ ] Correct emulator ports used in `--dart-define` passed to Flutter.

### 12.6 `setup.ps1` / `dev.ps1` (Windows)
- [ ] Functionally equivalent to `.sh` counterparts.
- [ ] PowerShell-appropriate error handling (`$ErrorActionPreference = "Stop"`).
- [ ] Same flags supported.
- [ ] Cross-check: do the Windows scripts match the Linux scripts in behavior?

### 12.7 `logs.sh`
- [ ] What does it do? (Tails debug log files.)
- [ ] Paths used match actual log file locations (`database-debug.log`, `firestore-debug.log`, `pubsub-debug.log` at repo root).
- [ ] Is it useful / documented anywhere?

### 12.8 `functions/package.json` Scripts
- [ ] `lint`: runs ESLint on `src/` (not `lib/`).
- [ ] `build`: runs `tsc` — confirm it also compiles before serve/deploy.
- [ ] `serve`: `npm run build && firebase emulators:start --only functions`.
- [ ] `deploy`: `firebase deploy --only functions` — runs `predeploy` hooks (lint + build).
- [ ] `test`: `jest --config jest.config.js` (unit only).
- [ ] `test:embedding`: `jest --config jest.integration.config.js` (integration only).
- [ ] `predeploy` hooks: lint + build run automatically before deploy (in `firebase.json`).
- [ ] `engines.node` matches CI Node version (`24`).

### 12.9 Version Consistency Matrix
Create this table for the review:

| Component | Local dev | CI (ci.yml) | Build (build.yml) | package.json |
|-----------|-----------|-------------|-------------------|--------------|
| Flutter | ? | 3.41.7 | 3.41.6 | N/A |
| Java | ? | 21 | 17 | N/A |
| Node | ? | 24 | N/A | 24 |
| Firebase CLI | ? | ? | N/A | ? |

Discrepancies in this matrix are HIGH-severity findings.

---

## Files to Read in Full

1. `.github/workflows/ci.yml`
2. `.github/workflows/build.yml`
3. `.github/pull_request_template.md`
4. `setup.sh`
5. `dev.sh`
6. `logs.sh`
7. `functions/package.json`

---

## Expected Findings Categories

- Flutter version mismatch between ci.yml and build.yml (HIGH)
- Java version mismatch between ci.yml and build.yml (MEDIUM)
- No `set -euo pipefail` in shell scripts (MEDIUM)
- No trap/cleanup for emulator processes in dev.sh (MEDIUM)
- build_runner missing `--delete-conflicting-outputs` (MEDIUM)
- Android build missing `google-services.json` injection from GitHub Secrets (HIGH)
- CI not caching pub cache (LOW — performance)
- `--dart-define=USE_EMULATOR=false` not set for web build (HIGH if deploying to prod)
- CI emulator wait uses `sleep` not health check (MEDIUM)

---

## Output

Write findings to `reviews/ch12_cicd_scripts.md` including the version consistency matrix.
