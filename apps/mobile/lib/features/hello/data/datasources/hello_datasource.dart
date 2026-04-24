import 'package:cloud_functions/cloud_functions.dart';

import '../models/hello_message_model.dart';

abstract class HelloDatasource {
  Future<HelloMessageModel> callHello(String message);
}

class HelloDatasourceImpl implements HelloDatasource {
  final FirebaseFunctions _functions;
  HelloDatasourceImpl(this._functions);

  @override
  Future<HelloMessageModel> callHello(String message) async {
    final result = await _functions
        .httpsCallable('helloWorld')
        .call({'message': message});
    final data = result.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected response format from helloWorld');
    }
    return HelloMessageModel.fromJson(data);
  }
}
