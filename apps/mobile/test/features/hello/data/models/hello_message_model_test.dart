import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/hello/data/models/hello_message_model.dart';

void main() {
  group('HelloMessageModel', () {
    group('fromJson', () {
      test('constructs from valid json', () {
        final model = HelloMessageModel.fromJson({'message': 'hello'});
        expect(model.message, 'hello');
      });

      test('preserves empty string message', () {
        final model = HelloMessageModel.fromJson({'message': ''});
        expect(model.message, '');
      });
    });

    group('toEntity', () {
      test('maps message field to HelloMessage', () {
        const model = HelloMessageModel(message: 'world');
        final entity = model.toEntity();
        expect(entity.message, 'world');
      });
    });
  });
}
