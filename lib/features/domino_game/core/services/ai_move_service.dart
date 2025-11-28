import '../../domain/entities/domino_tile.dart';
import '../../domain/entities/player.dart';

class AiMoveService {
  DominoTile selectTile(Player aiPlayer, List<DominoTile> boardEnds) {
    if (boardEnds.isEmpty) {
      return aiPlayer.hand.first;
    }

    final leftEnd = boardEnds.first.left;
    final rightEnd = boardEnds.last.right;

    final playableTiles = aiPlayer.hand.where((tile) {
      return tile.left == leftEnd ||
          tile.right == leftEnd ||
          tile.left == rightEnd ||
          tile.right == rightEnd;
    }).toList();

    if (playableTiles.isEmpty) {
      return aiPlayer.hand.first;
    }

    playableTiles.sort((a, b) {
      final aValue = a.left + a.right;
      final bValue = b.left + b.right;
      return bValue.compareTo(aValue);
    });

    return playableTiles.first;
  }
}
