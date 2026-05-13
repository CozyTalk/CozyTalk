import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/usecases/sign_out.dart';

class _FakeAuthRepository implements AuthRepository {
  int signOutCount = 0;
  Exception? error;

  @override
  Future<void> signOut() async {
    signOutCount++;
    if (error != null) throw error!;
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
  Future<AuthUser> signInWithGoogle() async => throw UnimplementedError();

  @override
  Stream<AuthUser?> watchAuthState() => throw UnimplementedError();
}

void main() {
  late _FakeAuthRepository repo;
  late SignOut usecase;

  setUp(() {
    repo = _FakeAuthRepository();
    usecase = SignOut(repo);
  });

  group('SignOut', () {
    test('delegates to repository', () async {
      await usecase();
      expect(repo.signOutCount, 1);
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('sign out failed');
      expect(() => usecase(), throwsA(isA<Exception>()));
    });
  });
}
