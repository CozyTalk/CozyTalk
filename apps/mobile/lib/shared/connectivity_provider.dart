import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network_info.dart';

final networkInfoProvider = Provider<NetworkInfo>(
  (ref) => NetworkInfoImpl(Connectivity()),
);

/// Emits the current online state, seeded with the actual connectivity state
/// on startup so the OfflineChip shows immediately without waiting for a
/// connectivity change event.
///
/// Subscribes to [NetworkInfo.onConnectivityChanged] before the async
/// [NetworkInfo.isConnected] seed so no events are dropped during the startup
/// gap. If a change event arrives before the seed, the seed is skipped (the
/// change is more recent).
final isOnlineProvider = StreamProvider<bool>((ref) {
  final networkInfo = ref.watch(networkInfoProvider);
  final ctrl = StreamController<bool>();
  var seeded = false;

  final changeSub = networkInfo.onConnectivityChanged.listen(
    (v) {
      seeded = true;
      if (!ctrl.isClosed) ctrl.add(v);
    },
    onDone: () {
      if (!ctrl.isClosed) ctrl.close();
    },
  );

  networkInfo.isConnected.then((initial) {
    if (!ctrl.isClosed && !seeded) ctrl.add(initial);
  });

  ref.onDispose(() {
    changeSub.cancel();
    ctrl.close();
  });

  return ctrl.stream;
});
