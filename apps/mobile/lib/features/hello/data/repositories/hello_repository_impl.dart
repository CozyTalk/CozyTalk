// this impl the interface using impl from datasource ( could call multiple datasources )
import '../../domain/entities/hello_message.dart';
import '../../domain/repositories/hello_repository.dart';
import '../datasources/hello_datasource.dart';
import '../models/hello_message_model.dart';

class HelloRepositoryImpl implements HelloRepository {
  final HelloDatasource _datasource;
  HelloRepositoryImpl(this._datasource);

  @override
  Future<HelloMessage> callHello(String message) async {
    final model = await _datasource.callHello(message);
    return model.toEntity();
  }
}
