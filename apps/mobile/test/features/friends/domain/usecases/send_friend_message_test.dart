import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/usecases/send_friend_message.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late SendFriendMessage usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = SendFriendMessage(repo);
  });

  test('forwards all parameters to repository', () async {
    await usecase(
      chatRoomId: 'room-abc',
      text: 'Hello!',
      senderDisplayName: 'Alice',
    );
    expect(repo.sendMessageCount, 1);
    expect(repo.lastChatRoomId, 'room-abc');
    expect(repo.lastText, 'Hello!');
    expect(repo.lastSenderDisplayName, 'Alice');
  });

  test('propagates repository exception', () {
    repo.error = Exception('send failed');
    expect(
      () => usecase(
        chatRoomId: 'room-abc',
        text: 'Hi',
        senderDisplayName: 'Alice',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
