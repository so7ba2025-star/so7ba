import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/rooms_repository.dart';
import 'package:so7ba/models/room_models.dart';
import 'package:so7ba/models/match_models.dart' as models;
import 'scoring_screen_onlie.dart' as scoring_online;

class _RoundEditResult {
  final int points;
  final String team;
  const _RoundEditResult({required this.points, required this.team});
}

class OngoingMatchesScreen extends StatefulWidget {
  final Room? room;
  const OngoingMatchesScreen({super.key, this.room});

  @override
  State<OngoingMatchesScreen> createState() => _OngoingMatchesScreenState();
}

class _OngoingMatchesScreenState extends State<OngoingMatchesScreen>
    with SingleTickerProviderStateMixin {
  String? _roomId;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  RealtimeChannel? _channel;
  final Set<String> _expandedIds = {};
  final Map<String, List<Map<String, dynamic>>> _roundsCache = {};
  final Set<String> _roundsLoading = {};
  bool _isPrefetchingRounds = false;
  late AnimationController _bgController;
  final Map<String, RealtimeChannel> _roundSubscriptions = {};
  String? _currentUserId;
  final List<Color> _bgGradientColors = const [
    Color(0xFF3A0000),
    Color(0xFFB30000),
  ];

  String _teamNameA(models.DominoMatch m) {
    if (m.mode == models.MatchMode.oneVOne) return m.players.a1;
    return '${m.players.a1} • ${m.players.a2 ?? ''}'.trim();
  }

  Future<void> _prefetchRoundsFor(List<String> matchIds) async {
    if (matchIds.isEmpty || _isPrefetchingRounds) return;
    // Filter out those already cached or loading
    final missing = matchIds
        .where((id) =>
            !_roundsCache.containsKey(id) && !_roundsLoading.contains(id))
        .toList();
    if (missing.isEmpty) return;
    _isPrefetchingRounds = true;
    try {
      // Limit to a reasonable batch to avoid heavy query
      final batch = missing.length > 10 ? missing.sublist(0, 10) : missing;
      final rows = await Supabase.instance.client
          .from('rounds')
          .select('id, match_id, round_no, team, points, created_at')
          .inFilter('match_id', batch)
          .order('round_no', ascending: true);
      final list = (rows as List).cast<Map<String, dynamic>>();
      // Group by match_id
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final r in list) {
        final mid = r['match_id']?.toString();
        if (mid == null) continue;
        (grouped[mid] ??= []).add(r);
      }
      for (final id in batch) {
        _roundsCache[id] = grouped[id] ?? <Map<String, dynamic>>[];
      }
      if (mounted) setState(() {});
    } catch (_) {
      // ignore prefetch errors silently
    } finally {
      _isPrefetchingRounds = false;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRounds(String matchId) async {
    final rows = await Supabase.instance.client
        .from('rounds')
        .select('id, round_no, team, points, created_at')
        .eq('match_id', matchId)
        .order('round_no', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _refreshRounds(String matchId) async {
    if (_roundsLoading.contains(matchId)) return;
    _roundsLoading.add(matchId);
    try {
      final list = await _fetchRounds(matchId);
      if (!mounted) return;
      setState(() {
        _roundsCache[matchId] = list;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _roundsCache[matchId] = const [];
      });
    } finally {
      _roundsLoading.remove(matchId);
    }
  }

  String _teamNameB(models.DominoMatch m) {
    if (m.mode == models.MatchMode.oneVOne) return m.players.b1;
    return '${m.players.b1} • ${m.players.b2 ?? ''}'.trim();
  }

  Map<String, dynamic>? _normalizeMetadata(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // ignore decoding errors and fall through to null
      }
    }
    return null;
  }

  Map<String, dynamic>? _slotMetadata(
    Map<String, dynamic>? metadata,
    String slot,
  ) {
    if (metadata == null) return null;
    final lower = slot.toLowerCase();
    if (!metadata.containsKey(lower)) return null;
    final value = metadata[lower];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, String?> _resolvePlayerInfo(
    models.DominoMatch match,
    String slot,
    Map<String, dynamic>? metadata,
  ) {
    final slotMetadata = _slotMetadata(metadata, slot);
    final fallbackName = () {
      switch (slot.toLowerCase()) {
        case 'a1':
          return match.players.a1;
        case 'a2':
          return match.players.a2 ?? '';
        case 'b1':
          return match.players.b1;
        case 'b2':
          return match.players.b2 ?? '';
        default:
          return '';
      }
    }();

    final resolvedNameRaw =
        (slotMetadata?['display_name'] ?? slotMetadata?['name'])
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
            ? slotMetadata!['display_name']?.toString().trim().isNotEmpty == true
                ? slotMetadata['display_name'].toString().trim()
                : slotMetadata['name'].toString().trim()
            : fallbackName.trim();
    final displayName = _shortDisplayName(resolvedNameRaw);

    final members = widget.room?.members ?? const <RoomMember>[];
    String? avatarUrl = slotMetadata?['avatar_url']?.toString();
    if (avatarUrl == null || avatarUrl.isEmpty) {
      for (final m in members) {
        if (m.userId == slotMetadata?['user_id'] || m.displayName == fallbackName) {
          avatarUrl = m.avatarUrl;
          break;
        }
      }
    }

    if ((avatarUrl == null || avatarUrl.isEmpty) &&
        (resolvedNameRaw.trim().isNotEmpty || displayName.isNotEmpty)) {
      for (final m in members) {
        final memberName = m.displayName.trim();
        if (memberName == resolvedNameRaw.trim() || memberName == displayName) {
          avatarUrl = m.avatarUrl;
          break;
        }
      }
    }

    return {
      'name': displayName,
      'avatar': (avatarUrl ?? '').trim().isNotEmpty ? avatarUrl!.trim() : null,
    };
  }

  String _initial(String s) {
    final t = s.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  String _shortDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;

    final hashIndex = trimmed.indexOf('#');
    final withoutDiscriminator = hashIndex > 0
        ? trimmed.substring(0, hashIndex).trim()
        : trimmed;

    final parts = withoutDiscriminator.split(RegExp(r'\s+'));
    for (final part in parts) {
      if (part.isNotEmpty) {
        return part;
      }
    }
    return withoutDiscriminator;
  }

  List<Map<String, String?>> _teamPlayers(
    models.DominoMatch match,
    String teamKey,
    Map<String, dynamic>? metadata,
  ) {
    final key = teamKey.toLowerCase();
    final slots = <String>[
      key == 'b' ? 'b1' : 'a1',
      if (match.mode == models.MatchMode.twoVTwo)
        if (key == 'b') 'b2' else 'a2',
    ];

    final players = <Map<String, String?>>[];
    for (final slot in slots) {
      final info = _resolvePlayerInfo(match, slot, metadata);
      if ((info['name'] ?? '').trim().isNotEmpty) {
        players.add(info);
      }
    }
    return players;
  }

  Widget _buildAvatarCircle(Map<String, String?> playerInfo) {
    final name = playerInfo['name'] ?? '';
    final avatarUrl = playerInfo['avatar'];
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
        color: avatarUrl == null ? Colors.white.withOpacity(0.18) : Colors.white,
        image: avatarUrl != null
            ? DecorationImage(
                image: NetworkImage(avatarUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: avatarUrl == null
          ? Text(
              _initial(name),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Widget _buildTeamAvatar(
      models.DominoMatch match, String teamKey, Map<String, dynamic>? metadata) {
    final players = _teamPlayers(match, teamKey, metadata);
    if (players.isEmpty) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.12),
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.help_outline, color: Colors.white70, size: 18),
      );
    }

    if (match.mode != models.MatchMode.twoVTwo || players.length == 1) {
      return _buildAvatarCircle(players.first);
    }

    return SizedBox(
      width: players.length > 1 ? 66 : 38,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < players.length; index++)
            Positioned(
              left: index * 24.0,
              child: _buildAvatarCircle(players[index]),
            ),
        ],
      ),
    );
  }

  String _teamLabel(
      models.DominoMatch match, String teamKey, Map<String, dynamic>? metadata) {
    final players = _teamPlayers(match, teamKey, metadata)
        .map((p) => (p['name'] ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (players.isNotEmpty) {
      return players.join(' • ');
    }
    return teamKey.toLowerCase() == 'b'
        ? _teamNameB(match)
        : _teamNameA(match);
  }

  Widget _buildHeroAvatar(Map<String, String?> info, double radius) {
    final name = (info['name'] ?? '').trim();
    final avatarUrl = (info['avatar'] ?? '').trim();
    final hasAvatar = avatarUrl.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          hasAvatar ? Colors.white : Colors.white.withOpacity(0.2),
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      child: hasAvatar
          ? null
          : Text(
              _initial(name),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Future<void> _endMatch(BuildContext context, models.DominoMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إنهاء المباراة'),
          content: Text(
              'هل أنت متأكد من أنك تريد إنهاء مباراة ${_teamNameA(match)} ضد ${_teamNameB(match)}؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('إنهاء'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final supabase = Supabase.instance.client;
      String? winningTeam;
      final scoreA = match.rounds
          .where((r) => r.winner == models.Team.a)
          .fold<int>(0, (sum, r) => sum + r.points);
      final scoreB = match.rounds
          .where((r) => r.winner == models.Team.b)
          .fold<int>(0, (sum, r) => sum + r.points);
      if (scoreA > scoreB) {
        winningTeam = 'a';
      } else if (scoreB > scoreA) {
        winningTeam = 'b';
      }

      await supabase.from('matches').update({
        'status': 'finished',
        'finished_at': DateTime.now().toIso8601String(),
        'winning_team': winningTeam,
      }).eq('id', match.id);
      if (mounted) _reload();
    }
  }

  @override
  void initState() {
    super.initState();
    _bgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 15))
          ..repeat();
    _init();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    for (final channel in _roundSubscriptions.values) {
      Supabase.instance.client.removeChannel(channel);
    }
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final roomsRepo = RoomsRepository();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final rid = widget.room?.id ??
        (await roomsRepo.roomStream.firstWhere((r) => r != null))!.id;
    setState(() => _roomId = rid);
    await _subscribeRealtime();
    await _reload();
  }

  bool _isMatchCreator(models.DominoMatch match) {
    return match.creatorId != null && match.creatorId == _currentUserId;
  }

  Future<void> _recalculateMatchScores(String matchId) async {
    try {
      final client = Supabase.instance.client;
      final rounds = await client
          .from('rounds')
          .select('team, points')
          .eq('match_id', matchId);

      int totalA = 0;
      int totalB = 0;
      for (final r in rounds as List) {
        final team = (r['team'] as String?)?.toLowerCase();
        final points = (r['points'] ?? 0) as int;
        if (team == 'b') {
          totalB += points;
        } else {
          totalA += points;
        }
      }

      await client.from('matches').update({
        'score_a': totalA,
        'score_b': totalB,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', matchId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تحديث نتيجة المباراة: $e')),
      );
    }
  }

  Future<_RoundEditResult?> _showEditRoundDialog(
    Map<String, dynamic> round,
  ) {
    final pointsController = TextEditingController(
      text: '${round['points'] ?? 0}',
    );
    String selectedTeam = (round['team'] as String?)?.toLowerCase() == 'b'
        ? 'b'
        : 'a';
    String? errorMessage;

    return showDialog<_RoundEditResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('تعديل الجولة رقم ${round['round_no'] ?? ''}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pointsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: 'النقاط',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedTeam,
                    style: const TextStyle(color: Colors.black),
                    dropdownColor: Colors.white,
                    items: const [
                      DropdownMenuItem(value: 'a', child: Text('فريق أ')),
                      DropdownMenuItem(value: 'b', child: Text('فريق ب')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selectedTeam = value);
                    },
                    decoration: const InputDecoration(labelText: 'الفريق الفائز'),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () {
                    final parsed = int.tryParse(pointsController.text);
                    if (parsed == null || parsed <= 0) {
                      setState(() =>
                          errorMessage = 'يرجى إدخال قيمة صحيحة للنقاط (أكبر من صفر).');
                      return;
                    }
                    Navigator.of(context).pop(
                      _RoundEditResult(points: parsed, team: selectedTeam),
                    );
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateRound(
    String matchId,
    Map<String, dynamic> round,
    _RoundEditResult result,
  ) async {
    final currentId = round['id'];
    if (currentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن تعديل هذه الجولة.')),
      );
      return;
    }

    final oldPoints = (round['points'] ?? 0) as int;
    final oldTeam = (round['team'] as String?)?.toLowerCase() ?? 'a';
    if (oldPoints == result.points && oldTeam == result.team) {
      return;
    }

    try {
      final client = Supabase.instance.client;
      await client.from('rounds').update({
        'points': result.points,
        'team': result.team,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', currentId);

      await _recalculateMatchScores(matchId);
      await _refreshRounds(matchId);
      await _reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعديل الجولة بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تعديل الجولة: $e')),
      );
    }
  }

  Future<void> _subscribeRealtime() async {
    if (_roomId == null) return;
    _channel = Supabase.instance.client.channel('public:matches');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: _roomId!,
          ),
          callback: (payload) {
            if (!mounted) return;
            final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
            final matchId = record['id']?.toString();

            if (matchId != null) {
              _subscribeToRounds(matchId);
            }

            _reload();
          },
        )
        .subscribe();
  }

  void _subscribeToRounds(String matchId) {
    if (_roundSubscriptions.containsKey(matchId)) return;

    final channel = Supabase.instance.client
        .channel('public:rounds_match_$matchId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'rounds',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'match_id',
          value: matchId,
        ),
        callback: (payload) {
          final round = Map<String, dynamic>.from(payload.newRecord);

          setState(() {
            final existing = List<Map<String, dynamic>>.from(
                _roundsCache[matchId] ?? const []);
            existing.removeWhere((r) => r['round_no'] == round['round_no']);
            existing.add(round);
            existing.sort((a, b) =>
                ((a['round_no'] ?? 0) as int).compareTo((b['round_no'] ?? 0) as int));
            _roundsCache[matchId] = existing;
          });
        },
      )
      ..subscribe();

    _roundSubscriptions[matchId] = channel;
  }

  Future<void> _reload() async {
    if (_roomId == null) return;
    setState(() => _loading = true);
    final rows = await Supabase.instance.client
        .from('matches')
        .select()
        .eq('room_id', _roomId!)
        .or('status.is.null,status.eq.ongoing')
        .order('start_time');
    final list = (rows as List).cast<Map<String, dynamic>>();
    debugPrint('🔁 _reload fetched ${list.length} matches for room $_roomId');
    for (final row in list) {
      debugPrint('  • match ${row['id']} status=${row['status']} room=${row['room_id']}');
    }
    final items = list.map(_mapRow).toList();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });

    // Ensure expanded cards show latest rounds immediately
    for (final matchId in _expandedIds) {
      _refreshRounds(matchId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('المباريات الجارية'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 136, 4, 4),
              Color.fromARGB(255, 194, 2, 2),
            ],
          ),
        ),
        child: Stack(
          children: [
            ...List.generate(
              9,
              (index) => Positioned(
                top: (MediaQuery.of(context).size.height) * (index + 1) / 10 -
                    90,
                right: (MediaQuery.of(context).size.width) *
                        ((index % 5) + 1) /
                        6 -
                    90,
                child: AnimatedBuilder(
                  animation: _bgController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _bgController.value * 2 * 3.1415926535,
                      child: Opacity(
                        opacity: 0.3,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _bgGradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              left: false,
              right: false,
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_roomId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final stream = Supabase.instance.client
        .from('matches')
        .stream(primaryKey: ['id']).order('start_time');

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('خطأ في التحديث اللحظي: ${snap.error}'));
        }
        final rows = snap.data ?? const [];
        debugPrint('📡 Stream emitted ${rows.length} rows for matches');
        final filtered = rows.where((r) {
          final roomIdValue = r['room_id']?.toString();
          if (roomIdValue != _roomId) return false;
          final status = (r['status'] as String?)?.trim();
          return status == null || status.isEmpty || status == 'ongoing';
        }).toList();
        if (filtered.isEmpty) {
          return const Center(
            child: Text('لا توجد مباريات جارية حالياً',
                style: TextStyle(fontSize: 18, color: Color(0xFF757575))),
          );
        }
        final items = filtered.map(_mapRow).toList();
        // Prefetch rounds for visible matches in the background to make expansion instant
        // Schedule after frame to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ids =
              items.map((e) => (e['match'] as models.DominoMatch).id).toList();
          _prefetchRoundsFor(ids);
        });
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final row = items[i];
              final match = row['match'] as models.DominoMatch;
              final scoreA = row['score_a'] as int;
              final scoreB = row['score_b'] as int;
              final metadata = row['metadata'] as Map<String, dynamic>?;
              final playerA1 = _resolvePlayerInfo(match, 'a1', metadata);
              final playerA2 = match.mode == models.MatchMode.twoVTwo
                  ? _resolvePlayerInfo(match, 'a2', metadata)
                  : {'name': '', 'avatar': null};
              final playerB1 = _resolvePlayerInfo(match, 'b1', metadata);
              final playerB2 = match.mode == models.MatchMode.twoVTwo
                  ? _resolvePlayerInfo(match, 'b2', metadata)
                  : {'name': '', 'avatar': null};
              final teamALabel = _teamLabel(match, 'a', metadata);
              final teamBLabel = _teamLabel(match, 'b', metadata);
              final roundEntries = _roundsCache[match.id];
              final currentRoundNumber =
                  (roundEntries == null || roundEntries.isEmpty)
                      ? 1
                      : roundEntries.length + 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 6,
                  shadowColor: Colors.black.withOpacity(0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white.withOpacity(0.06),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => scoring_online.ScoringScreen(
                            match: match,
                            playersMetadata: metadata,
                          ),
                        ),
                      );
                    },
                    onLongPress: () => _endMatch(context, match),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Playstation-style hero card section
                          SizedBox(
                            height: 180,
                            child: Stack(
                              children: [
                                // Gradient background box with glow
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: _bgGradientColors,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Color(0x33000000),
                                            blurRadius: 14,
                                            offset: Offset(0, 8)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Subtle lightning icons
                                Positioned.fill(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Icon(Icons.bolt,
                                          size: 64,
                                          color:
                                              Colors.white.withOpacity(0.08)),
                                      Icon(Icons.bolt,
                                          size: 64,
                                          color:
                                              Colors.white.withOpacity(0.08)),
                                    ],
                                  ),
                                ),
                                // Bottom-right: expand toggle
                                Positioned(
                                  right: 2,
                                  bottom: 8,
                                  child: IconButton(
                                    tooltip: 'عرض/إخفاء الجولات',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    visualDensity: VisualDensity.compact,
                                    color: Colors.white,
                                    icon: Icon(
                                        _expandedIds.contains(match.id)
                                            ? Icons.expand_less
                                            : Icons.expand_more),
                                    onPressed: () async {
                                      if (_expandedIds.contains(match.id)) {
                                        setState(() =>
                                            _expandedIds.remove(match.id));
                                        return;
                                      }
                                      setState(() =>
                                          _expandedIds.add(match.id));
                                      _subscribeToRounds(match.id);
                                      await _refreshRounds(match.id);
                                    },
                                  ),
                                ),
                                // Top-right: refresh
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        tooltip: 'تحديث الجولات',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                        color: Colors.white,
                                        icon: const Icon(Icons.refresh),
                                        onPressed: () {
                                          _subscribeToRounds(match.id);
                                          _refreshRounds(match.id);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                // Center avatars and names
                                // Center divider line overlay
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 2,
                                      margin:
                                          const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withOpacity(0.0),
                                            Colors.white.withOpacity(0.7),
                                            Colors.white.withOpacity(0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (match.mode ==
                                                models.MatchMode.twoVTwo)
                                              SizedBox(
                                                height: 72,
                                                width: 96,
                                                child: Stack(
                                                  children: [
                                                    Positioned(
                                                      left: 0,
                                                      child: _buildHeroAvatar(
                                                          playerA1, 32),
                                                    ),
                                                    if ((playerA2['name'] ?? '')
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty)
                                                      Positioned(
                                                        left: 36,
                                                        top: 8,
                                                        child: _buildHeroAvatar(
                                                            playerA2, 28),
                                                      ),
                                                  ],
                                                ),
                                              )
                                            else
                                              _buildHeroAvatar(playerA1, 36),
                                            const SizedBox(height: 8),
                                            Text(
                                              teamALabel,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (match.mode ==
                                                models.MatchMode.twoVTwo)
                                              SizedBox(
                                                height: 72,
                                                width: 96,
                                                child: Stack(
                                                  children: [
                                                    Positioned(
                                                      right: 0,
                                                      child: _buildHeroAvatar(
                                                          playerB1, 32),
                                                    ),
                                                    if ((playerB2['name'] ?? '')
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty)
                                                      Positioned(
                                                        right: 36,
                                                        top: 8,
                                                        child: _buildHeroAvatar(
                                                            playerB2, 28),
                                                      ),
                                                  ],
                                                ),
                                              )
                                            else
                                              _buildHeroAvatar(playerB1, 36),
                                            const SizedBox(height: 8),
                                            Text(
                                              teamBLabel,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Center stylized VS
                                Center(
                                  child: Text(
                                    'VS',
                                    style: TextStyle(
                                      fontSize: 56,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white.withOpacity(0.95),
                                      letterSpacing: 3,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x33FFFFFF),
                                          blurRadius: 14,
                                        ),
                                        Shadow(
                                          color: Color(0x33000000),
                                          offset: Offset(0, 8),
                                          blurRadius: 22,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.92),
                                            Colors.white.withOpacity(0.85),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.18),
                                            blurRadius: 10,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Text('$scoreA',
                                          style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF8A0303))),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(minWidth: 120),
                                    child: Container(
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Colors.white.withOpacity(0.24),
                                            Colors.white.withOpacity(0.14),
                                          ],
                                        ),
                                      ),
                                      child: Text(
                                        'الجولة ${currentRoundNumber.clamp(1, 999)}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.92),
                                            Colors.white.withOpacity(0.85),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.18),
                                            blurRadius: 10,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Text('$scoreB',
                                          style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF8A0303))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_expandedIds.contains(match.id))
                            _roundsLoading.contains(match.id)
                                ? const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  )
                                : ((_roundsCache[match.id] ?? const []).isEmpty
                                    ? Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text('لا توجد جولات بعد',
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.75),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500)),
                                      )
                                    : ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount:
                                            _roundsCache[match.id]!.length,
                                        separatorBuilder: (_, __) => Divider(
                                            color:
                                                Colors.grey.withOpacity(0.2)),
                                        itemBuilder: (context, idx) {
                                          final r =
                                              _roundsCache[match.id]![idx];
                                          final rn = r['round_no'] ?? idx + 1;
                                          final teamKey =
                                              ((r['team'] as String?) ?? 'a')
                                                  .toLowerCase();
                                          final pts = r['points'] ?? 0;
                                          final winnerAvatar = _buildTeamAvatar(
                                              match, teamKey, metadata);
                                          final roundId = r['id'];
                                          final canEdit = roundId != null &&
                                              _isMatchCreator(match);
                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 34,
                                                    height: 34,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.18),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Text(
                                                      '$rn',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  winnerAvatar,
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(Icons.stars,
                                                      size: 16,
                                                      color: Colors.amber),
                                                  const SizedBox(width: 6),
                                                  Text('$pts',
                                                      style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Colors.white)),
                                                  if (canEdit) ...[
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.edit,
                                                        size: 18,
                                                        color:
                                                            Color(0xFFFFD54F),
                                                      ),
                                                      tooltip: 'تعديل الجولة',
                                                      onPressed: () async {
                                                        final result =
                                                            await _showEditRoundDialog(
                                                                r);
                                                        if (result == null) {
                                                          return;
                                                        }
                                                        await _updateRound(
                                                            match.id,
                                                            r,
                                                            result);
                                                      },
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          );
                                        },
                                      )),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }, // end itemBuilder
          ), // end ListView.builder
        ); // end RefreshIndicator
      }, // end StreamBuilder builder
    ); // end StreamBuilder
  }

  Map<String, dynamic> _mapRow(Map<String, dynamic> row) {
    final modeStr = (row['mode'] as String?) ?? 'one_v_one';
    final mode = modeStr == 'two_v_two'
        ? models.MatchMode.twoVTwo
        : models.MatchMode.oneVOne;
    final playersJson = Map<String, dynamic>.from(row['players'] as Map);
    final metadata = _normalizeMetadata(row['players_metadata']);
    final match = models.DominoMatch(
      id: row['id'].toString(),
      startTime: DateTime.parse(row['start_time'] as String),
      mode: mode,
      players: models.PlayerNames(
        a1: (playersJson['a1'] ?? '') as String,
        a2: playersJson['a2'] as String?,
        b1: (playersJson['b1'] ?? '') as String,
        b2: playersJson['b2'] as String?,
      ),
      creatorId: row['created_by'] as String?,
    );
    return {
      'match': match,
      'score_a': (row['score_a'] ?? 0) as int,
      'score_b': (row['score_b'] ?? 0) as int,
      'metadata': metadata,
    };
  }
}
