import '../entities/admin_user.dart';
import '../repositories/admin_repository.dart';

class WatchUsers {
  final AdminRepository _r;

  WatchUsers(this._r);

  Stream<List<AdminUser>> call() => _r.watchUsers();
}
