# word_filter Feature

Local, offline, multilingual (EN + TH) word censor gated behind a Firebase Remote Config feature flag.

---

## Feature Flag

| Flag | Type | Default | Console path |
|------|------|---------|--------------|
| `content_filtering_enabled` | boolean | `false` | Firebase Console → Remote Config |

Remote Config is fetched at app startup with a **1-hour minimum fetch interval**. On network failure the cached/default value is used so the app boots normally.

### Rollback plan

If content filtering causes false positives or performance issues:
1. Go to Firebase Remote Config console
2. Set `content_filtering_enabled = false`
3. Publish — change takes effect on the next app launch (up to 1 hour after the previous fetch, per `minimumFetchInterval`)
4. No app store release required

---

## Architecture

```
features/word_filter/
├── domain/
│   ├── entities/banned_word.dart          ← {word, language}
│   ├── repositories/word_filter_repository.dart  ← censorText(String) → Future<String>
│   └── usecases/censor_text.dart
├── data/
│   ├── models/banned_word_model.dart      ← @freezed DTO, toEntity()
│   ├── datasources/
│   │   ├── word_filter_database_helper.dart  ← sqflite wrapper (non-web platforms)
│   │   └── word_filter_datasource.dart    ← ContentModerationService logic
│   └── repositories/word_filter_repository_impl.dart
└── presentation/
    └── providers/word_filter_provider.dart
```

---

## SQLite Schema

```sql
CREATE TABLE banned_words (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  word     TEXT NOT NULL,
  language TEXT NOT NULL,
  UNIQUE(word, language)
);
CREATE INDEX idx_language ON banned_words(language);
```

**Platform support:**
- **Android**: native sqflite — seeded once from JSON, then queried from SQLite
- **Web**: no SQLite; words loaded directly from `assets/banned_words.json` into memory on first use (`kIsWeb` branch in `_initWords()`)

### Seeding

`assets/banned_words.json` is bundled with the app:
```json
{
  "en": ["badword1", ...],
  "th": ["คำหยาบ1", ...]
}
```

On first call to `censorText()`, `seedIfNeeded()` loads the JSON and batch-inserts all rows. A `db_seeded` boolean in `SharedPreferences` prevents re-seeding on subsequent launches.

---

## Censor Algorithm

Words are loaded from SQLite into memory on first use (`_enWords`, `_thWords`), then cached for the app lifetime.

**English** — tokenise by spaces; compare each token case-insensitively; replace matches with `*` × token length.

**Thai** — no word boundaries; scan full text for each banned word via `String.replaceAll`; replace with `*` × word length.

If the flag is off, the original text is returned immediately with no DB access.

---

## Integration Point

`ChatNotifier.sendMessage()` in `chat/presentation/providers/chat_provider.dart`:
1. Reads `censorTextProvider` (a `CensorText` usecase backed by `wordFilterRepositoryProvider`)
2. Calls `await censorText(text)` to get the possibly-censored string
3. Passes the censored string to `SendMessage` usecase

The chat screen (`chat_screen.dart`) is unchanged — the widget tree and submit handler are not modified.

---

## Provider Wiring

```dart
// word_filter_provider.dart
final wordFilterRepositoryProvider = Provider<WordFilterRepository>(...);
final censorTextProvider = Provider<CensorText>(...);
```

`wordFilterRepositoryProvider` is public so tests can override it.

---

## Testing

Tests live in `test/features/word_filter/` mirroring the source tree.

| File | Covers |
|------|--------|
| `domain/entities/banned_word_test.dart` | Construction, field values |
| `domain/usecases/censor_text_test.dart` | Delegation, return, exception propagation |
| `domain/shared_fakes.dart` | `FakeWordFilterRepository` |
| `data/models/banned_word_model_test.dart` | `fromJson` all/unknown fields, `toEntity()` |
| `data/repositories/word_filter_repository_impl_test.dart` | Delegation to datasource fake |
| `presentation/providers/word_filter_provider_test.dart` | Provider override, usecase resolution |
