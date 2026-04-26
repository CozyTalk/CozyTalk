import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignInAnonymously {
  final AuthRepository _repository;
  const SignInAnonymously(this._repository);

  Future<AuthUser> call() => _repository.signInAnonymously();
}
