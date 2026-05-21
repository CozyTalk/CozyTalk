import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkInfo {
  Stream<bool> get onConnectivityChanged;
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfoImpl(this._connectivity);

  @override
  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged
      .map((r) => r.any((c) => c != ConnectivityResult.none));

  @override
  Future<bool> get isConnected async {
    final r = await _connectivity.checkConnectivity();
    return r.any((c) => c != ConnectivityResult.none);
  }
}
