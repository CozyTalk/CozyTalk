import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/word_filter_database_helper.dart';
import '../../data/datasources/word_filter_datasource.dart';
import '../../data/repositories/word_filter_repository_impl.dart';
import '../../domain/repositories/word_filter_repository.dart';
import '../../domain/usecases/censor_text.dart';

final _wordFilterDatasourceProvider = Provider<WordFilterDatasource>(
  (ref) => WordFilterDatasourceImpl(
    WordFilterDatabaseHelper(),
    FirebaseRemoteConfig.instance,
  ),
);

final wordFilterRepositoryProvider = Provider<WordFilterRepository>(
  (ref) => WordFilterRepositoryImpl(ref.watch(_wordFilterDatasourceProvider)),
);

final censorTextProvider = Provider<CensorText>(
  (ref) => CensorText(ref.watch(wordFilterRepositoryProvider)),
);
