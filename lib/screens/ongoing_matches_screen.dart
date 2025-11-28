import 'package:flutter/material.dart';
import '../data/match_repository.dart';
import 'package:so7ba/models/match_models.dart';
import 'scoring_screen.dart';

class OngoingMatchesScreen extends StatelessWidget {
  const OngoingMatchesScreen({super.key});

  String _teamNameA(DominoMatch m) {
    if (m.mode == MatchMode.oneVOne) return m.players.a1;
    return '${m.players.a1} • ${m.players.a2 ?? ''}'.trim();
  }

  String _teamNameB(DominoMatch m) {
    if (m.mode == MatchMode.oneVOne) return m.players.b1;
    return '${m.players.b1} • ${m.players.b2 ?? ''}'.trim();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 99) {
      return '${hours}ساعة';
    } else if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '${minutes}د';
    } else {
      return '<1د';
    }
  }

  Future<void> _endMatch(BuildContext context, DominoMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إنهاء المباراة'),
          content: Text('هل أنت متأكد من أنك تريد إنهاء مباراة ${_teamNameA(match)} ضد ${_teamNameB(match)}؟'),
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
      final updatedMatch = match.copyWith(finishedAt: DateTime.now());
      await MatchRepository.instance.finishMatch(updatedMatch);
      // Refresh the screen
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OngoingMatchesScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('المباريات الجارية'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<DominoMatch>>(
        future: MatchRepository.instance.getOngoing(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('خطأ في تحميل المباريات: ${snap.error}'));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_baseball, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد مباريات جارية حالياً',
                    style: const TextStyle(fontSize: 18, color: Color(0xFF757575)),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final match = items[i];
              final elapsed = DateTime.now().difference(match.startTime);
              final isNearWin = (match.scoreA >= 140 && match.scoreA < 151) || (match.scoreB >= 140 && match.scoreB < 151);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 2,
                  shadowColor: Colors.black.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ScoringScreen(match: match)),
                      );
                    },
                    onLongPress: () => _endMatch(context, match),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 160),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with match number and mode
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isNearWin ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isNearWin ? Colors.orange : Colors.green,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  match.mode == MatchMode.oneVOne ? '1 ضد 1' : '2 ضد 2',
                                  style: TextStyle(
                                    color: isNearWin ? Colors.orange : Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Team names
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _teamNameA(match),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'فريق أ',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'ضد',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF757575),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _teamNameB(match),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'فريق ب',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF616161),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Scores
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '${match.scoreA}',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1a1a1a),
                                      ),
                                    ),
                                    Text(
                                      'نقاط',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF757575),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${match.scoreB}',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1a1a1a),
                                      ),
                                    ),
                                    Text(
                                      'نقاط',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF757575),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Time and action hint
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'الوقت المنقضي: ${_formatDuration(elapsed)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF757575),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'اضغط مطولاً للإنهاء',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9E9E9E),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

extension DominoMatchExtension on DominoMatch {
  DominoMatch copyWith({DateTime? finishedAt}) {
    return DominoMatch(
      id: id,
      mode: mode,
      players: players,
      startTime: startTime,
      rounds: rounds,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}
