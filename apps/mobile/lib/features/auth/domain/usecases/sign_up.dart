import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignUp {
  final AuthRepository _repository;
  const SignUp(this._repository);

  Future<AuthUser> call({required String email, required String password}) =>
      _repository.signUp(email: email, password: password);
}
