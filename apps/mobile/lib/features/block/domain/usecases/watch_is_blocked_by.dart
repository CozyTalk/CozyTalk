import '../repositories/block_repository.dart';

class WatchIsBlockedBy {
  final BlockRepository _repository;
  WatchIsBlockedBy(this._repository);

  Stream<bool> call(String partnerUid, String myUid) =>
      _repository.watchIsBlockedBy(partnerUid, myUid);
}
