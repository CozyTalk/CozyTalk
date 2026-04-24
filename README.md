# CozyTalk

A Flutter + Firebase app.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Node.js 24
- Firebase CLI: `npm install -g firebase-tools`

## Setup

**1. Install dependencies**

```bash
# Flutter app
cd apps/mobile
flutter pub get

# Cloud Functions
cd ../../functions
npm install
```

**2. Regenerate code**

```bash
cd apps/mobile
dart run build_runner build --delete-conflicting-outputs
```

**3. Log into Firebase**

You need to be invited to the `cozytalk-5d984` Firebase project first.

```bash
firebase login
```

## Run

By default the app runs against the **local emulator**. To run against production, pass `--dart-define=USE_EMULATOR=false`.

**With local emulators (default):**

```bash
# Terminal 1 — start emulators
cd functions
npm run serve

# Terminal 2 — run app
cd apps/mobile
flutter run
```

**Against production Firebase:**

```bash
cd apps/mobile
flutter run --dart-define=USE_EMULATOR=false
```
