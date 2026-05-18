import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend_message.dart';
import 'package:mobile/features/friends/domain/usecases/watch_friend_messages.dart';

import '../shared_fakes.dart';

void main() {
  late FakeFriendsRepository repo;
  late WatchFriendMessages usecase;

  setUp(() {
    repo = FakeFriendsRepository();
    usecase = WatchFriendMessages(repo);
  });

  test('passes chatRoomId to repository', () async {
    await usecase('room-123').first;
    expect(repo.lastChatRoomId, 'room-123');
  });

  test('returns messages stream from repository', () async {
    repo.messages = [
      FriendMessage(
        id: 'm1',
        senderId: 'u1',
        senderDisplayName: 'Alice',
        text: 'hi',
        timestamp: DateTime(2024),
      ),
    ];
    final result = await usecase('room-1').first;
    expect(result, hasLength(1));
    expect(result[0].text, 'hi');
  });

  test('returns empty list when no messages', () async {
    final result = await usecase('room-empty').first;
    expect(result, isEmpty);
  });

  test('propagates stream error from repository', () {
    repo.error = Exception('chat room not found');
    expect(usecase('room-bad').first, throwsA(isA<Exception>()));
  });
}
