import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/hello/domain/entities/hello_message.dart';
import 'package:mobile/features/hello/domain/repositories/hello_repository.dart';
import 'package:mobile/features/hello/domain/usecases/call_hello.dart';

class _FakeHelloRepository implements HelloRepository {
  String? lastMessage;
  HelloMessage? returnValue;
  Exception? error;

  @override
  Future<HelloMessage> callHello(String message) async {
    lastMessage = message;
    if (error != null) throw error!;
    return returnValue!;
  }
}

void main() {
  late _FakeHelloRepository repo;
  late CallHello usecase;

  setUp(() {
    repo = _FakeHelloRepository();
    usecase = CallHello(repo);
  });

  group('CallHello', () {
    test('delegates to repository with the given message', () async {
      repo.returnValue = const HelloMessage(message: 'pong');
      await usecase('ping');
      expect(repo.lastMessage, 'ping');
    });

    test('returns the HelloMessage from the repository', () async {
      repo.returnValue = const HelloMessage(message: 'response');
      final result = await usecase('any');
      expect(result.message, 'response');
    });

    test('propagates repository exceptions', () async {
      repo.error = Exception('network error');
      expect(() => usecase('msg'), throwsA(isA<Exception>()));
    });
  });
}
