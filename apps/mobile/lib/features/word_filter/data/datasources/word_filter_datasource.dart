// ROLLBACK PLAN:
// If content filtering causes false positives or performance issues:
// 1. Go to Firebase Remote Config console
// 2. Set content_filtering_enabled = false
// 3. Publish — change propagates to all active clients within ~60 seconds
// 4. No app store release required

import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'word_filter_database_helper.dart';

abstract class WordFilterDatasource {
  Future<String> censorText(String text);
  Future<void> seedIfNeeded();
}

class WordFilterDatasourceImpl implements WordFilterDatasource {
  WordFilterDatasourceImpl(this._dbHelper, this._remoteConfig, this._prefs);

  final WordFilterDatabaseHelper _dbHelper;
  final FirebaseRemoteConfig _remoteConfig;
  final SharedPreferences _prefs;

  static const _keyDbSeeded = 'db_seeded_v1';
  static const _flagName = 'content_filtering_enabled';

  List<String>? _enWords;
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

  Future<void> _initWords() {
    _initFuture ??= _loadWords();
    return _initFuture!;
  }

  Future<void> _loadWords() async {
    if (kIsWeb) {
      // Web: load directly from bundled JSON — SQLite not available on web
      final jsonStr = await rootBundle.loadString('assets/banned_words.json');
      final data = Map<String, dynamic>.from(json.decode(jsonStr) as Map);
      _enWords = (data['en'] as List<dynamic>).cast<String>();
      _thWords = (data['th'] as List<dynamic>).cast<String>();
    } else {
      await seedIfNeeded();
      final enRows = await _dbHelper.getWordsByLanguage('en');
      final thRows = await _dbHelper.getWordsByLanguage('th');
      _enWords = enRows.map((r) => r['word'] as String).toList();
      _thWords = thRows.map((r) => r['word'] as String).toList();
    }
  }

  @override
  Future<String> censorText(String text) async {
    if (!_remoteConfig.getBool(_flagName)) return text;

    await _initWords();

    final tokens = text.split(' ');
    final censoredTokens = tokens.map((token) {
      if ((_enWords ?? []).any((w) => w.toLowerCase() == token.toLowerCase())) {
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
