import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/usecases/sign_in_anonymously.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAuthRepository repo;
  late SignInAnonymously usecase;

  setUp(() {
    repo = FakeAuthRepository();
    usecase = SignInAnonymously(repo);
  });

  group('SignInAnonymously', () {
    test('delegates to repository', () async {
      repo.returnUser = const AuthUser(uid: 'anon-1');
      await usecase();
      expect(repo.signInAnonymouslyCount, 1);
    });

    test('returns the AuthUser', () async {
      repo.returnUser = const AuthUser(uid: 'anon-1');
      final result = await usecase();
      expect(result.uid, 'anon-1');
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('anon sign-in disabled');
      expect(() => usecase(), throwsA(isA<Exception>()));
    });
  });
}
