import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/navigation_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/domino_tile.dart';
import '../../domain/entities/game_round.dart';
import '../../domain/entities/game_state.dart';
import '../../domain/entities/player.dart';
import '../../providers/match_provider.dart';
import 'game_screen.dart';

class DominoAiOfflineLobbyScreen extends ConsumerWidget {
  const DominoAiOfflineLobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF880404),
                    Color(0xFFC20202),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  ...List.generate(
                    7,
                    (index) => Positioned(
                      top: Random().nextDouble() * constraints.maxHeight,
                      right: Random().nextDouble() * constraints.maxWidth,
                      child: Opacity(
                        opacity: 0.25,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFF6B6B),
                                Color(0xFF8A0303),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  final navigator = rootNavigatorKey.currentState;
                                  if (navigator != null && navigator.mounted) {
                                    navigator.pop();
                                  }
                                },
                                icon: const Icon(Icons.arrow_back_ios_new),
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'دومينو — 1 ضد الذكاء الاصطناعي',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: Card(
                                color: Colors.black.withOpacity(0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 10,
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.smart_toy,
                                        color: Colors.amber,
                                        size: 48,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'وضع اللعب الأوفلاين 1 ضد الذكاء الاصطناعي',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'اللعبة هتتوزّع محلياً على جهازك، وهتلعب ضد خصم يعتمد على قواعد الدومينو واختيارات ذكية لبلاطاته.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                const humanPlayerId = 'human_player';
                                const aiPlayerId = 'ai_bot';

                                final allTiles = <DominoTile>[];
                                for (var left = 0; left <= 6; left++) {
                                  for (var right = left; right <= 6; right++) {
                                    allTiles.add(DominoTile(left: left, right: right));
                                  }
                                }

                                allTiles.shuffle(Random());

                                const humanPlayer = Player(
                                  id: humanPlayerId,
                                  name: 'أنت',
                                  hand: <DominoTile>[],
                                );

                                const aiPlayer = Player(
                                  id: aiPlayerId,
                                  name: 'AI Bot',
                                  hand: <DominoTile>[],
                                );

                                final initialRound = GameRound(
                                  roundNumber: 1,
                                  players: <Player>[humanPlayer, aiPlayer],
                                  playedTiles: const <DominoTile>[],
                                  currentTurnPlayerId: humanPlayerId,
                                );

                                final initialState = GameState(
                                  roomId: 'offline_ai_match',
                                  players: <Player>[humanPlayer, aiPlayer],
                                  rounds: <GameRound>[initialRound],
                                  isFinished: false,
                                );

                                try {
                                  // Show loading indicator
                                  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                                  final overlayEntry = OverlayEntry(
                                    builder: (context) => Center(
                                      child: Material(
                                        color: Colors.black54,
                                        child: Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(),
                                              SizedBox(height: 16),
                                              Text('يتم تحضير اللعبة...'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                  Overlay.of(context).insert(overlayEntry);

                                  // Initialize the game and wait for shuffling
                                  await ref.read(matchProvider.notifier).setupOfflineAiGame(
                                    initialState: initialState,
                                    humanPlayerId: humanPlayerId,
                                    aiPlayerId: aiPlayerId,
                                    boneyard: allTiles,
                                  );

                                  // Remove loading indicator
                                  overlayEntry.remove();

                                  // Navigate to game screen
                                  if (context.mounted) {
                                    final navigator = rootNavigatorKey.currentState;
                                    if (navigator != null && navigator.mounted) {
                                      navigator.pushReplacement(
                                        MaterialPageRoute(
                                          builder: (context) => GameScreen(
                                            matchId: 'offline_ai_match',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    print('Error setting up game: $e');
                                  }
                                  // Remove loading indicator if still present
                                  final navigator = rootNavigatorKey.currentState;
                                  if (navigator != null && navigator.mounted) {
                                    navigator.popUntil((route) => route.isFirst);
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('حدث خطأ أثناء تحضير اللعبة. يرجى المحاولة مرة أخرى.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('بدء اللعب ضد الذكاء الاصطناعي'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
