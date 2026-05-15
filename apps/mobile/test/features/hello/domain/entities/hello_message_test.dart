import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/hello/domain/entities/hello_message.dart';

void main() {
  group('HelloMessage', () {
    test('constructs with required message', () {
      const msg = HelloMessage(message: 'hi');
      expect(msg.message, 'hi');
    });

    test('preserves empty string', () {
      const msg = HelloMessage(message: '');
      expect(msg.message, '');
    });

    test('preserves whitespace content', () {
      const msg = HelloMessage(message: '  hello  ');
      expect(msg.message, '  hello  ');
    });
  });
}
