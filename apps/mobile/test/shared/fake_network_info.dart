import 'package:mobile/shared/network_info.dart';

class FakeNetworkInfo implements NetworkInfo {
  final bool _isOnline;

  FakeNetworkInfo({required bool isOnline}) : _isOnline = isOnline;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(_isOnline);

  @override
  Future<bool> get isConnected async => _isOnline;
}
