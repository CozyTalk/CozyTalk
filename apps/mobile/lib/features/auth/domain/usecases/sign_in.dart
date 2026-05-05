import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignIn {
  final AuthRepository _repository;
  const SignIn(this._repository);

  Future<AuthUser> call({required String email, required String password}) =>
      _repository.signIn(email: email, password: password);
}
