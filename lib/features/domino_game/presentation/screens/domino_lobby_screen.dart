import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/match_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/room_provider.dart';
import '../widgets/domino_players_list_widget.dart';
import '../widgets/turn_order_preview_widget.dart';
import 'game_screen.dart';

class DominoLobbyScreen extends ConsumerStatefulWidget {
  const DominoLobbyScreen({super.key});

  @override
  ConsumerState<DominoLobbyScreen> createState() => _DominoLobbyScreenState();
}

class _DominoLobbyScreenState extends ConsumerState<DominoLobbyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<Color> _gradientColors = const [
    Color(0xFFFF6B6B),
    Color(0xFF8A0303),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only watch what's needed for this screen
    final isRunning = ref.watch(matchProvider.select((state) => state.isRunning));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
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
            // دوائر الخلفية المتحركة كما في login_screen
            ...List.generate(
              9,
              (index) => Positioned(
                top: Random().nextDouble() * MediaQuery.of(context).size.height,
                right:
                    Random().nextDouble() * MediaQuery.of(context).size.width,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animationController.value * 2 * pi,
                      child: Opacity(
                        opacity: 0.3,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _gradientColors,
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
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text('لوبي الدومينو'),
                centerTitle: true,
                backgroundColor: Colors.black.withOpacity(0.3),
                elevation: 0,
              ),
              body: Consumer(
                builder: (context, ref, child) {
                  final roomAsync = ref.watch(currentRoomProvider);
                  
                  return roomAsync.when(
                    data: (room) {
                      // في حالة عدم وجود غرفة حالية بعد الاتصال
                      if (room == null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'لا توجد غرفة نشطة لهذه اللعبة حالياً.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('الرجوع'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final players = room.members
                          .where((m) => !m.isSpectator)
                          .toList(growable: false);

                      final readyPlayers = players
                          .where((m) => m.isReady)
                          .toList(growable: false);

                      final canStartRound = players.length == 4 &&
                          readyPlayers.length == players.length;

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: DominoPlayersListWidget(
                              players: players,
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TurnOrderPreviewWidget(
                              players: players,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: canStartRound && !isRunning
                                ? () async {
                                    final roomId = room.id;
                                    await ref
                                        .read(matchProvider.notifier)
                                        .startMatch(roomId);
                                    await ref
                                        .read(gameProvider.notifier)
                                        .loadGameState(roomId);

                                    final gameState =
                                        ref.read(gameProvider);
                                    if (gameState != null) {
                                      ref
                                          .read(matchProvider.notifier)
                                          .setInitialGameState(gameState);
                                    }

                                    if (!mounted) return;
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            GameScreen(matchId: roomId),
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('بدء الجولة'),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stack) => Center(
                      child: Text('خطأ: $error'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
