import '../repositories/admin_repository.dart';

class GetChatLogUrl {
  final AdminRepository _r;

  GetChatLogUrl(this._r);

  Future<String> call(String reportId) => _r.getChatLogUrl(reportId);
}
