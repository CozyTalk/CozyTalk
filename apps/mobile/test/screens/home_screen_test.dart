import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/avatar/presentation/providers/avatar_decoration_provider.dart';
import 'package:mobile/features/profile/domain/entities/profile_user.dart';
import 'package:mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:mobile/screens/home_screen.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier({AuthState initial = const AuthState()})
    : _initial = initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signInWithGoogle() async {}
}

class _FakeProfileNotifier extends ProfileNotifier {
  final ProfileState _initial;
  int loadCount = 0;
  int updateThoughtsCount = 0;
  String? lastUid;
  String? lastThoughts;

  _FakeProfileNotifier({ProfileState initial = const ProfileState()})
    : _initial = initial;

  @override
  ProfileState build() => _initial;

  @override
  Future<void> load(String uid) async {
    loadCount++;
    lastUid = uid;
  }

  @override
  Future<void> updateDisplayName(String uid, String displayName) async {}

  @override
  Future<void> updateInterest(String uid, String interest) async {}

  @override
  Future<void> updateThoughts(String uid, String thoughts) async {
    updateThoughtsCount++;
    lastUid = uid;
    lastThoughts = thoughts;
  }
}

class _FakeAvatarDecorationNotifier extends AvatarDecorationNotifier {
  final AvatarDecorationState _initial;
  int loadCount = 0;
  int updateMoodCount = 0;
  int updateHatCount = 0;

  _FakeAvatarDecorationNotifier({
    AvatarDecorationState initial = const AvatarDecorationState(),
  }) : _initial = initial;

  @override
  AvatarDecorationState build() => _initial;

  @override
  Future<void> load(String uid) async => loadCount++;

  @override
  Future<void> updateMood(String uid, String? moodKey) async =>
      updateMoodCount++;

  @override
  Future<void> updateHat(String uid, String? hatKey) async => updateHatCount++;

  @override
  Future<void> updateDecoration(
    String uid,
    String? hatKey,
    String? moodKey,
  ) async {}
}

// ── Helpers ────────────────────────────────────────────────────────────────────

const _authenticatedAuth = AuthState(
  status: AuthStatus.authenticated,
  user: AuthUser(uid: 'test-uid'),
);

Widget _buildScreen(
  _FakeProfileNotifier profileFake,
  _FakeAvatarDecorationNotifier avatarFake, {
  AuthState auth = _authenticatedAuth,
}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(initial: auth)),
      profileNotifierProvider.overrideWith(() => profileFake),
      avatarDecorationNotifierProvider.overrideWith(() => avatarFake),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('HomeScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        _buildScreen(_FakeProfileNotifier(), _FakeAvatarDecorationNotifier()),
      );
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('displays username from profileNotifierProvider', (
      tester,
    ) async {
      final profile = _FakeProfileNotifier(
        initial: ProfileState(
          profile: const ProfileUser(uid: 'test-uid', displayName: 'Alice'),
        ),
      );
      await tester.pumpWidget(
        _buildScreen(profile, _FakeAvatarDecorationNotifier()),
      );

      expect(find.text('Hello, Alice!'), findsOneWidget);
    });

    testWidgets('displays thoughts from profileNotifierProvider', (
      tester,
    ) async {
      final profile = _FakeProfileNotifier(
        initial: ProfileState(
          profile: const ProfileUser(
            uid: 'test-uid',
            thoughts: 'Feeling great today',
          ),
        ),
      );
      await tester.pumpWidget(
        _buildScreen(profile, _FakeAvatarDecorationNotifier()),
      );

      expect(find.text('Feeling great today'), findsOneWidget);
    });

    testWidgets('calls load on profile and avatar notifiers on mount', (
      tester,
    ) async {
      final profile = _FakeProfileNotifier();
      final avatar = _FakeAvatarDecorationNotifier();
      await tester.pumpWidget(_buildScreen(profile, avatar));
      await tester.pump();

      expect(profile.loadCount, 1);
      expect(profile.lastUid, 'test-uid');
      expect(avatar.loadCount, 1);
    });

    testWidgets('does not call load when user is unauthenticated', (
      tester,
    ) async {
      final profile = _FakeProfileNotifier();
      final avatar = _FakeAvatarDecorationNotifier();
      await tester.pumpWidget(
        _buildScreen(
          profile,
          avatar,
          auth: const AuthState(status: AuthStatus.unauthenticated),
        ),
      );
      await tester.pump();

      expect(profile.loadCount, 0);
      expect(avatar.loadCount, 0);
    });

    testWidgets('calls updateThoughts when dialog Save is tapped', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final profile = _FakeProfileNotifier(
        initial: ProfileState(
          profile: const ProfileUser(uid: 'test-uid', thoughts: 'Old thought'),
        ),
      );
      final avatar = _FakeAvatarDecorationNotifier();
      await tester.pumpWidget(_buildScreen(profile, avatar));
      await tester.pump();

      await tester.tap(find.text('Old thought'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'New thought');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(profile.updateThoughtsCount, 1);
      expect(profile.lastThoughts, 'New thought');
      expect(profile.lastUid, 'test-uid');
    });

    testWidgets('does not call updateThoughts when dialog Cancel is tapped', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final profile = _FakeProfileNotifier(
        initial: ProfileState(
          profile: const ProfileUser(uid: 'test-uid', thoughts: 'Old thought'),
        ),
      );
      final avatar = _FakeAvatarDecorationNotifier();
      await tester.pumpWidget(_buildScreen(profile, avatar));
      await tester.pump();

      await tester.tap(find.text('Old thought'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(profile.updateThoughtsCount, 0);
    });
  });
}
