# CozyTalk

Anonymous 1-on-1 stranger chat — Flutter (Android + Web) + Firebase.

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | 3.x+ | [flutter.dev](https://docs.flutter.dev/get-started/install) |
| Node.js | 20+ | [nodejs.org](https://nodejs.org) |
| firebase-tools | latest | `npm i -g firebase-tools` |

You also need to be invited to the `cozytalk-5d984` Firebase project before running against production.

---

## Quick start

**1. Install everything**

```bash
./setup.sh
```

Installs Flutter packages, runs code generation (Freezed + Riverpod), and installs Cloud Functions dependencies.

**2. Log into Firebase** *(first time only)*

```bash
firebase login
```

**3. Start developing**

```bash
./dev.sh              # emulators + Flutter on Android
./dev.sh --web        # emulators + Flutter on Chrome
./dev.sh --prod       # Flutter → live Firebase (Android)
./dev.sh --prod --web # Flutter → live Firebase (Chrome)
```

`dev.sh` starts the Firebase emulators in the background, waits until they're ready, then launches Flutter. `Ctrl+C` shuts everything down cleanly.

---

## Emulator UI

When running with emulators, the Firebase Emulator UI is available at:

```
http://127.0.0.1:4000
```

| Service | Port |
|---|---|
| Emulator UI | 4000 |
| Auth | 9099 |
| Functions | 5001 |

---

## Manual commands

If you prefer to run things yourself:

```bash
# ── Flutter app ─────────────────────────────────────────────────────────────
cd apps/mobile

flutter pub get
dart run build_runner build --delete-conflicting-outputs  # after editing @freezed / @riverpod
flutter run                                                # Android
flutter run -d chrome                                      # Web
flutter run --dart-define=USE_EMULATOR=false               # against production
flutter test

# ── Cloud Functions ──────────────────────────────────────────────────────────
cd functions

npm install
npm run build    # compile TypeScript
npm run serve    # start local emulators (ports 5001 + 9099)
npm run lint
npm run deploy   # deploy to Firebase (runs lint + build first)
```

---

## Project layout

```
apps/mobile/   Flutter app (Android + Web)
functions/     Firebase Cloud Functions (TypeScript)
packages/      Shared packages (reserved)
tools/         CLI tools (reserved)
```

See [`CLAUDE.md`](./CLAUDE.md) for architecture details, code conventions, and the full feature guide.
