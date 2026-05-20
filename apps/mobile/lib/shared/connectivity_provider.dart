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
final isOnlineProvider = StreamProvider<bool>((ref) {
  final networkInfo = ref.watch(networkInfoProvider);
  StreamSubscription<bool>? changeSub;
  final ctrl = StreamController<bool>();

  // Emit current state first, then pipe all future changes.
  networkInfo.isConnected.then((initial) {
    if (ctrl.isClosed) return;
    ctrl.add(initial);
    changeSub = networkInfo.onConnectivityChanged.listen(
      (v) {
        if (!ctrl.isClosed) ctrl.add(v);
      },
      onDone: () {
        if (!ctrl.isClosed) ctrl.close();
      },
    );
  });

  ref.onDispose(() {
    changeSub?.cancel();
    ctrl.close();
  });

  return ctrl.stream;
});
