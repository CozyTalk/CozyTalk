import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/home/presentation/screens/home_screen.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('displays CozyTalk app bar title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      expect(find.text('CozyTalk'), findsOneWidget);
    });

    testWidgets('displays welcome text', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      expect(find.text('Welcome to CozyTalk'), findsOneWidget);
    });

    testWidgets('displays Start Chatting button', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      expect(find.text('Start Chatting'), findsOneWidget);
    });
  });
}
