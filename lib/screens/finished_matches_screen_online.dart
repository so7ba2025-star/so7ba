import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/rooms_repository.dart';
import 'package:so7ba/models/room_models.dart';
import 'package:so7ba/models/match_models.dart' as models;

class FinishedMatchesScreen extends StatefulWidget {
  final Room? room;
  const FinishedMatchesScreen({super.key, this.room});

  @override
  State<FinishedMatchesScreen> createState() => _FinishedMatchesScreenState();
}

class _FinishedMatchesScreenState extends State<FinishedMatchesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final roomsRepo = RoomsRepository();
      final roomId = widget.room?.id ?? (await roomsRepo.roomStream.firstWhere((r) => r != null))!.id;
      final resp = await supabase
          .from('matches')
          .select()
          .eq('room_id', roomId)
          .eq('status', 'finished')
          .order('finished_at', ascending: false);

      final items = (resp as List)
          .map((e) => e as Map<String, dynamic>)
          .map((row) {
            final modeStr = (row['mode'] as String?) ?? 'one_v_one';
            final mode = modeStr == 'two_v_two' ? models.MatchMode.twoVTwo : models.MatchMode.oneVOne;
            final playersJson = Map<String, dynamic>.from(row['players'] as Map);
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
              'finished_at': row['finished_at'] as String?,
            };
          })
          .toList();

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المباريات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المباريات المنتهية')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('لا توجد مباريات منتهية بعد')),
                        SizedBox(height: 120),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final row = _items[i];
                        final m = row['match'] as models.DominoMatch;
                        final scoreA = row['score_a'] as int;
                        final scoreB = row['score_b'] as int;
                        final aName = m.mode == models.MatchMode.oneVOne
                            ? m.players.a1
                            : '${m.players.a1} • ${m.players.a2 ?? ''}'.trim();
                        final bName = m.mode == models.MatchMode.oneVOne
                            ? m.players.b1
                            : '${m.players.b1} • ${m.players.b2 ?? ''}'.trim();
                        final score = '$scoreA - $scoreB';
                        final finishedAtStr = row['finished_at'] as String?;
                        final date = finishedAtStr != null
                            ? DateTime.parse(finishedAtStr)
                            : m.startTime;
                        final dateStr =
                            '${date.year}-${_two(date.month)}-${_two(date.day)} ${_two(date.hour)}:${_two(date.minute)}';
                        return Card(
                          child: ListTile(
                            title: Text('$aName  vs  $bName'),
                            subtitle: Text(
                              'النتيجة: $score\nالتاريخ: $dateStr',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.share),
                              onPressed: () {
                                // TODO: Generate share image and open share sheet (fallback to system if WhatsApp absent)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('')),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}
