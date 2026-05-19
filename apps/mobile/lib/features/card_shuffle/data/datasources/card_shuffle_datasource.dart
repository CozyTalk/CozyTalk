import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/icebreaker_question.dart';
import '../models/icebreaker_question_model.dart';

abstract class CardShuffleDatasource {
  Future<IcebreakerQuestion> drawCard();
}

class CardShuffleDatasourceImpl implements CardShuffleDatasource {
  static const _keyRemaining = 'card_shuffle_remaining';
  static const _keySeen = 'card_shuffle_seen';
  static const _keyDrawCount = 'card_shuffle_draw_count';

  // First N draws are restricted to light/medium depth only.
  static const _warmupThreshold = 5;

  final Random _rng = Random();
  List<IcebreakerQuestionModel>? _allQuestions;

  Future<List<IcebreakerQuestionModel>> _loadQuestions() async {
    _allQuestions ??= await _parseAsset();
    return _allQuestions!;
  }

  Future<List<IcebreakerQuestionModel>> _parseAsset() async {
    final raw = await rootBundle.loadString('assets/icebreaker-questions.json');
    final list = json.decode(raw) as List;
    return list
        .map(
          (e) => IcebreakerQuestionModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  @override
  Future<IcebreakerQuestion> drawCard() async {
    final prefs = await SharedPreferences.getInstance();
    final questions = await _loadQuestions();
    final byId = {for (final q in questions) q.id: q};

    var remaining = _loadIds(prefs.getString(_keyRemaining));
    var seen = _loadIds(prefs.getString(_keySeen));
    var drawCount = prefs.getInt(_keyDrawCount) ?? 0;

    if (remaining.isEmpty && seen.isEmpty) {
      remaining = questions.map((q) => q.id).toList()..shuffle(_rng);
    }

    if (remaining.isEmpty) {
      remaining = List<String>.from(seen)..shuffle(_rng);
      seen = [];
    }

    final eligible = _buildEligible(remaining, byId, drawCount);
    final pickedId = eligible[_rng.nextInt(eligible.length)];

    remaining.remove(pickedId);
    seen.add(pickedId);
    drawCount++;

    await prefs.setString(_keyRemaining, json.encode(remaining));
    await prefs.setString(_keySeen, json.encode(seen));
    await prefs.setInt(_keyDrawCount, drawCount);

    return byId[pickedId]!.toEntity();
  }

  // During warmup only draw light/medium; fall back to all if none qualify.
  List<String> _buildEligible(
    List<String> remaining,
    Map<String, IcebreakerQuestionModel> byId,
    int drawCount,
  ) {
    if (drawCount >= _warmupThreshold) return remaining;
    final warmup = remaining.where((id) => byId[id]?.depth != 'deep').toList();
    return warmup.isNotEmpty ? warmup : remaining;
  }

  List<String> _loadIds(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = json.decode(raw) as List;
    return list.cast<String>();
  }
}
