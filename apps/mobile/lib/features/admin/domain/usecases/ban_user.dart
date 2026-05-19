import '../repositories/admin_repository.dart';

class BanUser {
  final AdminRepository _r;

  BanUser(this._r);

  Future<void> call({
    required String uid,
    required String reason,
    required String duration,
    String? note,
    String? reportId,
  }) => _r.banUser(
    uid: uid,
    reason: reason,
    duration: duration,
    note: note,
    reportId: reportId,
  );
}
