import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/usecases/sign_in.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAuthRepository repo;
  late SignIn usecase;

  setUp(() {
    repo = FakeAuthRepository();
    usecase = SignIn(repo);
  });

  group('SignIn', () {
    test('passes email and password to repository', () async {
      repo.returnUser = const AuthUser(uid: 'u1', email: 'a@b.com');
      await usecase(email: 'a@b.com', password: 'secret');
      expect(repo.signInCount, 1);
      expect(repo.lastEmail, 'a@b.com');
      expect(repo.lastPassword, 'secret');
    });

    test('returns the AuthUser from repository', () async {
      repo.returnUser = const AuthUser(uid: 'u1', email: 'a@b.com');
      final result = await usecase(email: 'a@b.com', password: 'secret');
      expect(result.uid, 'u1');
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('invalid credentials');
      expect(
        () => usecase(email: 'a@b.com', password: 'wrong'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
