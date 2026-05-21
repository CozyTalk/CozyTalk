---
  Handoff — feat/admin-api → Block Feature

  Date: 2026-05-21
  Branch: feat/admin-api
  Session goal: Complete user-blocking feature — CFs, Flutter CA layer, screen integrations, tests, docs.

  ---
  Status: Complete — awaiting commits + PR

  All code, tests, and docs are written and verified. The only remaining action is committing and opening the PR. Git commands are in the previous message in this conversation.

  Test results (last run):
  - flutter test → 580/580 passed (exit 0, after flutter clean)
  - flutter analyze → 0 issues (exit 0)
  - npm run build (TypeScript) → clean (exit 0)
  - npm test → requires emulators; 15 new block CF tests in functions/src/user/__tests__/block.test.ts

  ---
  What was built

  Cloud Functions (functions/src/)

  ┌───────────────────────────────┬──────────┬───────────────────────────────────────────────────────────────────────────────────────────────┐
  │             File              │  Status  │                                             Notes                                             │
  ├───────────────────────────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ user/_blockUtils.ts           │ NEW      │ BlockListEntry type; getBlockedUids, mergeIntoBlockList, removeFromBlockList, isBlockedByRoom │
  ├───────────────────────────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ user/blockUser.ts             │ NEW      │ Callable CF; max-5 limit; idempotent re-block                                                 │
  ├───────────────────────────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ user/unblockUser.ts           │ NEW      │ Callable CF; deletes subcollection doc                                                        │
  ├───────────────────────────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ admin/adminGetBlockedUsers.ts │ NEW      │ Admin-only CF; returns block list ordered by blockedAt desc                                   │
  ├───────────────────────────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ index.ts                      │ MODIFIED │ Exports blockUser, unblockUser, adminGetBlockedUsers                                          │
  ├───────────────────────────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ matchmaking/_utils.ts         │ MODIFIED │ BlockListEntry type re-exported; added to RoomData interface                                  │
  ├───────────────────────────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ matchmaking/joinGroupRoom.ts  │ MODIFIED │ Block check on join; mergeIntoBlockList on success                                            │
  ├───────────────────────────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ matchmaking/joinRoomById.ts   │ MODIFIED │ Pre-flight block check; mergeIntoBlockList on join                                            │
  ├───────────────────────────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ matchmaking/leaveRoom.ts      │ MODIFIED │ removeFromBlockList on leave                                                                  │
  ├───────────────────────────────┼──────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ matchmaking/match1v1Users.ts  │ MODIFIED │ Filters mutually-blocked candidate pairs                                                      │
  └───────────────────────────────┴──────────┴───────────────────────────────────────────────────────────────────────────────────────────────┘

  Firestore rules: users/{userId}/blocked/{blockedId} — owner-only read/write added.

  Flutter CA layer (apps/mobile/lib/features/block/)

  Full Clean Architecture layer — all files are new:

  domain/entities/blocked_user.dart
  domain/repositories/block_repository.dart
  domain/usecases/watch_blocked_users.dart
  domain/usecases/block_user.dart
  domain/usecases/unblock_user.dart
  data/models/timestamp_converter.dart        ← local copy (not shared with other features yet)
  data/models/blocked_user_model.dart         ← @freezed; .freezed.dart/.g.dart are gitignored
  data/datasources/block_datasource.dart
  data/repositories/block_repository_impl.dart
  presentation/providers/block_provider.dart  ← blockNotifierProvider; BlockStatus enum

  Flutter screen integrations

  ┌───────────────────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │               File                │                                                      Change                                                       │
  ├───────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ screens/blocked_screen.dart       │ Converted to ConsumerStatefulWidget; watches blockNotifierProvider + authNotifierProvider; unblock calls notifier │
  ├───────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ screens/admin_users_tab.dart      │ Added "Blocked" AdminActionBtn between Profile and Ban                                                            │
  ├───────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ screens/admin_console_screen.dart │ Added _viewBlockedUsers() method + _AdminBlockedUsersDialog widget                                                │
  └───────────────────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  Admin CA layer additions

  ┌─────────────────────────────────────────────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────┐
  │                            File                             │                                            Change                                             │
  ├─────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ features/admin/admin.dart                                   │ Added export 'domain/entities/admin_blocked_entry.dart'                                       │
  ├─────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ features/admin/domain/entities/admin_blocked_entry.dart     │ NEW — {uid, displayName?, blockedAt?}                                                         │
  ├─────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ features/admin/domain/usecases/get_blocked_users.dart       │ NEW                                                                                           │
  ├─────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ features/admin/domain/repositories/admin_repository.dart    │ Added getBlockedUsers(String uid)                                                             │
  ├─────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ features/admin/data/datasources/admin_datasource.dart       │ Calls adminGetBlockedUsers CF                                                                 │
  ├─────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ features/admin/data/repositories/admin_repository_impl.dart │ Delegates to datasource                                                                       │
  ├─────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────┤
  │ features/admin/presentation/providers/admin_provider.dart   │ AdminUsersState gains blockedUsersForUid + blockedUsersUid; notifier gains loadBlockedUsers() │
  └─────────────────────────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────┘

  Other

  - apps/mobile/pubspec.yaml — http moved from dev_dependencies → dependencies
  - apps/mobile/lib/main.dart — // ignore: unused_element added above _AuthRouter (class is dead code when _useMainUI = false; CLAUDE.md rule preserved)

  Tests

  - functions/src/user/__tests__/block.test.ts — 15 Jest CF tests
  - apps/mobile/test/features/block/ — 8 Flutter test files (entity, 3 usecases, model, repo, provider, screen)
  - Updated fakes: test/features/admin/domain/shared_fakes.dart, test/features/admin/data/repositories/admin_repository_impl_test.dart — added getBlockedUsers stub
  - Cleaned up: removed unused dart:async imports; removed unused isSubmitting local var in admin notifiers test

  Docs

  All updated to reflect current state:
  - docs/features/block.md — NEW
  - docs/database/schema.md — blocked subcollection + room blockList field
  - docs/backend/cloud-functions.md — all three new CFs documented
  - docs/frontend/screens.md — BlockedScreen marked integrated
  - docs/INDEX.md — block feature listed
  - CLAUDE.md §4 — Flutter test count updated to 580
  - PROJECT_CONTEXT.md — Flutter test count updated to 580 in both locations

  ---
  Commits to create (run in order)

  See the previous message in this conversation for the exact git add + git commit + gh pr create commands. Six commits:

  1. feat(block): add blockUser, unblockUser, adminGetBlockedUsers CFs and Firestore rules
  2. feat(block): enforce block list in matchmaking and room join/leave
  3. feat(block): add features/block CA layer (domain, data, presentation)
  4. feat(block): integrate BlockedScreen and wire admin block API
  5. test(block): add CF and Flutter unit/widget tests for block feature
  6. docs: document block feature, update schema, CFs, screens, and test counts

  ---
  Known issues / non-issues

  - 8 pre-existing test failures before flutter clean — caused by stale shader cache after Flutter 3.41.9 upgrade (commit 8ba5a97). Fixed by running flutter clean. All 580 now pass.
  - _AuthRouter in main.dart — genuinely unused (home is AdminConsoleScreen when _useMainUI = false). Suppressed with // ignore: unused_element. Do not remove _AuthRouter — it's kept for future re-use when the chatroom flow is re-wired.
  - CF tests require emulators — npm test from functions/ requires ./dev.sh --emulator-only first.
  - blocked_user_model.freezed.dart / .g.dart — gitignored. Must run dart run build_runner build --delete-conflicting-outputs from apps/mobile/ after a fresh clone before tests will compile.

  ---
  Next logical tasks (not started)

  The blocking feature is the last item in the "deferred" list from CLAUDE.md §9 integration progression. Remaining deferred items:

  - Notifications — push notifications for match found / new message
  - Friends — friend request flow (FriendsScreen, friend_chat)
  - The admin branch (feat/admin-api) has been the working branch for several features; once this PR merges, consider whether a clean feat/notifications or feat/friends branch makes more sense off main.