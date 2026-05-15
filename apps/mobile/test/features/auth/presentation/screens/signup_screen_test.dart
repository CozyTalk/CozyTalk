import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/auth/presentation/screens/signup_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  int signUpCount = 0;
  String? lastEmail;
  String? lastPassword;

  final AuthState _initial;

  _FakeAuthNotifier({AuthState initial = const AuthState()})
    : _initial = initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signUp({required String email, required String password}) async {
    signUpCount++;
    lastEmail = email;
    lastPassword = password;
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signOut() async {}
}

Widget _buildSignupScreen(_FakeAuthNotifier fake) {
  return ProviderScope(
    overrides: [authNotifierProvider.overrideWith(() => fake)],
    child: const MaterialApp(home: SignupScreen()),
  );
}

void main() {
  group('SignupScreen', () {
    testWidgets('renders email, password and confirm password fields', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSignupScreen(_FakeAuthNotifier()));

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        findsOneWidget,
      );
    });

    testWidgets('shows email required error on empty submit', (tester) async {
      await tester.pumpWidget(_buildSignupScreen(_FakeAuthNotifier()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Email is required.'), findsOneWidget);
    });

    testWidgets('shows password mismatch error', (tester) async {
      await tester.pumpWidget(_buildSignupScreen(_FakeAuthNotifier()));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'password2',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('calls signUp with email and password on valid submit', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_buildSignupScreen(fake));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'secret123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(fake.signUpCount, 1);
      expect(fake.lastEmail, 'new@example.com');
      expect(fake.lastPassword, 'secret123');
    });

    testWidgets('shows error message from state.error', (tester) async {
      final fake = _FakeAuthNotifier(
        initial: const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'This email is already registered.',
        ),
      );
      await tester.pumpWidget(_buildSignupScreen(fake));

      expect(find.text('This email is already registered.'), findsOneWidget);
    });

    testWidgets('shows loading indicator when status is loading', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier(
        initial: const AuthState(status: AuthStatus.loading),
      );
      await tester.pumpWidget(_buildSignupScreen(fake));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('short password shows minimum length error', (tester) async {
      await tester.pumpWidget(_buildSignupScreen(_FakeAuthNotifier()));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        '12345',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(
        find.text('Password must be at least 6 characters.'),
        findsOneWidget,
      );
    });

    testWidgets('shows confirm password required error when confirm is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSignupScreen(_FakeAuthNotifier()));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password1',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Please confirm your password.'), findsOneWidget);
    });
  });
}
