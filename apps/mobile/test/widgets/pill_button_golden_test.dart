import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/pill_button.dart';

void main() {
  testWidgets('PillButton golden – Accept (green) variant', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PillButton(
              label: 'Accept',
              bgColor: const Color(0xFFDEF1C2),
              borderColor: const Color(0xFFDEF1C2),
              textColor: const Color(0xFF695959),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(PillButton),
      matchesGoldenFile('goldens/pill_button_accept.png'),
    );
  });

  testWidgets('PillButton golden – Decline (red) variant', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PillButton(
              label: 'Decline',
              bgColor: const Color(0xFFF6D4E5),
              borderColor: const Color(0xFFF6D4E5),
              textColor: const Color(0xFF695959),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(PillButton),
      matchesGoldenFile('goldens/pill_button_decline.png'),
    );
  });
}
