import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/hello/domain/entities/hello_message.dart';
import 'package:mobile/features/hello/presentation/providers/hello_provider.dart';
import 'package:mobile/features/hello/presentation/screens/hello_screen.dart';

class _FakeHelloNotifier extends HelloNotifier {
  final HelloState _initial;
  int callHelloCount = 0;
  String? lastMessage;

  _FakeHelloNotifier({HelloState initial = const HelloState()})
    : _initial = initial;

  @override
  HelloState build() => _initial;

  @override
  Future<void> callHello(String message) async {
    callHelloCount++;
    lastMessage = message;
  }
}

Widget _buildHelloScreen(_FakeHelloNotifier fake) {
  return ProviderScope(
    overrides: [helloNotifierProvider.overrideWith(() => fake)],
    child: const MaterialApp(home: HelloScreen()),
  );
}

void main() {
  group('HelloScreen', () {
    testWidgets('renders the message input field', (tester) async {
      final fake = _FakeHelloNotifier();
      await tester.pumpWidget(_buildHelloScreen(fake));

      expect(find.widgetWithText(TextField, 'Type a message'), findsOneWidget);
    });

    testWidgets('renders the Send to server button', (tester) async {
      final fake = _FakeHelloNotifier();
      await tester.pumpWidget(_buildHelloScreen(fake));

      expect(find.text('Send to server'), findsOneWidget);
    });

    testWidgets('renders navigation buttons', (tester) async {
      final fake = _FakeHelloNotifier();
      await tester.pumpWidget(_buildHelloScreen(fake));

      expect(find.text('Test Matchmaking'), findsOneWidget);
      expect(find.text('Test avatar picker'), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when loading', (tester) async {
      final fake = _FakeHelloNotifier(
        initial: const HelloState(isLoading: true),
      );
      await tester.pumpWidget(_buildHelloScreen(fake));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error text when error is set', (tester) async {
      final fake = _FakeHelloNotifier(
        initial: const HelloState(error: 'server error'),
      );
      await tester.pumpWidget(_buildHelloScreen(fake));

      expect(find.textContaining('Error: server error'), findsOneWidget);
    });

    testWidgets('shows result message when result is set', (tester) async {
      final fake = _FakeHelloNotifier(
        initial: const HelloState(result: HelloMessage(message: 'Hello World')),
      );
      await tester.pumpWidget(_buildHelloScreen(fake));

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('send button is disabled when loading', (tester) async {
      final fake = _FakeHelloNotifier(
        initial: const HelloState(isLoading: true),
      );
      await tester.pumpWidget(_buildHelloScreen(fake));

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Send to server'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('calls callHello with trimmed text on submit', (tester) async {
      final fake = _FakeHelloNotifier();
      await tester.pumpWidget(_buildHelloScreen(fake));

      await tester.enterText(
        find.widgetWithText(TextField, 'Type a message'),
        '  hello  ',
      );
      await tester.tap(find.text('Send to server'));
      await tester.pump();

      expect(fake.callHelloCount, 1);
      expect(fake.lastMessage, 'hello');
    });

    testWidgets('does not call callHello when input is empty', (tester) async {
      final fake = _FakeHelloNotifier();
      await tester.pumpWidget(_buildHelloScreen(fake));

      await tester.tap(find.text('Send to server'));
      await tester.pump();

      expect(fake.callHelloCount, 0);
    });
  });
}
