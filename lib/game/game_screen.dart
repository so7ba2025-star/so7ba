import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/domino_tile.dart';
import 'domino_piece.dart';

class DominoCafeGame extends FlameGame {
  late List<DominoTile> playerHand = [];
  late List<DominoTile> aiHand = [];
  final List<DominoTile> board = [];
  int? leftEnd, rightEnd;
  bool isPlayerTurn = true;
  bool _isLoading = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Add red background rectangle
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFFB71C1C),
    ));
    
    if (_isLoading) return;
    _isLoading = true;
    
    print('Game loading started...');
    _startNewRound();
    print('Game loading completed');
  }

  void _startNewRound() async {
    // Skip audio for now to avoid issues
    // try {
    //   await FlameAudio.play('drag.mp3');
    // } catch (e) {
    //   print('Audio error: $e');
    // }

    final allTiles = <DominoTile>[];
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        allTiles.add(DominoTile(left: i, right: j));
      }
    }
    allTiles.shuffle();
    print('Total tiles created: ${allTiles.length}');

    playerHand = allTiles.sublist(0, 7);
    aiHand = allTiles.sublist(7, 14);
    print('Player hand size: ${playerHand.length}');
    print('AI hand size: ${aiHand.length}');

    // إيد اللاعب تحت - simplified
    for (int i = 0; i < playerHand.length; i++) {
      final tile = playerHand[i];
      print('Adding domino piece ${i}: ${tile.left}|${tile.right}');
      
      // Add small delay to reduce graphics buffer pressure
      await Future.delayed(Duration(milliseconds: 50 * i));
      
      add(DominoPiece(
        tile: tile,
        isMine: true,
        originalPosition: Vector2(100 + i * 80, size.y - 100),
        onPlayed: (playedTile, toLeft) {
          _playTile(playedTile, toLeft);
        },
      ));
    }

    // Skip AI domino backs for now
    // for (int i = 0; i < aiHand.length; i++) {
    //   try {
    //     add(SpriteComponent(
    //       sprite: await Sprite.load('Domino_tiels/domino_back.png'),
    //       size: Vector2(66, 132),
    //       position: Vector2(100 + i * 80, 80),
    //       anchor: Anchor.center,
    //     ));
    //   } catch (e) {
    //     print('Error loading domino back: $e');
    //   }
    // }
  }

  void _playTile(DominoTile tile, bool toLeft) {
    if (board.isEmpty) {
      board.add(tile);
      leftEnd = tile.left;
      rightEnd = tile.right;

      final pos = size / 2;
      add(DominoPiece(
        tile: tile,
        originalPosition: pos,
        isMine: false,
      ));
    } else {
      final attachPoint = toLeft
          ? Vector2(size.x * 0.3, size.y / 2)
          : Vector2(size.x * 0.7, size.y / 2);

      final oriented = toLeft
          ? (tile.right == leftEnd ? tile.flip() : tile)
          : (tile.left == rightEnd ? tile.flip() : tile);

      board.add(oriented);
      if (toLeft) leftEnd = oriented.left;
      else rightEnd = oriented.right;

      add(DominoPiece(
        tile: oriented,
        originalPosition: attachPoint,
        isMine: false,
      ));
    }

    playerHand.remove(tile);
    isPlayerTurn = false;

    if (playerHand.isEmpty) {
      FlameAudio.play('win.mp3');
      HapticFeedback.heavyImpact();
      // فوز اللاعب
      Future.delayed(const Duration(seconds: 2), () => _startNewRound());
    }
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  DominoCafeGame? _game;

  @override
  void initState() {
    super.initState();
    // Delay game initialization to prevent game loop errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _game = DominoCafeGame();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB71C1C),
      body: _game != null ? GameWidget(game: _game!) : 
        const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}