import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../domain/entities/domino_tile.dart';
import '../../domain/flame/domino_game_world.dart';

/// شاشة اللعبة الجديدة باستخدام Flame مع فيزيقا
class FlameGameScreen extends StatefulWidget {
  final List<DominoTile> boardTiles;
  final List<DominoTile> playerTiles;
  final List<DominoTile> aiTiles;
  final int playerScore;
  final int aiScore;
  final bool isPlayerTurn;
  final Function(DominoTile)? onTilePlayed;
  final Function()? onDrawFromBoneyard;
  final Function()? onPassTurn;
  final VoidCallback? onBack;

  const FlameGameScreen({
    Key? key,
    required this.boardTiles,
    required this.playerTiles,
    required this.aiTiles,
    required this.playerScore,
    required this.aiScore,
    required this.isPlayerTurn,
    this.onTilePlayed,
    this.onDrawFromBoneyard,
    this.onPassTurn,
    this.onBack,
  }) : super(key: key);

  @override
  State<FlameGameScreen> createState() => _FlameGameScreenState();
}

class _FlameGameScreenState extends State<FlameGameScreen> {
  late FlameGame _flameGame;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _enableFullscreenPortrait();
    _initializeGame();
  }

  @override
  void dispose() {
    _restoreSystemUI();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _enableFullscreenPortrait() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _restoreSystemUI() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  void _initializeGame() {
    _flameGame = DominoFlameGame(
      boardTiles: widget.boardTiles,
      playerTiles: widget.playerTiles,
      aiTiles: widget.aiTiles,
      onTilePlayed: widget.onTilePlayed,
      isPlayerTurn: widget.isPlayerTurn,
      onSoundPlayed: _playSound,
    );
  }

  Future<void> _playSound(String soundName) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$soundName'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: SafeArea(
        child: Column(
          children: [
            // منطقة الذكاء الاصطناعي
            _buildAiArea(),

            // منطقة اللعبة الرئيسية
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GameWidget(
                    game: _flameGame,
                    overlayBuilderMap: {
                      'game_ui': (context, game) => _buildGameOverlay(),
                    },
                    initialActiveOverlays: const ['game_ui'],
                  ),
                ),
              ),
            ),

            // منطقة اللاعب
            _buildPlayerArea(),
          ],
        ),
      ),
    );
  }

  /// منطقة الذكاء الاصطناعي
  Widget _buildAiArea() {
    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: !widget.isPlayerTurn
            ? Border.all(color: Colors.green, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // صورة الذكاء الاصطناعي
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: !widget.isPlayerTurn
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(1.0),
        borderRadius: BorderRadius.circular(2),
      ),
      child: showBack
          ? null
          : Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      '${tile.left}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 16,
                  color: Colors.black,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${tile.right}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// واجهة المستخدم فوق اللعبة
  Widget _buildGameOverlay() {
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Column(
        children: [
          // الصف الأول: زر الرجوع ومعلومات اللعبة
          Row(
            children: [
              // زر الرجوع
              if (widget.onBack != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'رجوع',
                    iconSize: 16,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: const EdgeInsets.all(6),
                  ),
                ),

              // مسافة مرنة
              if (widget.onBack != null) const SizedBox(width: 8),

              // معلومات اللعبة
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.isPlayerTurn ? 'دورك' : 'دور الذكاء الاصطناعي',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // عدد البلاطات على اللوحة
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'بلاطات: ${widget.boardTiles.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// لعبة Flame مخصصة للدومينو
class DominoFlameGame extends Forge2DGame {
  final List<DominoTile> boardTiles;
  final List<DominoTile> playerTiles;
  final List<DominoTile> aiTiles;
  final Function(DominoTile)? onTilePlayed;
  final bool isPlayerTurn;
  final Function(String)? onSoundPlayed;

  DominoFlameGame({
    required this.boardTiles,
    required this.playerTiles,
    required this.aiTiles,
    this.onTilePlayed,
    required this.isPlayerTurn,
    this.onSoundPlayed,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // إضافة عالم اللعبة
    final gameWorld = DominoGameWorld(
      tiles: boardTiles,
      onTilePlayed: onTilePlayed,
      isPlayerTurn: isPlayerTurn,
    );

    await add(gameWorld);

    // إضافة الكاميرا
    final cameraComponent = CameraComponent(
      world: gameWorld,
    );
    await add(cameraComponent);
  }
}
