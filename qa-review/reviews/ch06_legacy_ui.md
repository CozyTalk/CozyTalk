# Chapter 6 — Legacy UI Screens & Shared Widgets QA Review

> Status: COMPLETE
> Reviewer: qa-agent-phase3
> Date: 2026-05-17

## Summary

Reviewed all 30 files in `apps/mobile/lib/screens/`, `apps/mobile/lib/dialogs/`, `apps/mobile/lib/shared/`, and `apps/mobile/lib/models/`. These are design-preview screens not yet wired to Clean Architecture features. Key results: **no Firebase SDK anywhere in legacy screens** — all screens use hardcoded in-memory data. No `print()` calls. No `ListView(children:)` violations. The admin screens (7 files) are dead code: they contain fully rendered mock UIs with no route entry point. The legacy chat and finding-room screens are UI stubs that simulate behavior with in-memory state and timers. Three medium-severity integration-gap findings and one model-quality finding documented below.

**Findings by severity:** HIGH 0 · MEDIUM 3 · LOW 2 · INFO 2

---

## Screen Inventory

| Screen / File | Status | Firebase Direct | Business Logic | `print()` | `ListView(children:)` | Notes |
|---|---|---|---|---|---|---|
| `home_screen.dart` (screens/) | Real UI | No | No | No | No | Full design-preview home with nav hub; 587 lines |
| `profile_screen.dart` (screens/) | Real UI | No | No | No | No | Read-only profile view with avatar; 385 lines |
| `profile_edit_screen.dart` (screens/) | Real UI | No | No | No | No | Edit form, hardcoded state; 391 lines |
| `notification_screen.dart` | Real UI | No | No | No | No | Hardcoded notification list; 318 lines |
| `blocked_screen.dart` | Real UI | No | No | No | No | Uses `models/friend.dart`; 232 lines |
| `friends_screen.dart` | Real UI | No | No | No | No | Full friends list with mock data; 529 lines |
| `friend_chat_screen.dart` | Real UI | No | No | No | No | In-memory DM UI; 540 lines |
| `chat_screen.dart` (screens/) | Real UI | No | In-screen | No | No | In-memory messages, local `ChatMessage` class, no CF calls; 650 lines |
| `group_chat_screen.dart` | Real UI | No | In-screen | No | No | In-memory group messages; similar structure to chat_screen |
| `dress_up_screen.dart` | Real UI | No | No | No | No | Avatar customization UI; 378 lines |
| `mood_screen.dart` | Real UI | No | No | No | No | Mood selection UI; 346 lines |
| `choose_room_type_screen.dart` | Real UI | No | No | No | No | Room type selector; 406 lines |
| `select_background_screen.dart` | Real UI | No | No | No | No | Background picker; 236 lines |
| `join_room_id_screen.dart` | Real UI | No | No | No | No | Room ID input; 235 lines |
| `finding_room_screen.dart` | Partial stub | No | Yes | No | No | Timer-based match simulation — not wired to CFs; 120 lines |
| `admin_console_screen.dart` | Real UI | No | In-screen | No | No | **Unreachable** — all hardcoded mock data; 907 lines |
| `admin_profile_screen.dart` | Real UI | No | No | No | No | **Unreachable** — mock admin profile; |
| `admin_users_tab.dart` | Real UI | No | No | No | No | **Unreachable** — hardcoded user list |
| `admin_reports_tab.dart` | Real UI | No | No | No | No | **Unreachable** — hardcoded reports list |
| `admin_report_detail_screen.dart` | Real UI | No | No | No | No | **Unreachable** — hardcoded report detail |
| `admin_banned_tab.dart` | Real UI | No | No | No | No | **Unreachable** — hardcoded ban list |
| `admin_ban_detail_screen.dart` | Real UI | No | No | No | No | **Unreachable** — hardcoded ban detail |
| `admin_shared.dart` | Real UI | No | No | No | No | `AdminReport`, `AdminUser`, `AdminBan` models — pure Dart |
| `widgets.dart` | Real UI | No | No | No | No | Misc reusable widgets using `Friend` model; 364 lines |
| `block_dialogs.dart` (screens/) | Real UI | No | No | No | No | Block confirm dialog |
| `remove_friend_dialog.dart` (screens/) | Real UI | No | No | No | No | Remove friend confirm dialog |
| `thought_bubble_dialog.dart` (screens/) | Real UI | No | No | No | No | Thought bubble display |
| `login_screen.dart` (screens/) | Real UI | No | No | No | No | **Dead** — `main.dart` uses `features/auth` version |
| `signup_screen.dart` (screens/) | Real UI | No | No | No | No | **Dead** — `main.dart` uses `features/auth` version |
| `friend_profile_dialog.dart` (screens/) | Real UI | No | No | No | No | Friend profile popup |
| `layered_avatar.dart` (shared/) | Real UI | No | No | No | N/A | Pure Flutter; renders overlays correctly |
| `avatar_overlay.dart` (shared/) | Real UI | No | No | No | N/A | Legacy `avatarProvider` backed by SharedPreferences — separate from `features/avatar` |
| `friend_message_popup.dart` (shared/) | Real UI | No | No | No | N/A | Overlay banner; pure Flutter; no Firebase |
| `user_profile.dart` (shared/) | Real UI | No | No | No | N/A | Hardcoded default username `'Somtum'` in notifier; in-memory only |
| `pill_button.dart` (shared/) | Real UI | No | No | No | N/A | Pure reusable button |
| `press_bounce_btn.dart` (shared/) | Real UI | No | No | No | N/A | Tap animation wrapper |
| `models/friend.dart` | Library | No | No | No | N/A | Hand-rolled model + copyWith; contains its own `ChatMessage` class |

---

## Findings

### F-001 — `finding_room_screen.dart` not integrated with real matchmaking CFs
- **Severity:** MEDIUM
- **File:** `apps/mobile/lib/screens/finding_room_screen.dart`
- **Category:** Missing Feature
- **Description:** `FindingRoomScreen` uses `Timer.periodic` to simulate a match after a fixed delay. It navigates to the legacy `ChatScreen` (also mock) after the timer fires. There is no connection to `MatchmakingNotifier`, `join1v1Pool`, or any Cloud Function. When `_useMainUI` is flipped to `true` and users navigate to `/finding-room`, they get a fake matching experience that never produces a real room.
- **Evidence:** `initState()` sets `_matchTimer = Timer.periodic(...)` with a simulated match; no provider subscriptions or CF calls.
- **Recommendation:** Before shipping `_useMainUI = true`, replace `FindingRoomScreen` with a screen that wraps `MatchmakingNotifier.join1v1Pool()` and watches `matchmakingNotifierProvider` for the `matched` state.

---

### F-002 — `shared/user_profile.dart` hardcodes default username `'Somtum'`
- **Severity:** MEDIUM
- **File:** `apps/mobile/lib/shared/user_profile.dart`
- **Category:** Bug / Design
- **Description:** `UserProfileNotifier.build()` returns `UserProfileState(username: 'Somtum', ...)`. Any screen that uses `userProfileProvider` without loading real user data will display `'Somtum'` as the username. This is a design-preview placeholder that will leak into production if `_useMainUI = true` is shipped without wiring `userProfileProvider` to `users/{uid}`.
- **Evidence:** `const UserProfileState({this.username = 'Somtum', ...})` in `user_profile.dart`.
- **Recommendation:** When integrating, replace the in-memory `UserProfileNotifier` with one that reads from `users/{uid}` via Firestore, or route screens to `profileNotifierProvider` directly.

---

### F-003 — `screens/login_screen.dart` and `screens/signup_screen.dart` are dead files
- **Severity:** MEDIUM
- **File:** `apps/mobile/lib/screens/login_screen.dart`, `apps/mobile/lib/screens/signup_screen.dart`
- **Category:** Style / Maintenance
- **Description:** `main.dart` imports `features/auth/presentation/screens/login_screen.dart` (the real CA implementation) and registers no route for the legacy versions in `screens/`. The `screens/login_screen.dart` and `screens/signup_screen.dart` are fully implemented UI files that are never imported or navigated to. They introduce naming confusion (both are named `LoginScreen` and `SignUpScreen`).
- **Evidence:** `main.dart` has no import referencing `screens/login_screen.dart`; the `features/auth` version is imported directly.
- **Recommendation:** Delete `screens/login_screen.dart` and `screens/signup_screen.dart`. If they contain UI patterns worth keeping, extract them into the features/auth screens directly.

---

### F-004 — `models/friend.dart` uses hand-rolled model instead of Freezed
- **Severity:** LOW
- **File:** `apps/mobile/lib/models/friend.dart`
- **Category:** Style / CA-Violation
- **Description:** `Friend` and `ChatMessage` (in this file) are hand-rolled models with manually written `copyWith()`. They are not `@freezed`. The project standard requires Freezed for all data models. Additionally, `models/friend.dart` defines a local `ChatMessage` class that shares a name with `features/chat/domain/entities/chat_message.dart`. If ever imported together, they will conflict.
- **Evidence:** `friend.dart` — manual `copyWith` with `const _sentinel = Object()` (correct sentinel pattern used manually, but still not Freezed).
- **Recommendation:** These models are legacy-only and not used in features/. No immediate action required. When integrating friends functionality, replace with `@freezed` models in a proper feature layer.

---

### F-005 — Admin screens are 900+ lines of dead unreachable UI
- **Severity:** LOW
- **File:** `apps/mobile/lib/screens/admin_console_screen.dart` and related
- **Category:** Maintenance
- **Description:** Seven admin screens contain a complete admin dashboard with hardcoded mock data (`AdminReport`, `AdminUser`, `AdminBan` structs in `admin_shared.dart`). None of these screens are registered in any route map in `main.dart`. There is no navigation path to any admin screen. All admin actions (ban, unban, resolve reports) operate on in-memory state only.
- **Evidence:** `main.dart` has no import or route entry for any `Admin*Screen`. Admin data is hardcoded (e.g., `AdminReport(id: 'r1', reporter: 'Somtum', ...)`).
- **Recommendation:** Either wire admin screens to real Firestore reads (behind an `isAdmin()` role check) before `_useMainUI = true`, or delete the dead files. Retain `admin_shared.dart` models only if they will be reused.

---

### F-006 — `shared/avatar_overlay.dart` defines a second `avatarProvider` separate from `features/avatar`
- **Severity:** INFO
- **File:** `apps/mobile/lib/shared/avatar_overlay.dart`
- **Category:** Style
- **Description:** `avatar_overlay.dart` defines `avatarProvider = NotifierProvider<AvatarNotifier, AvatarState>` backed by `SharedPreferences`. This is distinct from the `avatarDecorationNotifierProvider` in `features/avatar/`. The features/avatar notifier correctly syncs to this `avatarProvider` via `_syncToSharedProvider()` — so the shared provider is the rendering-state bridge. The naming is correct and the design is intentional.
- **Evidence:** `avatar_overlay.dart` exports `avatarProvider`; `features/avatar/presentation/providers/avatar_decoration_provider.dart` imports it for sync.
- **Recommendation:** None — this is the intended architecture. Document clearly in CLAUDE.md that `avatarProvider` (rendering state) is separate from `avatarDecorationNotifierProvider` (persistence).

---

### F-007 — `screens/chat_screen.dart` (legacy) messages are plaintext in-memory
- **Severity:** INFO
- **File:** `apps/mobile/lib/screens/chat_screen.dart`
- **Category:** Design
- **Description:** The legacy chat screen defines its own in-memory `ChatMessage` model and stores messages in a list inside the widget state. Messages are plaintext strings — no encryption. This is expected for a design preview screen and is NOT connected to the `features/chat` implementation. No security risk: messages never leave the device and are destroyed when the widget is disposed.
- **Evidence:** `class ChatMessage { final String type; final String text; ... }` in `chat_screen.dart`; messages are appended to a local list.
- **Recommendation:** None for the legacy screen. When wiring the production UI to `features/chat`, use `ChatNotifier.sendMessage()` which calls the `sendMessage` CF (AES-256-GCM encrypted).

---

## What Is Working Well

- Zero Firebase SDK imports across all 30+ legacy files ✅
- Zero `print()` calls in any legacy file ✅
- Zero `ListView(children: [...])` violations — all lists use `ListView.builder` ✅
- No hardcoded credentials or admin UIDs in admin screens ✅
- `shared/layered_avatar.dart` is pure Flutter with correct overlay z-ordering ✅
- `shared/friend_message_popup.dart` and `press_bounce_btn.dart` are clean, reusable, side-effect-free ✅
- `models/friend.dart` correctly uses `_sentinel` pattern in hand-rolled `copyWith` — pattern is consistent even without Freezed ✅
- All admin screens use only in-memory data (no risk of bypassing real Firestore security rules) ✅
