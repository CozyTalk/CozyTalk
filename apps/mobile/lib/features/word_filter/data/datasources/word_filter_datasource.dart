import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'word_filter_database_helper.dart';

abstract class WordFilterDatasource {
  Future<String> censorText(String text);
  Future<void> seedIfNeeded();
}

class WordFilterDatasourceImpl implements WordFilterDatasource {
  WordFilterDatasourceImpl(this._dbHelper, this._isEnabled, this._prefs);

  final WordFilterDatabaseHelper _dbHelper;
  final bool Function() _isEnabled;
  final SharedPreferences _prefs;

  static const _keyDbSeeded = 'db_seeded_v1';

  Set<String>? _enWords;
  List<String>? _thWords;
  Future<void>? _initFuture;

  @override
  Future<void> seedIfNeeded() async {
    if (kIsWeb) return;

    if (_prefs.getBool(_keyDbSeeded) == true) return;

    final jsonStr = await rootBundle.loadString('assets/banned_words.json');
    final data = Map<String, dynamic>.from(json.decode(jsonStr) as Map);

    final enWords = (data['en'] as List<dynamic>).cast<String>();
    final thWords = (data['th'] as List<dynamic>).cast<String>();

    final wordMaps = [
      ...enWords.map((w) => {'word': w, 'language': 'en'}),
      ...thWords.map((w) => {'word': w, 'language': 'th'}),
    ];

    await _dbHelper.insertWordsBatch(wordMaps);
    await _prefs.setBool(_keyDbSeeded, true);
  }

  Future<void> _initWords() async {
    if (_enWords != null) return;
    final future = _initFuture ??= _loadWords();
    try {
      await future;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<void> _loadWords() async {
    if (kIsWeb) {
      final jsonStr = await rootBundle.loadString('assets/banned_words.json');
      final data = Map<String, dynamic>.from(json.decode(jsonStr) as Map);
      _enWords = {
        for (final w in (data['en'] as List<dynamic>))
          (w as String).toLowerCase(),
      };
      _thWords = (data['th'] as List<dynamic>).cast<String>();
    } else {
      await seedIfNeeded();
      final enRows = await _dbHelper.getWordsByLanguage('en');
      final thRows = await _dbHelper.getWordsByLanguage('th');
      _enWords = {for (final r in enRows) (r['word'] as String).toLowerCase()};
      _thWords = thRows.map((r) => r['word'] as String).toList();
    }
  }

  static final _stripPunct = RegExp(r'^[^a-zA-Z]+|[^a-zA-Z]+$');

  @override
  Future<String> censorText(String text) async {
    if (!_isEnabled()) return text;

    await _initWords();

    final tokens = text.split(' ');
    final censoredTokens = tokens.map((token) {
      final bare = token.replaceAll(_stripPunct, '').toLowerCase();
      if (bare.isNotEmpty && (_enWords ?? {}).contains(bare)) {
        return '*' * token.length;
      }
      return token;
    });
    var result = censoredTokens.join(' ');

    for (final word in (_thWords ?? [])) {
      result = result.replaceAll(word, '*' * word.length);
    }

    return result;
  }
}
