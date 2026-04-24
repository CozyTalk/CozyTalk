// interface - any HelloRepository object created should impl callHello
import '../entities/hello_message.dart';

abstract class HelloRepository {
  Future<HelloMessage> callHello(String message);
}
