import 'domino_tile.dart';

class Player {
  final String id;
  final String name;
  final List<DominoTile> hand;

  const Player({
    required this.id,
    required this.name,
    required this.hand,
  });
}
