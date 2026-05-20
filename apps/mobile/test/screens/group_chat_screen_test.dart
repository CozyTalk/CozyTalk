import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/group_chat_screen.dart';
import 'package:mobile/shared/avatar_overlay.dart';
import 'package:mobile/shared/user_profile.dart';
import 'package:mobile/theme/app_routes.dart';

// ── Fakes ──────────────────────────────────────────────────────────────────────

class _FakeAvatarNotifier extends AvatarNotifier {
  final AvatarState _initial;

  _FakeAvatarNotifier({AvatarState initial = const AvatarState()})
    : _initial = initial;

  @override
  AvatarState build() => _initial;

  @override
  Future<void> setMood(AvatarOverlay? v) async {}

  @override
  Future<void> setAccessory(AvatarOverlay? v) async {}
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  final UserProfileState _initial;

  _FakeUserProfileNotifier({
    UserProfileState initial = const UserProfileState(),
  }) : _initial = initial;

  @override
  UserProfileState build() => _initial;

  @override
  void setUsername(String username) {}

  @override
  void setInterest(String interest) {}

  @override
  void setThought(String thought) {}

  @override
  void update({required String username, required String interest}) {}
}

// ── Helper ─────────────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester, {
  String roomName = 'Kao Tapu',
  String roomId = 'AB123',
  _FakeAvatarNotifier? avatarFake,
  _FakeUserProfileNotifier? profileFake,
}) async {
  avatarFake ??= _FakeAvatarNotifier();
  profileFake ??= _FakeUserProfileNotifier();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        avatarProvider.overrideWith(() => avatarFake!),
        userProfileProvider.overrideWith(() => profileFake!),
      ],
      child: MaterialApp(
        routes: {
          '/': (_) => Builder(
            builder: (ctx) => TextButton(
              onPressed: () => Navigator.pushNamed(
                ctx,
                AppRoutes.groupChatScreen,
                arguments: {
                  'roomName': roomName,
                  'roomId': roomId,
                  'bgImage': 'assets/images/backgrounds/kao_tapu.png',
                  'maxMembers': 5,
                },
              ),
              child: const Text('go'),
            ),
          ),
          AppRoutes.groupChatScreen: (_) => const GroupChatScreen(),
          AppRoutes.friendChat: (_) =>
              const Scaffold(body: Text('friend-chat')),
        },
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester
      .pump(); // render GroupChatScreen + register first postFrameCallback
  await tester
      .pump(); // _scrollToBottom() fires + starts Future.delayed(350 ms)
  // Drain the 350 ms scroll timer so it doesn't remain pending after disposal.
  // Stays well below the 3-second friend-message timer to keep tests isolated.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(); // settle any resulting callbacks
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('GroupChatScreen', () {
    testWidgets('renders without error', (tester) async {
      await _pump(tester);
      expect(find.byType(GroupChatScreen), findsOneWidget);
    });

    testWidgets('shows room name in header', (tester) async {
      await _pump(tester, roomName: 'Kao Tapu');
      expect(find.text('Kao Tapu'), findsWidgets);
    });

    testWidgets('shows room ID in header', (tester) async {
      await _pump(tester, roomId: 'AB123');
      expect(find.textContaining('AB123'), findsOneWidget);
    });

    testWidgets('renders message input field', (tester) async {
      await _pump(tester);
      // SongPanelBody (always in the tree) also has a TextField, so check for ≥1
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('shows existing messages in the list', (tester) async {
      await _pump(tester);
      expect(find.textContaining('Hello'), findsWidgets);
    });
  });
}
