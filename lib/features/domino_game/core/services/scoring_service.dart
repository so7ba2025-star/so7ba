import '../../domain/entities/domino_tile.dart';

class ScoringService {
  int calculateTilePoints(DominoTile tile) {
    return tile.left + tile.right;
  }

  int calculateHandScore(List<DominoTile> hand) {
    var total = 0;
    for (final tile in hand) {
      total += calculateTilePoints(tile);
    }
    return total;
  }
}
