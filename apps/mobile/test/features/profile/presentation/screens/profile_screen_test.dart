import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/profile/domain/entities/profile_user.dart';
import 'package:mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:mobile/features/profile/presentation/screens/profile_screen.dart';

class _FakeProfileNotifier extends ProfileNotifier {
  final ProfileState _initial;
  int loadCount = 0;
  int updateDisplayNameCount = 0;
  int updateInterestCount = 0;
  int updateThoughtsCount = 0;
  String? lastDisplayName;
  String? lastInterest;
  String? lastThoughts;

  _FakeProfileNotifier({ProfileState initial = const ProfileState()})
    : _initial = initial;

  @override
  ProfileState build() => _initial;

  @override
  Future<void> load(String uid) async => loadCount++;

  @override
  Future<void> updateDisplayName(String uid, String displayName) async {
    updateDisplayNameCount++;
    lastDisplayName = displayName;
  }

  @override
  Future<void> updateInterest(String uid, String interest) async {
    updateInterestCount++;
    lastInterest = interest;
  }

  @override
  Future<void> updateThoughts(String uid, String thoughts) async {
    updateThoughtsCount++;
    lastThoughts = thoughts;
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier({AuthState initial = const AuthState()})
    : _initial = initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signUp({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signInWithGoogle() async {}
}

const _authenticatedAuth = AuthState(
  status: AuthStatus.authenticated,
  user: AuthUser(uid: 'test-uid'),
);

Widget _buildProfileScreen(
  _FakeProfileNotifier profileFake, {
  AuthState auth = _authenticatedAuth,
}) {
  final authFake = _FakeAuthNotifier(initial: auth);
  return ProviderScope(
    overrides: [
      profileNotifierProvider.overrideWith(() => profileFake),
      authNotifierProvider.overrideWith(() => authFake),
    ],
    child: const MaterialApp(home: ProfileScreen()),
  );
}

void main() {
  group('ProfileScreen', () {
    testWidgets('renders Username, Interest, and Current Thoughts fields', (
      tester,
    ) async {
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(_buildProfileScreen(fake));

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Interest'), findsOneWidget);
      expect(find.text('Current Thoughts'), findsOneWidget);
    });

    testWidgets('renders Save buttons for each field', (tester) async {
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(_buildProfileScreen(fake));

      expect(find.text('Save Username'), findsOneWidget);
      expect(find.text('Save Interest'), findsOneWidget);
      expect(find.text('Save Current Thoughts'), findsOneWidget);
    });

    testWidgets('calls load on init with authenticated uid', (tester) async {
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(_buildProfileScreen(fake));
      await tester.pump();

      expect(fake.loadCount, 1);
    });

    testWidgets('does not call updateDisplayName when username field is empty',
        (tester) async {
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(_buildProfileScreen(fake));

      await tester.tap(find.text('Save Username'));
      await tester.pump();

      expect(fake.updateDisplayNameCount, 0);
    });

    testWidgets('calls updateDisplayName with trimmed text on valid input', (
      tester,
    ) async {
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(_buildProfileScreen(fake));

      await tester.enterText(
        find.widgetWithText(TextField, 'Max 20 characters'),
        '  Alice  ',
      );
      await tester.tap(find.text('Save Username'));
      await tester.pump();

      expect(fake.updateDisplayNameCount, 1);
      expect(fake.lastDisplayName, 'Alice');
    });

    testWidgets('calls updateDisplayName with exactly 20 chars', (tester) async {
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(_buildProfileScreen(fake));

      await tester.enterText(
        find.widgetWithText(TextField, 'Max 20 characters'),
        'a' * 20,
      );
      await tester.tap(find.text('Save Username'));
      await tester.pump();

      expect(fake.updateDisplayNameCount, 1);
      expect(fake.lastDisplayName, 'a' * 20);
    });

    testWidgets('calls updateInterest on valid interest input', (tester) async {
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(_buildProfileScreen(fake));

      await tester.enterText(
        find.widgetWithText(TextField, 'Max 200 characters'),
        'music and coding',
      );
      await tester.tap(find.text('Save Interest'));
      await tester.pump();

      expect(fake.updateInterestCount, 1);
      expect(fake.lastInterest, 'music and coding');
    });

    testWidgets('calls updateThoughts on valid thoughts input', (tester) async {
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(_buildProfileScreen(fake));

      await tester.enterText(
        find.widgetWithText(TextField, 'Max 50 characters'),
        'feeling creative today',
      );
      await tester.tap(find.text('Save Current Thoughts'));
      await tester.pump();

      expect(fake.updateThoughtsCount, 1);
      expect(fake.lastThoughts, 'feeling creative today');
    });

    testWidgets('calls updateThoughts with exactly 50 chars', (tester) async {
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(_buildProfileScreen(fake));

      await tester.enterText(
        find.widgetWithText(TextField, 'Max 50 characters'),
        'a' * 50,
      );
      await tester.tap(find.text('Save Current Thoughts'));
      await tester.pump();

      expect(fake.updateThoughtsCount, 1);
      expect(fake.lastThoughts, 'a' * 50);
    });

    testWidgets('shows error message when state.error is set', (tester) async {
      final fake = _FakeProfileNotifier(
        initial: const ProfileState(error: 'Failed to update'),
      );
      await tester.pumpWidget(_buildProfileScreen(fake));

      expect(find.textContaining('Failed to update'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading is true', (
      tester,
    ) async {
      final fake = _FakeProfileNotifier(
        initial: const ProfileState(
          profile: ProfileUser(uid: 'test-uid'),
          isLoading: true,
        ),
      );
      await tester.pumpWidget(_buildProfileScreen(fake));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows success checkmark when successField matches', (
      tester,
    ) async {
      final fake = _FakeProfileNotifier(
        initial: const ProfileState(
          profile: ProfileUser(uid: 'test-uid'),
          successField: 'username',
        ),
      );
      await tester.pumpWidget(_buildProfileScreen(fake));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('disables save buttons while loading', (tester) async {
      final fake = _FakeProfileNotifier(
        initial: const ProfileState(
          profile: ProfileUser(uid: 'test-uid'),
          isLoading: true,
        ),
      );
      await tester.pumpWidget(_buildProfileScreen(fake));

      final saveUsernameButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save Username'),
      );
      expect(saveUsernameButton.onPressed, isNull);
    });
  });
}
