import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/usecases/watch_presence.dart';
import '../shared_fakes.dart';

void main() {
  late FakeChatRepository repo;
  late WatchPresence usecase;

  setUp(() {
    repo = FakeChatRepository();
    usecase = WatchPresence(repo);
  });

  group('WatchPresence', () {
    test('passes sessionId to repository', () {
      usecase('session-1');
      expect(repo.lastSessionId, 'session-1');
    });

    test('returns uid set from repository stream', () async {
      repo.presenceStream = Stream.value({'u1', 'u2'});
      final result = await usecase('session-1').first;
      expect(result, containsAll(['u1', 'u2']));
      expect(result.length, 2);
    });

    test('returns empty set when no one is present', () async {
      repo.presenceStream = Stream.value({});
      final result = await usecase('session-1').first;
      expect(result, isEmpty);
    });
  });
}
