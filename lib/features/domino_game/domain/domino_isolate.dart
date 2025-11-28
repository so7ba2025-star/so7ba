import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'package:so7ba/features/domino_game/domain/entities/domino_tile.dart';

class DominoIsolate {
  static Future<List<DominoTile>> dealTiles(List<DominoTile> allTiles, int count) async {
    final receivePort = ReceivePort();
    
    await Isolate.spawn(
      _dealer,
      _DealerData(
        sendPort: receivePort.sendPort,
        allTiles: allTiles,
        count: count,
      ),
    );

    return await receivePort.first.then((data) => data as List<DominoTile>);
  }

  static void _dealer(_DealerData data) {
    final tiles = <DominoTile>[];
    final random = DateTime.now().millisecondsSinceEpoch;
    final availableTiles = List<DominoTile>.from(data.allTiles);
    
    for (var i = 0; i < data.count && availableTiles.isNotEmpty; i++) {
      final index = (random * (i + 1)) % availableTiles.length;
      tiles.add(availableTiles.removeAt(index));
    }
    
    Isolate.exit(data.sendPort, tiles);
  }
}

class _DealerData {
  final SendPort sendPort;
  final List<DominoTile> allTiles;
  final int count;

  _DealerData({
    required this.sendPort,
    required this.allTiles,
    required this.count,
  });
}
