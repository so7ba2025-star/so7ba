import '../../domain/entities/player.dart';
import '../../domain/entities/domino_tile.dart';

class PlayerModel {
  final String id;
  final String name;
  final List<DominoTile> hand;

  const PlayerModel({
    required this.id,
    required this.name,
    required this.hand,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      hand: (json['hand'] as List<dynamic>)
          .map((e) => DominoTile(
                left: (e as Map<String, dynamic>)['left'] as int,
                right: (e as Map<String, dynamic>)['right'] as int,
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hand': hand
          .map((tile) => {
                'left': tile.left,
                'right': tile.right,
              })
          .toList(),
    };
  }
}
