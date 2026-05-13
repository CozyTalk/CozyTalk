import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/usecases/sign_in.dart';

class _FakeAuthRepository implements AuthRepository {
  String? lastEmail;
  String? lastPassword;
  AuthUser? returnUser;
  Exception? error;

  @override
  Future<AuthUser> signIn({required String email, required String password}) async {
    lastEmail = email;
    lastPassword = password;
    if (error != null) throw error!;
    return returnUser!;
  }

  @override
  Future<AuthUser> signUp({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signInAnonymously() async => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithGoogle() async => throw UnimplementedError();

  @override
  Future<void> signOut() async => throw UnimplementedError();

  @override
  Stream<AuthUser?> watchAuthState() => throw UnimplementedError();
}

void main() {
  late _FakeAuthRepository repo;
  late SignIn usecase;

  setUp(() {
    repo = _FakeAuthRepository();
    usecase = SignIn(repo);
  });

  group('SignIn', () {
    test('passes email and password to repository', () async {
      repo.returnUser = const AuthUser(uid: 'u1', email: 'a@b.com');
      await usecase(email: 'a@b.com', password: 'secret');
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
