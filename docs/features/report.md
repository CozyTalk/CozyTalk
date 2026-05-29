# Feature: report

In-session abuse reporting. Users can report a chat partner during or after a session, optionally attaching screenshots and context text. Images are uploaded to Firebase Storage; the `reportSession` CF validates participants, decrypts messages, and archives the chat log.

## File Map

```
features/report/
├── domain/
│   ├── entities/report_type.dart      ReportType enum: spam | harassment | inappropriateContent | other
│   │                                   each has wireValue (CF-serialized: 'inappropriate_content' etc.)
│   │                                   and displayName (user-facing label)
│   ├── repositories/report_repository.dart  abstract ReportRepository
│   └── usecases/submit_report.dart    SubmitReport
├── data/
│   ├── datasources/report_datasource.dart   ReportDatasourceImpl — uploads images → calls reportSession CF
│   └── repositories/report_repository_impl.dart
└── presentation/
    ├── providers/report_provider.dart        reportNotifierProvider
    └── screens/
        ├── report_sheet.dart                 DraggableScrollableSheet — shown from ChatScreen report button
        └── report_test_screen.dart           dev/test only
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `reportNotifierProvider` | `NotifierProvider<ReportNotifier, ReportState>` | form state + submission lifecycle |

## State

`ReportState` fields:

| Field | Type | Notes |
|---|---|---|
| `isSubmitting` | bool | loading guard; blocks re-entry during submit |
| `isSuccess` | bool | set to `true` after successful CF response |
| `error` | String? | error message from CF or Storage upload |
| `selectedType` | ReportType? | which category the user chose |
| `reason` | String | free-text reason, ≤500 chars (CF-enforced) |
| `contextText` | String | optional additional context, ≤2000 chars (CF-enforced) |
| `contextImagePaths` | List\<String\> | local file paths; max 5; uploaded to Storage before CF call |

Nullable fields use `_sentinel` pattern for `copyWith`.

## Notifier Methods

- `reset()` — clears all fields back to initial state
- `selectType(ReportType)` — sets `selectedType`
- `setReason(String)` — updates reason text
- `setContextText(String)` — updates context text
- `addImage(String path)` — appends path; no-op if already at 5 images
- `removeImage(int index)` — splices image list
- `submit({sessionId, reportedUserId})` — isSubmitting guard; requires `selectedType != null` and non-empty reason; uploads images to Storage; calls `reportSession` CF; sets `isSuccess` on success or `error` on failure

## Key Behavior

- Image paths are local device paths selected by the user. `ReportDatasourceImpl` uploads each to Firebase Storage (`reports/{uid}/{timestamp}_{filename}`) and collects the resulting download URLs before calling the CF.
- The CF (`reportSession`) validates that both `reporterId` and `reportedUserId` are actual participants of `sessionId`. Self-reporting is rejected.
- The report does NOT end the session — the caller (typically `report_sheet.dart`) calls `endSession` separately if the user wants to leave after reporting.
- `ReportType.wireValue` is what gets sent to the CF (`'spam'`, `'harassment'`, `'inappropriate_content'`, `'other'`).

## ReportType Enum

| Dart name | wireValue | displayName |
|---|---|---|
| `spam` | `'spam'` | Spam |
| `harassment` | `'harassment'` | Harassment |
| `inappropriateContent` | `'inappropriate_content'` | Inappropriate Content |
| `other` | `'other'` | Other |

## Integration

`report_sheet.dart` is a `DraggableScrollableSheet` shown via `showModalBottomSheet` from `ChatScreen` (triggered by the report button in the AppBar). It is not yet wired in `GroupChatScreen`.
