import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/domain/usecases/sign_up.dart';

class _FakeAuthRepository implements AuthRepository {
  String? lastEmail;
  String? lastPassword;
  AuthUser? returnUser;
  Exception? error;

  @override
  Future<AuthUser> signUp({required String email, required String password}) async {
    lastEmail = email;
    lastPassword = password;
    if (error != null) throw error!;
    return returnUser!;
  }

  @override
  Future<AuthUser> signIn({required String email, required String password}) async =>
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
  late SignUp usecase;

  setUp(() {
    repo = _FakeAuthRepository();
    usecase = SignUp(repo);
  });

  group('SignUp', () {
    test('passes email and password to repository', () async {
      repo.returnUser = const AuthUser(uid: 'new-user');
      await usecase(email: 'new@example.com', password: 'pass123');
      expect(repo.lastEmail, 'new@example.com');
      expect(repo.lastPassword, 'pass123');
    });

    test('returns the created AuthUser', () async {
      repo.returnUser = const AuthUser(uid: 'new-user', email: 'new@example.com');
      final result = await usecase(email: 'new@example.com', password: 'pass123');
      expect(result.uid, 'new-user');
      expect(result.email, 'new@example.com');
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('email already in use');
      expect(
        () => usecase(email: 'taken@example.com', password: 'pass123'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
