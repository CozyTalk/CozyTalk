# CI Plan

## Do I need CI?

Yes. `.github/workflows/` existed but was empty. The effect:
- Tests break silently — 31 unit tests run locally but nothing enforces them on PRs
- Lint/format violations accumulate — ESLint and `flutter_lints` are configured but never enforced automatically
- Build breakage goes undetected — `flutter analyze` passes on code that fails to compile due to Gradle or plugin issues
- No coverage tracking — CLAUDE.md requires >80% domain layer coverage with nothing to measure it

Everything needed for CI was already installed (jest infra, `flutter_lints`, ESLint, both Android/Web build targets). It just wasn't wired up.

---

## What Was Added

Two GitHub Actions workflows: `.github/workflows/ci.yml` and `.github/workflows/build.yml`.

### `ci.yml` — quality gate

Triggers on every push to `main` and every PR targeting `main`.

**Job: `flutter-quality`**

| Step | What it catches |
|---|---|
| `build_runner build` | Contributors who edit `@freezed`/`@riverpod` classes but forget to regenerate — stale generated files cause compile errors |
| `dart format --set-exit-if-changed` | Unformatted Dart — eliminates style-only review comments |
| `flutter analyze` | Type errors, deprecated API usage, lint rule violations |
| `flutter test --coverage` | Regressions in any of the 31 unit tests; produces `coverage/lcov.info` |
| Codecov upload | Tracks coverage trend over time; posts a coverage diff comment on each PR |

Java 17 (temurin) is included because the Flutter toolchain needs it even for analyze and test.

**Job: `functions-quality`**

| Step | What it catches |
|---|---|
| `npm run lint` | ESLint violations in TypeScript Cloud Functions |
| `npm run build` | TypeScript compilation errors |

### `build.yml` — compile verification

Triggers on PRs targeting `main`. Skipped automatically for docs-only PRs (`**.md` changes) via `paths-ignore`.

**Job: `build-android`** — `flutter build apk --debug`  
**Job: `build-web`** — `flutter build web`

These catch errors that `flutter analyze` misses: Gradle misconfigurations, missing native plugin registrations, web renderer incompatibilities.

The web build job omits Java setup since the web toolchain doesn't need it, keeping it faster.

---

## Secrets Required

None. The Codecov GitHub App is installed on the CozyTalk organization, so the upload step authenticates automatically — no `CODECOV_TOKEN` secret is needed.

---

## What Is Not Included (and Why)

| Excluded | Reason |
|---|---|
| Firebase Functions auto-deploy on merge to `main` | No staging environment — automatic prod deploys are risky without one. Deploy stays manual via `npm run deploy` |
| Android release APK | Requires signing keystore and `key.properties` secrets. Out of scope until a release process is defined |
| Functions unit tests | jest is installed but there are zero test files. Add tests first; CI will pick them up automatically with no workflow changes needed |
| Flutter integration tests | `integration_test` dependency not added yet |
| Dependabot | Worth adding separately as a one-line config change |

---

## Verification

1. Break a Flutter test → `flutter-quality` job fails on PR
2. Commit unformatted Dart → `dart format` step fails
3. Introduce a TypeScript error in `functions/src/` → `functions-quality` job fails
4. Submit a docs-only PR (only `.md` changes) → `build.yml` is skipped, `ci.yml` still runs
5. Merge a clean PR → all jobs pass, Codecov comment appears on the PR
