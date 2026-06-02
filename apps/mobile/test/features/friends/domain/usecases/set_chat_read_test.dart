import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/usecases/set_chat_read.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late SetChatRead usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = SetChatRead(repo);
  });

  test('forwards chatRoomId to repository', () async {
    await usecase('room-1');
    expect(repo.setChatReadCount, 1);
    expect(repo.lastSetChatReadId, 'room-1');
  });

  test('propagates repository exception', () {
    repo.error = Exception('permission denied');
    expect(() => usecase('room-1'), throwsA(isA<Exception>()));
  });
}
