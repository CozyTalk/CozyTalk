import '../entities/admin_report.dart';
import '../repositories/admin_repository.dart';

class WatchReports {
  final AdminRepository _r;

  WatchReports(this._r);

  Stream<List<AdminReport>> call() => _r.watchReports();
}
