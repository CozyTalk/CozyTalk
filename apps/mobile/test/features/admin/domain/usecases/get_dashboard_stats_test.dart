import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_dashboard_stats.dart';
import 'package:mobile/features/admin/domain/usecases/get_dashboard_stats.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAdminRepository repo;
  late GetDashboardStats usecase;

  setUp(() {
    repo = FakeAdminRepository();
    usecase = GetDashboardStats(repo);
  });

  group('GetDashboardStats', () {
    test('calls repository and returns stats', () async {
      repo.returnStats = const AdminDashboardStats(
        pendingReports: 4,
        onlineUsers: 10,
        bannedUsers: 2,
      );
      final result = await usecase();
      expect(repo.getDashboardStatsCount, 1);
      expect(result.pendingReports, 4);
      expect(result.onlineUsers, 10);
      expect(result.bannedUsers, 2);
    });

    test('propagates repository exception', () {
      repo.error = Exception('network error');
      expect(() => usecase(), throwsA(isA<Exception>()));
    });
  });
}
