import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PlayersRepository {
  static const _kRoster = 'players_roster_v1';
  static final PlayersRepository instance = PlayersRepository._();
  PlayersRepository._();

  Future<List<String>> getRoster() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRoster);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List<dynamic>).cast<String>();
    return list;
  }

  Future<void> _saveRoster(List<String> roster) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRoster, jsonEncode(roster));
  }

  Future<void> addName(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    final roster = await getRoster();
    roster.removeWhere((e) => e.toLowerCase() == n.toLowerCase());
    roster.insert(0, n);
    // keep top 50
    if (roster.length > 50) roster.removeRange(50, roster.length);
    await _saveRoster(roster);
  }

  Future<void> addMany(Iterable<String?> names) async {
    final set = <String>{};
    for (final s in names) {
      if (s == null) continue;
      final n = s.trim();
      if (n.isNotEmpty) set.add(n);
    }
    if (set.isEmpty) return;
    final roster = await getRoster();
    // remove existing duplicates (case-insensitive)
    for (final n in set) {
      roster.removeWhere((e) => e.toLowerCase() == n.toLowerCase());
    }
    roster.insertAll(0, set);
    if (roster.length > 50) roster.removeRange(50, roster.length);
    await _saveRoster(roster);
  }

  Future<void> updateName(String oldName, String newName) async {
    if (oldName.trim().isEmpty || newName.trim().isEmpty) return;
    final roster = await getRoster();
    final index = roster.indexWhere((e) => e.toLowerCase() == oldName.toLowerCase());
    if (index != -1) {
      roster[index] = newName.trim();
      await _saveRoster(roster);
    }
  }

  Future<void> removeName(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    final roster = await getRoster();
    roster.removeWhere((e) => e.toLowerCase() == n.toLowerCase());
    await _saveRoster(roster);
  }
}
