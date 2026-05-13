import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/hello/presentation/providers/hello_provider.dart';
import 'package:mobile/features/hello/presentation/screens/hello_screen.dart';

class _FakeHelloNotifier extends HelloNotifier {
  int callCount = 0;

  @override
  HelloState build() => const HelloState();

  @override
  Future<void> callHello(String message) async {
    callCount++;
  }
}

void main() {
  testWidgets('HelloScreen renders input and send button', (tester) async {
    final fake = _FakeHelloNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [helloNotifierProvider.overrideWith(() => fake)],
        child: const MaterialApp(home: HelloScreen()),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Send to server'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('HelloScreen does not call callHello when input is empty', (
    tester,
  ) async {
    final fake = _FakeHelloNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [helloNotifierProvider.overrideWith(() => fake)],
        child: const MaterialApp(home: HelloScreen()),
      ),
    );

    await tester.tap(find.text('Send to server'));
    await tester.pump();

    expect(fake.callCount, 0);
  });

  testWidgets('HelloScreen calls callHello when input is non-empty', (
    tester,
  ) async {
    final fake = _FakeHelloNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [helloNotifierProvider.overrideWith(() => fake)],
        child: const MaterialApp(home: HelloScreen()),
      ),
    );

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.text('Send to server'));
    await tester.pump();

    expect(fake.callCount, 1);
  });
}
