import '../../domain/entities/game_round.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/domino_tile.dart';

class GameRoundModel {
  final int roundNumber;
  final List<Player> players;
  final List<DominoTile> playedTiles;
  final String currentTurnPlayerId;

  const GameRoundModel({
    required this.roundNumber,
    required this.players,
    required this.playedTiles,
    required this.currentTurnPlayerId,
  });

  factory GameRoundModel.fromJson(Map<String, dynamic> json) {
    return GameRoundModel(
      roundNumber: json['roundNumber'] as int,
      players: (json['players'] as List<dynamic>)
          .map((e) {
            final map = e as Map<String, dynamic>;
            return Player(
              id: map['id'] as String,
              name: map['name'] as String,
              hand: (map['hand'] as List<dynamic>)
                  .map((tile) {
                    final tileMap = tile as Map<String, dynamic>;
                    return DominoTile(
                      left: tileMap['left'] as int,
                      right: tileMap['right'] as int,
                    );
                  })
                  .toList(),
            );
          })
          .toList(),
      playedTiles: (json['playedTiles'] as List<dynamic>)
          .map((e) {
            final map = e as Map<String, dynamic>;
            return DominoTile(
              left: map['left'] as int,
              right: map['right'] as int,
            );
          })
          .toList(),
      currentTurnPlayerId: json['currentTurnPlayerId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roundNumber': roundNumber,
      'players': players
          .map((player) => {
                'id': player.id,
                'name': player.name,
                'hand': player.hand
                    .map((tile) => {
                          'left': tile.left,
                          'right': tile.right,
                        })
                    .toList(),
              })
          .toList(),
      'playedTiles': playedTiles
          .map((tile) => {
                'left': tile.left,
                'right': tile.right,
              })
          .toList(),
      'currentTurnPlayerId': currentTurnPlayerId,
    };
  }
}
