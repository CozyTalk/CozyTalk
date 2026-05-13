import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/usecases/sign_in_with_google.dart';

class _FakeAuthRepository implements AuthRepository {
  int callCount = 0;
  AuthUser? returnUser;
  Exception? error;

  @override
  Future<AuthUser> signInWithGoogle() async {
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
  Future<AuthUser> signInAnonymously() async => throw UnimplementedError();

  @override
  Future<void> signOut() async => throw UnimplementedError();

  @override
  Stream<AuthUser?> watchAuthState() => throw UnimplementedError();
}

void main() {
  late _FakeAuthRepository repo;
  late SignInWithGoogle usecase;

  setUp(() {
    repo = _FakeAuthRepository();
    usecase = SignInWithGoogle(repo);
  });

  group('SignInWithGoogle', () {
    test('delegates to repository', () async {
      repo.returnUser = const AuthUser(uid: 'g-uid', email: 'user@gmail.com');
      await usecase();
      expect(repo.callCount, 1);
    });

    test('returns the AuthUser', () async {
      repo.returnUser =
          const AuthUser(uid: 'g-uid', email: 'user@gmail.com', displayName: 'Bob');
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
