import 'package:mobile/features/word_filter/domain/repositories/word_filter_repository.dart';

class FakeWordFilterRepository implements WordFilterRepository {
  FakeWordFilterRepository({this.returnValue = '', this.shouldThrow = false});

  final String returnValue;
  final bool shouldThrow;

  int callCount = 0;
  String? lastArg;

  @override
  Future<String> censorText(String text) async {
    callCount++;
    lastArg = text;
    if (shouldThrow) throw Exception('censor error');
    return returnValue;
  }
}
