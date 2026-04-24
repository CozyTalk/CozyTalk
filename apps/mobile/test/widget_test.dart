import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/hello/presentation/providers/hello_provider.dart';
import 'package:mobile/features/hello/presentation/screens/hello_screen.dart';

class _FakeHelloNotifier extends HelloNotifier {
  @override
  HelloState build() => const HelloState();

  @override
  Future<void> callHello(String message) async {}
}

Widget _buildApp() => ProviderScope(
      overrides: [
        helloNotifierProvider.overrideWith(_FakeHelloNotifier.new),
      ],
      child: const MaterialApp(home: HelloScreen()),
    );

void main() {
  testWidgets('HelloScreen renders input and send button', (tester) async {
    await tester.pumpWidget(_buildApp());

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Send to server'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('HelloScreen does not submit when input is empty', (tester) async {
    await tester.pumpWidget(_buildApp());

    await tester.tap(find.text('Send to server'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
