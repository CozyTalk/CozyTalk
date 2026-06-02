import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/usecases/watch_chat_read.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late WatchChatRead usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = WatchChatRead(repo);
  });

  test('forwards chatRoomId to repository', () async {
    await usecase('room-1').first;
    expect(repo.lastWatchChatReadId, 'room-1');
  });

  test('emits the read marker from repository', () {
    final ts = DateTime.fromMillisecondsSinceEpoch(1000);
    repo.watchChatReadResult = ts;
    expect(usecase('room-1'), emits(ts));
  });

  test('emits null when no marker is stored', () {
    expect(usecase('room-1'), emits(null));
  });

  test('propagates repository exception', () {
    repo.error = Exception('permission denied');
    expect(usecase('room-1'), emitsError(isA<Exception>()));
  });
}
