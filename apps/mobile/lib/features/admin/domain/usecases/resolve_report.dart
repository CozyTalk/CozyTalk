import '../repositories/admin_repository.dart';

class ResolveReport {
  final AdminRepository _r;

  ResolveReport(this._r);

  Future<void> call(String reportId, {required String action, String? note}) =>
      _r.resolveReport(reportId, action: action, note: note);
}
