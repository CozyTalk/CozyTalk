import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/usecases/sign_in_anonymously.dart';

class _FakeAuthRepository implements AuthRepository {
  int callCount = 0;
  AuthUser? returnUser;
  Exception? error;

  @override
  Future<AuthUser> signInAnonymously() async {
    callCount++;
    if (error != null) throw error!;
    return returnUser!;
  }

  @override
  Future<AuthUser> signIn({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signUp({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signInWithGoogle() async => throw UnimplementedError();

  @override
  Future<void> signOut() async => throw UnimplementedError();

  @override
  Stream<AuthUser?> watchAuthState() => throw UnimplementedError();
}

void main() {
  late _FakeAuthRepository repo;
  late SignInAnonymously usecase;

  setUp(() {
    repo = _FakeAuthRepository();
    usecase = SignInAnonymously(repo);
  });

  group('SignInAnonymously', () {
    test('delegates to repository', () async {
      repo.returnUser = const AuthUser(uid: 'anon-1');
      await usecase();
      expect(repo.callCount, 1);
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
