import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_dashboard_stats.dart';

void main() {
  group('AdminDashboardStats', () {
    test('constructs with all fields', () {
      const stats = AdminDashboardStats(
        pendingReports: 5,
        onlineUsers: 12,
        bannedUsers: 3,
      );
      expect(stats.pendingReports, 5);
      expect(stats.onlineUsers, 12);
      expect(stats.bannedUsers, 3);
    });

    test('constructs with zero values', () {
      const stats = AdminDashboardStats(
        pendingReports: 0,
        onlineUsers: 0,
        bannedUsers: 0,
      );
      expect(stats.pendingReports, 0);
      expect(stats.onlineUsers, 0);
      expect(stats.bannedUsers, 0);
    });
  });
}
