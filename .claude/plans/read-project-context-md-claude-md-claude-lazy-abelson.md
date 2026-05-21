# Plan: Local Word Censoring with SQLite + Firebase Remote Config Feature Flag

## Context

CozyTalk has no content filtering today. Before a message is sent, it passes straight to `sendMessage` CF as plaintext (then encrypted server-side). The task adds a local, offline, multilingual (EN + TH) word censor that:
- Runs entirely on-device — no API calls
- Is gated by the `content_filtering_enabled` Firebase Remote Config boolean (default `false`)
- Uses SQLite (`sqflite` on Android, `sqflite_common_ffi_web` on Web) seeded from a bundled JSON
- Integrates at `ChatNotifier.sendMessage()` — zero changes to chat_screen.dart widget tree

This satisfies the project requirement: "At least one major feature must be gated behind a remote feature flag with a documented rollback plan."

---

## Architecture

New feature module: `lib/features/word_filter/` following existing Clean Architecture pattern.

The "ContentModerationService" concept from the spec maps to:
- **Domain**: `WordFilterRepository` (abstract) + `CensorText` usecase
- **Data**: `WordFilterDatasourceImpl` (SQLite reads + Remote Config check + censor logic) + `WordFilterDatabaseHelper` (raw sqflite operations) + `WordFilterRepositoryImpl`
- **Presentation**: `word_filter_provider.dart` (DI wiring, no Notifier needed — stateless service)

---

## New Files to Create

### 1. `apps/mobile/assets/banned_words.json`
Seed file bundled in the APK/web bundle.
```json
{
  "en": ["badword1", "badword2", "badword3"],
  "th": ["คำหยาบ1", "คำหยาบ2", "คำหยาบ3"]
}
```

### 2. Domain layer (pure Dart, zero imports)

**`lib/features/word_filter/domain/entities/banned_word.dart`**
```dart
class BannedWord {
  const BannedWord({required this.word, required this.language});
  final String word;
  final String language;
}
```

**`lib/features/word_filter/domain/repositories/word_filter_repository.dart`**
```dart
abstract class WordFilterRepository {
  Future<String> censorText(String text);
}
```

**`lib/features/word_filter/domain/usecases/censor_text.dart`**
```dart
class CensorText {
  const CensorText(this._repository);
  final WordFilterRepository _repository;
  Future<String> call(String text) => _repository.censorText(text);
}
```

### 3. Data layer

**`lib/features/word_filter/data/models/banned_word_model.dart`**
- `@freezed` DTO with `word` and `language` fields
- `fromJson(Map<String, dynamic>)` + `toEntity() → BannedWord`

**`lib/features/word_filter/data/datasources/word_filter_database_helper.dart`** (DatabaseHelper)
- `initialize()` static method: sets `databaseFactory = databaseFactoryFfiWeb` when `kIsWeb`
- `get database` lazy getter — opens `word_filter.db` on first access
- `onCreate`: creates `banned_words(id INTEGER PK AUTOINCREMENT, word TEXT NOT NULL, language TEXT NOT NULL)` + `CREATE INDEX idx_language ON banned_words(language)`
- `insertWordsBatch(List<Map<String,String>> words)` — uses `batch.insert()` for efficient bulk insert
- `getWordsByLanguage(String language)` → `List<Map<String,dynamic>>`

**`lib/features/word_filter/data/datasources/word_filter_datasource.dart`** (ContentModerationService)

Abstract `WordFilterDatasource`:
```dart
abstract class WordFilterDatasource {
  Future<String> censorText(String text);
  Future<void> seedIfNeeded();
}
```

`WordFilterDatasourceImpl`:
- Constructor: `(WordFilterDatabaseHelper dbHelper, FirebaseRemoteConfig remoteConfig)`
- `static const _keyDbSeeded = 'db_seeded'` — SharedPreferences guard
- `List<String>? _enWords, _thWords` — in-memory cache, populated once
- `bool _initialized = false`
- `seedIfNeeded()`: checks `prefs.getBool(_keyDbSeeded)`, if false → loads `assets/banned_words.json` via `rootBundle.loadString` → batch-inserts → sets flag
- `_initWords()`: idempotent; calls `seedIfNeeded()` then fetches all rows from SQLite into `_enWords`/`_thWords`
- `censorText(String text)`:
  1. `if (!remoteConfig.getBool('content_filtering_enabled')) return text;`
  2. `await _initWords()`
  3. English: split on spaces, map each token case-insensitively, replace matches with `'*' * token.length`
  4. Thai: for each word in `_thWords`, `result.replaceAll(word, '*' * word.length)` (substring scan)
  5. Return result

```dart
// ROLLBACK PLAN:
// If content filtering causes false positives or performance issues:
// 1. Go to Firebase Remote Config console
// 2. Set content_filtering_enabled = false
// 3. Publish — change propagates to all active clients within ~60 seconds
// 4. No app store release required
```

**`lib/features/word_filter/data/repositories/word_filter_repository_impl.dart`**
- Delegates `censorText` to `WordFilterDatasourceImpl`

### 4. Presentation layer

**`lib/features/word_filter/presentation/providers/word_filter_provider.dart`**
```dart
final _wordFilterDatasourceProvider = Provider((ref) =>
    WordFilterDatasourceImpl(WordFilterDatabaseHelper(), FirebaseRemoteConfig.instance));

final _wordFilterRepositoryProvider = Provider((ref) =>
    WordFilterRepositoryImpl(ref.watch(_wordFilterDatasourceProvider)));

final censorTextProvider = Provider((ref) =>
    CensorText(ref.watch(_wordFilterRepositoryProvider)));
```

### 5. `docs/features/word_filter.md`
Full feature doc: schema, Remote Config flag, rollback plan, censor algorithm (EN/TH), seeding flow, provider wiring.

---

## Files to Modify

### `apps/mobile/pubspec.yaml`
Add under `dependencies`:
```yaml
sqflite: ^2.3.3
sqflite_common_ffi_web: ^0.4.3
firebase_remote_config: ^5.1.5
```
Add to `assets` section:
```yaml
- assets/banned_words.json
```

### `apps/mobile/web/index.html`
Add before `</body>` (required by sqflite_common_ffi_web for WASM):
```html
<script src="sqlite3.wasm" type="application/wasm"></script>
```
Copy `sqlite3.wasm` to `web/` from the sqflite_common_ffi_web package assets.

### `apps/mobile/lib/main.dart`
In `main()`, after `Firebase.initializeApp(...)`:
```dart
// Remote Config: fetch with 1-hour cache, activate cached values
final remoteConfig = FirebaseRemoteConfig.instance;
await remoteConfig.setConfigSettings(RemoteConfigSettings(
  fetchTimeout: const Duration(seconds: 10),
  minimumFetchInterval: const Duration(hours: 1),
));
await remoteConfig.setDefaults({'content_filtering_enabled': false});
await remoteConfig.fetchAndActivate();

// SQLite: web-compatible initialization
await WordFilterDatabaseHelper.initialize();
```

### `apps/mobile/lib/features/chat/presentation/providers/chat_provider.dart`
Add private provider near the top (alongside existing `_sendMessageProvider`):
```dart
final _censorTextProvider = Provider((ref) => ref.watch(censorTextProvider));
```
Modify `ChatNotifier.sendMessage()`:
```dart
Future<void> sendMessage(String text) async {
  if (state.isSending) return;
  state = state.copyWith(isSending: true);
  try {
    final censored = await ref.read(_censorTextProvider).call(text); // NEW
    await ref.read(_sendMessageUsecaseProvider)(state.sessionId!, censored); // was: text
  } catch (e) {
    state = state.copyWith(error: e.toString(), isSending: false);
  } finally {
    state = state.copyWith(isSending: false);
  }
}
```

### `PROJECT_CONTEXT.md`
- Tech stack table: add `sqflite`, `firebase_remote_config` rows
- Test coverage table: update Flutter test count (580 → ~605)

### `CLAUDE.md` §4
Update Flutter test count comment.

---

## Tests to Create

**`test/features/word_filter/`** — mirror source structure:

| File | What it tests |
|------|--------------|
| `domain/entities/banned_word_test.dart` | Construction, field equality |
| `domain/usecases/censor_text_test.dart` | Forwards arg, returns result, propagates exception |
| `domain/shared_fakes.dart` | `FakeWordFilterRepository` (call tracking, configurable return) |
| `data/models/banned_word_model_test.dart` | `fromJson` full/null/unknown, `toEntity()` |
| `data/repositories/word_filter_repository_impl_test.dart` | Delegates to datasource, call count |
| `presentation/providers/word_filter_provider_test.dart` | `censorTextProvider` resolves, calls fake repo |

Tests follow existing fake pattern — no Firebase SDK, no mockito, fresh fake per `setUp`.

Estimated new test count: ~25 tests → Flutter total: ~605.

---

## Verification

1. `cd apps/mobile && flutter pub get` — no conflicts
2. `dart run build_runner build --delete-conflicting-outputs` — generates `banned_word_model.freezed.dart`
3. `flutter test` — all 605 tests pass
4. `flutter analyze` — zero warnings
5. Manual test (emulator):
   - `content_filtering_enabled = false` → send "badword1" → message appears uncensored
   - Set `content_filtering_enabled = true` in Remote Config → relaunch → send "badword1" → message shows `"********"`
   - Send a clean message → unchanged
   - Restart app → `db_seeded` flag prevents re-seeding (verify via log or test)
6. Web: `flutter run -d chrome` — SQLite initializes via WASM, filtering works identically
