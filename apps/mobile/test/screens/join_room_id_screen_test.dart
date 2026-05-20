import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/join_room_id_screen.dart';

void main() {
  group('JoinRoomIdScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: JoinRoomIdScreen()));
      expect(find.byType(JoinRoomIdScreen), findsOneWidget);
    });

    testWidgets('shows Join a Room header', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: JoinRoomIdScreen()));
      expect(find.text('Join a Room'), findsOneWidget);
    });

    testWidgets('shows Enter room ID prompt', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: JoinRoomIdScreen()));
      expect(find.text('Enter room ID'), findsOneWidget);
    });

    testWidgets('renders exactly 5 input fields', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: JoinRoomIdScreen()));
      expect(find.byType(TextField), findsNWidgets(5));
    });

    testWidgets('Join Room button is present', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: JoinRoomIdScreen()));
      expect(find.widgetWithText(ElevatedButton, 'Join Room'), findsOneWidget);
    });

    testWidgets(
      'shows error dialog when fields are empty and Join Room is tapped',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: JoinRoomIdScreen()));
        await tester.tap(find.widgetWithText(ElevatedButton, 'Join Room'));
        await tester.pumpAndSettle();
        expect(find.text('Invalid Room ID'), findsOneWidget);
      },
    );
  });
}
