# Feature: word_filter

Client-side profanity filter. Loads a banned word list from a bundled JSON asset into a SQLite database on first use, then exposes a stateless `CensorText` use case that replaces matched words with asterisks. Entirely gated by a Firebase Remote Config boolean flag.

## File Map

```
features/word_filter/
├── domain/
│   ├── entities/banned_word.dart
│   ├── repositories/word_filter_repository.dart  abstract WordFilterRepository
│   └── usecases/censor_text.dart                 CensorText — stateless; returns censored string
├── data/
│   ├── datasources/
│   │   ├── word_filter_datasource.dart            WordFilterDatasourceImpl
│   │   └── word_filter_database_helper.dart       SQLite helper (sqflite)
│   ├── models/banned_word_model.dart
│   └── repositories/word_filter_repository_impl.dart
└── presentation/
    └── providers/word_filter_provider.dart
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `censorTextProvider` | `Provider<CensorText>` | stateless service; consume with `ref.read` |
| `wordFilterRepositoryProvider` | `Provider<WordFilterRepository>` | shared repository; consumed by `censorTextProvider` |

No `Notifier` — this is a stateless service with no UI state.

## Key Behavior

- **Asset**: `assets/banned_words.json` — bundled word list seeded into SQLite on first launch
- **SQLite**: `WordFilterDatabaseHelper` (sqflite) manages the local DB; seeding is idempotent and guarded by a `SharedPreferences` flag to avoid re-seeding on every launch
- **Remote Config gate**: `content_filtering_enabled` boolean flag — when `false`, `CensorText` returns the input string unchanged (no-op)
- **No Notifier**: call `ref.read(censorTextProvider)(text)` wherever text censoring is needed (e.g. in `ChatDatasourceImpl` before sending, or in message rendering)

## Usage

```dart
// In a datasource or widget
final censor = ref.read(censorTextProvider);
final safe = censor(userInput);
```

The Remote Config flag check happens inside `WordFilterDatasourceImpl` on every call — no restart required when the flag toggles.
