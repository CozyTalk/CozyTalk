import '../repositories/admin_repository.dart';

class UnbanUser {
  final AdminRepository _r;

  UnbanUser(this._r);

  Future<void> call(String uid) => _r.unbanUser(uid);
}
