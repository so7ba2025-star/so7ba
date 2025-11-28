import 'package:flutter/material.dart';
import '../data/match_repository.dart';
import 'package:so7ba/models/match_models.dart';

class FinishedMatchesScreen extends StatefulWidget {
  const FinishedMatchesScreen({super.key});

  @override
  State<FinishedMatchesScreen> createState() => _FinishedMatchesScreenState();
}

class _FinishedMatchesScreenState extends State<FinishedMatchesScreen> {
  List<DominoMatch> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await MatchRepository.instance.getFinished();
    setState(() {
      _matches = list.reversed.toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المباريات المنتهية')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _matches.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('لا توجد مباريات منتهية بعد')),
                        SizedBox(height: 120),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _matches.length,
                      itemBuilder: (context, i) {
                        final m = _matches[i];
                        final aName = m.mode == MatchMode.oneVOne
                            ? m.players.a1
                            : '${m.players.a1} • ${m.players.a2 ?? ''}'.trim();
                        final bName = m.mode == MatchMode.oneVOne
                            ? m.players.b1
                            : '${m.players.b1} • ${m.players.b2 ?? ''}'.trim();
                        final score = '${m.scoreA} - ${m.scoreB}';
                        final date = m.finishedAt ?? m.startTime;
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
