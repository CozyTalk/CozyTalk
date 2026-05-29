import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/connectivity_provider.dart';
import 'package:mobile/shared/network_info.dart';

class _FakeNetworkInfo implements NetworkInfo {
  final StreamController<bool> controller;

  _FakeNetworkInfo(this.controller);

  @override
  Stream<bool> get onConnectivityChanged => controller.stream;

  @override
  Future<bool> get isConnected async => false;
}

void main() {
  group('isOnlineProvider', () {
    test('starts as AsyncLoading before stream emits', () {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      final container = ProviderContainer(
        overrides: [
          networkInfoProvider.overrideWithValue(_FakeNetworkInfo(controller)),
        ],
      );
      addTearDown(container.dispose);

      final value = container.read(isOnlineProvider);
      expect(value, isA<AsyncLoading<bool>>());
    });

    test('emits true when stream emits true', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      final container = ProviderContainer(
        overrides: [
          networkInfoProvider.overrideWithValue(_FakeNetworkInfo(controller)),
        ],
      );
      addTearDown(container.dispose);

      // Subscribe first so the stream is being listened to.
      final sub = container.listen(isOnlineProvider, (_, _) {});
      addTearDown(sub.close);

      controller.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(isOnlineProvider).value, true);
    });

    test('emits false when stream emits false', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      final container = ProviderContainer(
        overrides: [
          networkInfoProvider.overrideWithValue(_FakeNetworkInfo(controller)),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(isOnlineProvider, (_, _) {});
      addTearDown(sub.close);

      controller.add(false);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(isOnlineProvider).value, false);
    });

    test('transitions: true then false → final value is false', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      final container = ProviderContainer(
        overrides: [
          networkInfoProvider.overrideWithValue(_FakeNetworkInfo(controller)),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(isOnlineProvider, (_, _) {});
      addTearDown(sub.close);

      controller.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(isOnlineProvider).value, true);

      controller.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(isOnlineProvider).value, false);
    });
  });
}
