import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/select_background_screen.dart';

Widget _build({String roomType = '1v1'}) =>
    MaterialApp(home: SelectBackgroundScreen(roomType: roomType));

void main() {
  group('SelectBackgroundScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byType(SelectBackgroundScreen), findsOneWidget);
    });

    testWidgets('shows Select room type header', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.text('Select room type'), findsOneWidget);
    });

    testWidgets('shows all four location cards', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_build());
      await tester.pump();

      expect(find.text('Kao Tapu'), findsOneWidget);
      expect(find.text('Red Lotus Lake'), findsOneWidget);
      expect(find.text('The Sea of Cloud'), findsOneWidget);
      expect(find.text('Lumphini Park'), findsOneWidget);
    });

    testWidgets("Let's go! button is disabled before any selection", (
      tester,
    ) async {
      await tester.pumpWidget(_build());
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Let's go!"),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets("Let's go! button enables after selecting a location", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_build());
      await tester.pump();

      await tester.tap(find.text('Kao Tapu'));
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Let's go!"),
      );
      expect(btn.onPressed, isNotNull);
    });
  });
}
