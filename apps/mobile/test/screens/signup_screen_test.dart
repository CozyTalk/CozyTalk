import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/screens/signup_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  int signUpCount = 0;
  int signInWithGoogleCount = 0;
  int signInAnonymouslyCount = 0;

  final AuthState _initial;
  _FakeAuthNotifier({AuthState initial = const AuthState()})
    : _initial = initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async => signUpCount++;

  @override
  Future<void> signInWithGoogle() async => signInWithGoogleCount++;

  @override
  Future<void> signInAnonymously() async => signInAnonymouslyCount++;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}
}

Widget _build(_FakeAuthNotifier fake) => ProviderScope(
  overrides: [authNotifierProvider.overrideWith(() => fake)],
  child: const MaterialApp(home: SignupScreen()),
);

void main() {
  group('SignupScreen (production)', () {
    testWidgets('renders email, password fields and Sign Up button', (
      tester,
    ) async {
      await tester.pumpWidget(_build(_FakeAuthNotifier()));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets(
      'Sign Up button is disabled until both checkboxes are checked',
      (tester) async {
        await tester.pumpWidget(_build(_FakeAuthNotifier()));
        final btn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Sign Up'),
        );
        expect(btn.onPressed, isNull);
      },
    );

    testWidgets('Sign Up button enabled after checking both checkboxes', (
      tester,
    ) async {
      await tester.pumpWidget(_build(_FakeAuthNotifier()));
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Sign Up'),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('shows password required error when password is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_build(_FakeAuthNotifier()));
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pump();
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('calls signUp when form is valid and checkboxes checked', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_build(fake));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your email'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your password'),
        'password123',
      );
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pump();
      expect(fake.signUpCount, 1);
    });

    testWidgets('shows spinner and disables Sign Up button while loading', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier(
        initial: const AuthState(status: AuthStatus.loading),
      );
      await tester.pumpWidget(_build(fake));
      expect(find.byType(CircularProgressIndicator), findsAny);
      final btn = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('shows error snackbar when auth state emits a new error', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_build(fake));
      fake.state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Email already in use.',
      );
      await tester.pump();
      expect(find.text('Email already in use.'), findsOneWidget);
    });

    testWidgets('calls signInWithGoogle when Google button is tapped', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_build(fake));
      await tester.ensureVisible(find.text('Sign up with Google'));
      await tester.pump();
      await tester.tap(find.text('Sign up with Google'), warnIfMissed: false);
      await tester.pump();
      expect(fake.signInWithGoogleCount, 1);
    });

    testWidgets('calls signInAnonymously when guest link is tapped', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_build(fake));
      await tester.ensureVisible(find.text('Login as a guest'));
      await tester.pump();
      await tester.tap(find.text('Login as a guest'), warnIfMissed: false);
      await tester.pump();
      expect(fake.signInAnonymouslyCount, 1);
    });
  });
}
