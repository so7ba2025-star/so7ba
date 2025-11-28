import 'player.dart';
import 'game_round.dart';

class GameState {
  final String roomId;
  final List<Player> players;
  final List<GameRound> rounds;
  final bool isFinished;

  const GameState({
    required this.roomId,
    required this.players,
    required this.rounds,
    required this.isFinished,
  });

  GameState copyWith({
    String? roomId,
    List<Player>? players,
    List<GameRound>? rounds,
    bool? isFinished,
  }) {
    return GameState(
      roomId: roomId ?? this.roomId,
      players: players ?? this.players,
      rounds: rounds ?? this.rounds,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}
