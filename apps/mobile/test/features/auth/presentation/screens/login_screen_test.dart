import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  int signInCount = 0;
  int signInWithGoogleCount = 0;
  int signInAnonymouslyCount = 0;
  String? lastEmail;
  String? lastPassword;

  final AuthState _initial;

  _FakeAuthNotifier({AuthState initial = const AuthState()}) : _initial = initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCount++;
    lastEmail = email;
    lastPassword = password;
  }

  @override
  Future<void> signInWithGoogle() async => signInWithGoogleCount++;

  @override
  Future<void> signInAnonymously() async => signInAnonymouslyCount++;

  @override
  Future<void> signUp({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}
}

Widget _buildLoginScreen(_FakeAuthNotifier fake) {
  return ProviderScope(
    overrides: [authNotifierProvider.overrideWith(() => fake)],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('renders email field, password field and sign in button',
        (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuthNotifier()));

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('renders Google sign-in and guest buttons', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuthNotifier()));

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('shows email required error when email is empty', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuthNotifier()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Email is required.'), findsOneWidget);
    });

    testWidgets('shows invalid email error for malformed email', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuthNotifier()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'notanemail');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('shows password required error when password is empty', (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuthNotifier()));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'a@b.com');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('shows short password error when password is under 6 chars',
        (tester) async {
      await tester.pumpWidget(_buildLoginScreen(_FakeAuthNotifier()));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'a@b.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'abc');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);
    });

    testWidgets('calls signIn with trimmed email and password on valid submit',
        (tester) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_buildLoginScreen(fake));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), '  user@example.com  ');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(fake.signInCount, 1);
      expect(fake.lastEmail, 'user@example.com');
      expect(fake.lastPassword, 'password123');
    });

    testWidgets('shows error message from state.error', (tester) async {
      final fake = _FakeAuthNotifier(
        initial: const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Invalid email or password.',
        ),
      );
      await tester.pumpWidget(_buildLoginScreen(fake));

      expect(find.text('Invalid email or password.'), findsOneWidget);
    });

    testWidgets('disables sign in button while loading', (tester) async {
      final fake = _FakeAuthNotifier(
        initial: const AuthState(status: AuthStatus.loading),
      );
      await tester.pumpWidget(_buildLoginScreen(fake));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('calls signInWithGoogle when Google button is tapped',
        (tester) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_buildLoginScreen(fake));

      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      expect(fake.signInWithGoogleCount, 1);
    });

    testWidgets('calls signInAnonymously when guest button is tapped',
        (tester) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_buildLoginScreen(fake));

      await tester.tap(find.text('Continue as Guest'));
      await tester.pump();

      expect(fake.signInAnonymouslyCount, 1);
    });
  });
}
