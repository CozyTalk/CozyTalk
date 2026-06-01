# Admin Feature

**Entry point:** `lib/features/admin/admin.dart`  
**Presentation layer:** `lib/features/admin/presentation/providers/admin_provider.dart`  
**Screens:** `lib/screens/admin_console_screen.dart`, `lib/screens/admin_report_detail_screen.dart`, and related tabs

---

## Architecture

```
features/admin/
├── domain/
│   ├── entities/       AdminDashboardStats, AdminReport, AdminBanRecord, AdminUser
│   ├── repositories/   AdminRepository (abstract)
│   └── usecases/       GetDashboardStats, WatchReports, ResolveReport, GetChatLogUrl,
│                       WatchUsers, BanUser, UnbanUser
├── data/
│   ├── models/         AdminDashboardStatsModel, AdminReportModel, AdminUserModel, AdminBanRecordModel
│   ├── datasources/    AdminDatasourceImpl
│   └── repositories/   AdminRepositoryImpl
└── presentation/
    └── providers/      AdminDashboardNotifier, AdminReportsNotifier, AdminUsersNotifier
```

---

## Providers

| Provider | Class | State | Notifier |
|---|---|---|---|
| `adminDashboardProvider` | `AsyncNotifierProvider` | `AsyncValue<AdminDashboardStats>` | `AdminDashboardNotifier` |
| `adminReportsProvider` | `NotifierProvider` | `AdminReportsState` | `AdminReportsNotifier` |
| `adminUsersProvider` | `NotifierProvider` | `AdminUsersState` | `AdminUsersNotifier` |

---

## AdminReportsState

```dart
class AdminReportsState {
  final AdminReportsStatus status;  // idle | loading | loaded | error
  final List<AdminReport> reports;
  final bool isSubmitting;
  final String? error;
  final String? actionError;
  final String? chatLogUrl;         // populated after getChatLogUrl() succeeds
}
```

**Key notifier methods:**

- `resolveReport(reportId, {action, note})` — calls `adminResolveReport` CF; sets `isSubmitting` guard
- `getChatLogUrl(reportId) → Future<String?>` — calls `adminGetChatLog` CF; stores URL in `state.chatLogUrl` AND returns it directly to the caller. The dual return lets the detail screen `await` the URL to fetch the transcript JSON without a separate `ref.listen`.

---

## AdminUsersState

```dart
class AdminUsersState {
  final AdminUsersStatus status;   // idle | loading | loaded | error
  final List<AdminUser> users;
  final bool isSubmitting;
  final String? error;
  final String? actionError;
}
```

**Key notifier methods:**

- `banUser({uid, reason, duration, note?, reportId?})` — calls `adminBanUser` CF; sets `actionError` on failure **and re-throws** so callers can show an error toast
- `unbanUser(uid)` — calls `adminUnbanUser` CF; sets `actionError` on failure **and re-throws** so callers can show an error toast

---

## Key Behaviour Notes

**Unban flow** — `AdminBanDetailScreen` is a `StatefulWidget` that holds `_isUnbanning: bool`. When the admin confirms unban, the screen stays open with a spinner on the button while `onUnban` (typed `Future<void> Function(AdminBanDetailSubject)?`) awaits the `adminUnbanUser` CF. On success, `AdminConsoleScreen` pops the detail screen and shows `"<name> has been unbanned"` — at that point the `watchUsers()` stream has already emitted the updated snapshot, so the banned list is stale-free on return. On failure, `AdminBanDetailScreen` resets `_isUnbanning` via `finally` (button re-enabled for retry) and `AdminConsoleScreen` shows a red `"Failed to unban <name>"` error toast via `OverlayEntry` (appears above any open dialog/screen).

**Ban modal (Users tab)** — `AdminBanModal` is a 2-step centered dialog (`showDialog`, not a bottom sheet). Step 1 is multi-select: the admin may choose any combination of `kBanReasons` (`'Harassment or Bullying'`, `'Spam & Scams'`, `'Exposing private identifying information'`, `'Others'`). Selecting `'Others'` reveals a free-text field; Next is disabled until the field is non-empty. All selected reasons are joined with `', '` into a single string passed to `banUser`. Step 2 selects duration and shows a confirmation summary. Tapping Confirm Ban shows a loading spinner in the button and disables navigation until the CF call resolves. On success the dialog closes and shows `"<name> has been banned"`. On failure the dialog resets to the interactive state (loading cleared, admin can retry) and a red `"Failed to ban <name>"` toast appears via `OverlayEntry` above the dialog. The barrier is non-dismissible while loading.

**Report count per user** — computed in `AdminConsoleScreen.build()` by iterating `reportsState.reports` and building a `Map<String, int>` keyed by `reportedUserId`. Zero extra Firestore queries; the reports stream is already loaded.

**`getChatLogUrl` dual return** — `AdminReportsNotifier.getChatLogUrl` was changed from `Future<void>` to `Future<String?>`. The URL is written to `state.chatLogUrl` (for any provider listeners) and also returned to the awaiting caller. This lets `AdminReportDetailScreen._fetchAndShowChatLog()` get the URL in one step.

**Chat transcript fetch** — after getting the signed URL, `AdminReportDetailScreen` fetches the JSON content via `http.get` and shows a `_ChatTranscriptSheet` bottom sheet. Format: `{ reportId, sessionId, exportedAt, messages: [{id, senderId, displayName, text, timestamp}] }`.

**Image fullscreen** — evidence images in `AdminReportDetailScreen` are loaded with `Image.network`. Tapping any image opens a fullscreen `Dialog` with `InteractiveViewer` (pinch-to-zoom).

---

## Seed Script

`tools/seed-admin-data.js` — populates the emulator with 1 admin, 6 users, 6 reports.

```bash
# emulators must be running first
node tools/seed-admin-data.js
# or from functions/:
npm run seed:admin
```

Expected dashboard: **4 pending · 2 online · 2 banned**
