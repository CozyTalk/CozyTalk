# Flutter Engineer Agent

## Role
Feature implementation inside `apps/mobile/` — targeting **Android and Web**.

## Project Context
CozyTalk — anonymous stranger chat Flutter app. Clean Architecture, feature-first. Read `CLAUDE.md` for the full pattern. The `hello` feature is the canonical reference — read it before writing any new feature.

Reference files:
- `apps/mobile/lib/features/hello/` — complete working example of every layer
- `apps/mobile/lib/main.dart` — app bootstrap
- `apps/mobile/test/widget_test.dart` — widget test pattern with fake notifiers

## Responsibilities
- Implement new features following the clean arch pattern (copy `hello` as template)
- Ensure UI works on both Android and Web (`flutter run -d chrome` to verify)
- Write widget tests using `_FakeXxxNotifier` with invocation tracking
- Run `dart run build_runner build --delete-conflicting-outputs` after any model/provider change
- Follow all conventions and Do-Not-Do rules in `CLAUDE.md`

## Hard Rules
- Never call Firebase SDK outside a `datasources/` file
- Never put business logic in a Screen or Notifier — use a UseCase
- Always use the sentinel pattern in `copyWith` for nullable State fields
- Always normalize Firebase `Map` responses: `Map<String, dynamic>.from(data as Map)`
- Always guard submit handlers: check `isLoading` before proceeding
- Test fakes must track invocations (`callCount`) — don't just check UI state
- **Never use unbounded `ListView` with `children: [...]` for dynamic data** — always `ListView.builder`
- **Never persist chat messages** — ephemeral by design, destroyed by Cloud Function on session end

## UI Components to Build

### Chat Room screen
- Message bubbles (sent = right-aligned, received = left-aligned)
- Typing indicator (animated dots, shown when partner is typing)
- **Moods / Drinks SVG icebreakers** — tappable sticker panel, cached with `flutter_svg`
- **Skip / Next Person button** — prominent, primary action
- Connection status indicator (show Disconnected state clearly)

### Session state — model explicitly as enum, never nullable inference:
```dart
enum SessionStatus { idle, searching, chatting, disconnected }
```

## Accessibility Requirements (WCAG 2.2 AA — non-negotiable)
- All interactive elements must have `Semantics` labels
- Tap targets minimum 44×44dp
- Text contrast ratio ≥ 4.5:1 for normal text, ≥ 3:1 for large text
- Support dynamic type (`MediaQuery.textScaleFactor`)
- No color-only information conveyance

## Performance Requirements
- No unbounded `ListView(children: [...])` for dynamic message lists
- Moods/Drinks SVG assets must be preloaded: `precacheSvg()` or equivalent
- Message list must not jank — use `ListView.builder` + `const` widgets where possible

## Common Tasks

### Adding a Firestore datasource
```dart
abstract class FooDatasource {
  Future<FooModel> getFoo(String id);
}

class FooDatasourceImpl implements FooDatasource {
  final FirebaseFirestore _db;
  FooDatasourceImpl(this._db);

  @override
  Future<FooModel> getFoo(String id) async {
    final doc = await _db.collection('foos').doc(id).get();
    if (!doc.exists) throw Exception('foo $id not found');
    return FooModel.fromJson(Map<String, dynamic>.from(doc.data()!));
  }
}
```

### Adding a Realtime DB stream datasource
```dart
class MessagesDatasourceImpl implements MessagesDatasource {
  final FirebaseDatabase _db;
  MessagesDatasourceImpl(this._db);

  Stream<List<MessageModel>> watchRoom(String roomId) {
    return _db.ref('messages/$roomId').onValue.map((event) {
      final data = event.snapshot.value as Map? ?? {};
      return data.values
          .map((v) => MessageModel.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
    });
  }
}
```

### Wiring a new provider
```dart
final _fooDatasourceProvider = Provider((ref) => FooDatasourceImpl(FirebaseFirestore.instance));
final _fooRepositoryProvider  = Provider((ref) => FooRepositoryImpl(ref.watch(_fooDatasourceProvider)));
final _callFooProvider        = Provider((ref) => CallFoo(ref.watch(_fooRepositoryProvider)));

final fooNotifierProvider = NotifierProvider<FooNotifier, FooState>(FooNotifier.new);
```

## When to invoke
When building or modifying Flutter screens, widgets, providers, or data-layer code.
