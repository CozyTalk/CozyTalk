import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/hello_datasource.dart';
import '../../data/repositories/hello_repository_impl.dart';
import '../../domain/entities/hello_message.dart';
import '../../domain/repositories/hello_repository.dart';
import '../../domain/usecases/call_hello.dart';

final _helloDatasourceProvider = Provider<HelloDatasource>(
  (ref) => HelloDatasourceImpl(FirebaseFunctions.instance),
);

final _helloRepositoryProvider = Provider<HelloRepository>(
  (ref) => HelloRepositoryImpl(ref.watch(_helloDatasourceProvider)),
);

final _callHelloProvider = Provider<CallHello>(
  (ref) => CallHello(ref.watch(_helloRepositoryProvider)),
);

final helloNotifierProvider = NotifierProvider<HelloNotifier, HelloState>(
  HelloNotifier.new,
);

const _sentinel = Object();

class HelloState {
  final HelloMessage? result;
  final bool isLoading;
  final String? error;

  const HelloState({this.result, this.isLoading = false, this.error});

  HelloState copyWith({
    Object? result = _sentinel,
    bool? isLoading,
    Object? error = _sentinel,
  }) => HelloState(
    result: result == _sentinel ? this.result : result as HelloMessage?,
    isLoading: isLoading ?? this.isLoading,
    error: error == _sentinel ? this.error : error as String?,
  );
}

class HelloNotifier extends Notifier<HelloState> {
  @override
  HelloState build() => const HelloState();

  Future<void> callHello(String message) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await ref.read(_callHelloProvider)(message);
      state = state.copyWith(isLoading: false, result: result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
