import '../entities/hello_message.dart';
import '../repositories/hello_repository.dart';

class CallHello {
  final HelloRepository _repository;
  const CallHello(this._repository);
  Future<HelloMessage> call(String message) => _repository.callHello(message);
}
