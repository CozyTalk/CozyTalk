import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/word_filter/presentation/providers/word_filter_provider.dart';

import '../../domain/shared_fakes.dart';

void main() {
  late FakeWordFilterRepository fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeWordFilterRepository(returnValue: '*****');
    container = ProviderContainer(
      overrides: [wordFilterRepositoryProvider.overrideWithValue(fake)],
    );
  });

  tearDown(() => container.dispose());

  group('censorTextProvider', () {
    test(
      'resolves CensorText usecase and delegates to overridden repository',
      () async {
        final usecase = container.read(censorTextProvider);
        final result = await usecase('hello');

        expect(result, '*****');
        expect(fake.callCount, 1);
        expect(fake.lastArg, 'hello');
      },
    );

    test('propagates exception from repository', () async {
      final throwingFake = FakeWordFilterRepository(shouldThrow: true);
      final throwingContainer = ProviderContainer(
        overrides: [
          wordFilterRepositoryProvider.overrideWithValue(throwingFake),
        ],
      );
      addTearDown(throwingContainer.dispose);

      final usecase = throwingContainer.read(censorTextProvider);
      expect(() async => usecase('text'), throwsA(isA<Exception>()));
    });
  });
}
