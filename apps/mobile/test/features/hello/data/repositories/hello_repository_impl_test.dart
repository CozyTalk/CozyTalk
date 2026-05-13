import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/hello/data/datasources/hello_datasource.dart';
import 'package:mobile/features/hello/data/models/hello_message_model.dart';
import 'package:mobile/features/hello/data/repositories/hello_repository_impl.dart';

class _FakeHelloDatasource implements HelloDatasource {
  String? lastMessage;
  HelloMessageModel? returnValue;
  Exception? error;

  @override
  Future<HelloMessageModel> callHello(String message) async {
    lastMessage = message;
    if (error != null) throw error!;
    return returnValue!;
  }
}

void main() {
  late _FakeHelloDatasource datasource;
  late HelloRepositoryImpl repository;

  setUp(() {
    datasource = _FakeHelloDatasource();
    repository = HelloRepositoryImpl(datasource);
  });

  group('HelloRepositoryImpl', () {
    test('passes message to datasource', () async {
      datasource.returnValue = const HelloMessageModel(message: 'ok');
      await repository.callHello('test input');
      expect(datasource.lastMessage, 'test input');
    });

    test('converts model to entity', () async {
      datasource.returnValue = const HelloMessageModel(message: 'converted');
      final result = await repository.callHello('x');
      expect(result.message, 'converted');
    });

    test('propagates datasource exceptions', () {
      datasource.error = Exception('timeout');
      expect(() => repository.callHello('x'), throwsA(isA<Exception>()));
    });
  });
}
