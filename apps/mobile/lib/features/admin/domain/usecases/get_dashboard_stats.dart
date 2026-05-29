import '../entities/admin_dashboard_stats.dart';
import '../repositories/admin_repository.dart';

class GetDashboardStats {
  final AdminRepository _r;

  GetDashboardStats(this._r);

  Future<AdminDashboardStats> call() => _r.getDashboardStats();
}
