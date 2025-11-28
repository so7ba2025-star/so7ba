import 'player.dart';
import 'domino_tile.dart';

class GameRound {
  final int roundNumber;
  final List<Player> players;
  final List<DominoTile> playedTiles;
  final String currentTurnPlayerId;

  const GameRound({
    required this.roundNumber,
    required this.players,
    required this.playedTiles,
    required this.currentTurnPlayerId,
  });

  // Expose the board tiles as expected by the UI (alias of playedTiles)
  List<DominoTile> get boardTiles => playedTiles;

  // Compute the current player based on currentTurnPlayerId
  Player get currentPlayer => players.firstWhere(
        (p) => p.id == currentTurnPlayerId,
        orElse: () => players.first,
      );

  GameRound copyWith({
    int? roundNumber,
    List<Player>? players,
    List<DominoTile>? playedTiles,
    String? currentTurnPlayerId,
  }) {
    return GameRound(
      roundNumber: roundNumber ?? this.roundNumber,
      players: players ?? this.players,
      playedTiles: playedTiles ?? this.playedTiles,
      currentTurnPlayerId: currentTurnPlayerId ?? this.currentTurnPlayerId,
    );
  }
}
