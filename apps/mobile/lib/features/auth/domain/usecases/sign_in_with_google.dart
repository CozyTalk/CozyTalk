import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle {
  final AuthRepository _repository;
  const SignInWithGoogle(this._repository);

  Future<AuthUser> call() => _repository.signInWithGoogle();
}
