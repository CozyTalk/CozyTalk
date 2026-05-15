import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/usecases/sign_in_with_google.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAuthRepository repo;
  late SignInWithGoogle usecase;

  setUp(() {
    repo = FakeAuthRepository();
    usecase = SignInWithGoogle(repo);
  });

  group('SignInWithGoogle', () {
    test('delegates to repository', () async {
      repo.returnUser = const AuthUser(uid: 'g-uid', email: 'user@gmail.com');
      await usecase();
      expect(repo.signInWithGoogleCount, 1);
    });

    test('returns the AuthUser', () async {
      repo.returnUser = const AuthUser(
        uid: 'g-uid',
        email: 'user@gmail.com',
        displayName: 'Bob',
      );
      final result = await usecase();
      expect(result.uid, 'g-uid');
      expect(result.displayName, 'Bob');
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('popup closed');
      expect(() => usecase(), throwsA(isA<Exception>()));
    });
  });
}
