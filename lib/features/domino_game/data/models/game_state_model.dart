import '../../domain/entities/game_state.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/game_round.dart';
import '../../domain/entities/domino_tile.dart';

class GameStateModel {
  final String roomId;
  final List<Player> players;
  final List<GameRound> rounds;
  final bool isFinished;

  const GameStateModel({
    required this.roomId,
    required this.players,
    required this.rounds,
    required this.isFinished,
  });

  factory GameStateModel.fromJson(Map<String, dynamic> json) {
    return GameStateModel(
      roomId: json['roomId'] as String,
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
      rounds: (json['rounds'] as List<dynamic>)
          .map((e) {
            final map = e as Map<String, dynamic>;
            return GameRound(
              roundNumber: map['roundNumber'] as int,
              players: (map['players'] as List<dynamic>)
                  .map((p) {
                    final playerMap = p as Map<String, dynamic>;
                    return Player(
                      id: playerMap['id'] as String,
                      name: playerMap['name'] as String,
                      hand: (playerMap['hand'] as List<dynamic>)
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
              playedTiles: (map['playedTiles'] as List<dynamic>)
                  .map((tile) {
                    final tileMap = tile as Map<String, dynamic>;
                    return DominoTile(
                      left: tileMap['left'] as int,
                      right: tileMap['right'] as int,
                    );
                  })
                  .toList(),
              currentTurnPlayerId: map['currentTurnPlayerId'] as String,
            );
          })
          .toList(),
      isFinished: json['isFinished'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
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
      'rounds': rounds
          .map((round) => {
                'roundNumber': round.roundNumber,
                'players': round.players
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
                'playedTiles': round.playedTiles
                    .map((tile) => {
                          'left': tile.left,
                          'right': tile.right,
                        })
                    .toList(),
                'currentTurnPlayerId': round.currentTurnPlayerId,
              })
          .toList(),
      'isFinished': isFinished,
    };
  }
}
