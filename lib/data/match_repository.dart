import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:so7ba/models/match_models.dart';

class MatchRepository {
  static const _kOngoing = 'ongoing_matches';
  static const _kFinished = 'finished_matches';

  MatchRepository._();
  static final MatchRepository instance = MatchRepository._();

  Future<List<DominoMatch>> getOngoing() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kOngoing);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((e) => DominoMatch.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<List<DominoMatch>> getFinished() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFinished);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((e) => DominoMatch.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<void> _saveOngoing(List<DominoMatch> matches) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kOngoing,
      jsonEncode(matches.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveFinished(List<DominoMatch> matches) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kFinished,
      jsonEncode(matches.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> createOngoing(DominoMatch match) async {
    final list = await getOngoing();
    list.add(match);
    await _saveOngoing(list);
  }

  Future<void> updateOngoing(DominoMatch match) async {
    final list = await getOngoing();
    final idx = list.indexWhere((m) => m.id == match.id);
    if (idx >= 0) {
      list[idx] = match;
      await _saveOngoing(list);
    } else {
      // if not found, add it
      list.add(match);
      await _saveOngoing(list);
    }
  }

  Future<void> finishMatch(DominoMatch match) async {
    final ongoing = await getOngoing();
    ongoing.removeWhere((m) => m.id == match.id);
    await _saveOngoing(ongoing);

    final finished = await getFinished();
    finished.add(match);
    await _saveFinished(finished);
  }
}
