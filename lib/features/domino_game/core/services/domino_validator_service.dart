import 'package:flutter/foundation.dart';
import '../../domain/entities/domino_tile.dart';

class DominoValidatorService {
  bool canPlayTile(DominoTile tile, List<DominoTile> boardEnds) {
    if (kDebugMode) print('[Domino][Validator] canPlayTile ${tile.left}-${tile.right} | boardEnds=${boardEnds.length}');
    if (boardEnds.isEmpty) {
      if (kDebugMode) print('[Domino][Validator] -> true (empty board)');
      return true;
    }

    final playableEnds = getPlayableEnds(tile, boardEnds);
    final result = playableEnds.isNotEmpty;
    
    if (kDebugMode) {
      final leftEnd = boardEnds.first;
      final rightEnd = boardEnds.last;
      print('[Domino][Validator] -> $result (left=${leftEnd.left}-${leftEnd.right}, right=${rightEnd.left}-${rightEnd.right})');
    }
    return result;
  }

  List<int> getPlayableEnds(DominoTile tile, List<DominoTile> boardEnds) {
    final playableEnds = <int>[];

    if (boardEnds.isEmpty) {
      // Any tile can be played on an empty board
      playableEnds.add(tile.left);
      playableEnds.add(tile.right);
      
      if (kDebugMode) {
        print('[Domino][Validator] getPlayableEnds -> empty board, ends: [${tile.left}, ${tile.right}]');
      }
      return playableEnds;
    }

    final leftEnd = boardEnds.first;
    final rightEnd = boardEnds.last;

    if (kDebugMode) {
      print('[Domino][Validator] getPlayableEnds -> board tiles:');
      for (int i = 0; i < boardEnds.length; i++) {
        print('  tile#$i ${boardEnds[i].left}-${boardEnds[i].right}');
      }
      print('[Domino][Validator] getPlayableEnds -> leftEnd: ${leftEnd.left}-${leftEnd.right}, rightEnd: ${rightEnd.left}-${rightEnd.right}');
    }

    // Calculate actual board ends
    // Left end of board is the LEFT side of the first tile
    final actualLeftEnd = leftEnd.left;
    
    // For the right end, we need to determine which side is actually exposed
    // The right end is the side that's NOT connected to the previous tile
    int actualRightEnd;
    if (boardEnds.length == 1) {
      // Single tile: both ends are exposed
      actualRightEnd = rightEnd.right;
    } else {
      // Multiple tiles: the right end is the side of the last tile that's NOT connected to the previous tile
      final previousTile = boardEnds[boardEnds.length - 2];
      final lastTile = boardEnds.last;
      
      // Check if the last tile's left side connects to the previous tile
      if (lastTile.left == previousTile.left || lastTile.left == previousTile.right) {
        // Left side is connected, so right side is exposed
        actualRightEnd = lastTile.right;
      } else {
        // Right side is connected, so left side is exposed
        actualRightEnd = lastTile.left;
      }
    }

    if (kDebugMode) {
      print('[Domino][Validator] getPlayableEnds -> actual board ends: left=$actualLeftEnd, right=$actualRightEnd');
    }

    // Check if tile can match either end
    if (tile.left == actualLeftEnd || tile.right == actualLeftEnd) {
      playableEnds.add(actualLeftEnd);
    }
    
    if (tile.left == actualRightEnd || tile.right == actualRightEnd) {
      playableEnds.add(actualRightEnd);
    }

    if (kDebugMode) {
      final endsString = playableEnds.join(', ');
      print('[Domino][Validator] getPlayableEnds -> tile ${tile.left}-${tile.right} | ends: [$endsString]');
    }

    return playableEnds;
  }
}
