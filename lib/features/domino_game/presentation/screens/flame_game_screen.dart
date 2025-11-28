import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame/components.dart';
import 'package:flame/camera.dart';
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
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
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
      backgroundColor: Colors.red.shade800, // نفس لون خلفية Flame
      body: GameWidget(
        game: DominoFlameGame(
          boardTiles: widget.boardTiles,
          playerTiles: widget.playerTiles,
          aiTiles: widget.aiTiles,
          onTilePlayed: widget.onTilePlayed,
          isPlayerTurn: widget.isPlayerTurn,
          onSoundPlayed: _playSound,
          playerScore: widget.playerScore,
          aiScore: widget.aiScore,
          onBack: widget.onBack,
          onDrawFromBoneyard: widget.onDrawFromBoneyard,
          onPassTurn: widget.onPassTurn,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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
  final int playerScore;
  final int aiScore;
  final VoidCallback? onBack;
  final Function()? onDrawFromBoneyard;
  final Function()? onPassTurn;

  DominoFlameGame({
    required this.boardTiles,
    required this.playerTiles,
    required this.aiTiles,
    this.onTilePlayed,
    required this.isPlayerTurn,
    this.onSoundPlayed,
    required this.playerScore,
    required this.aiScore,
    this.onBack,
    this.onDrawFromBoneyard,
    this.onPassTurn,
  });

  @override
  Vector2 get size => Vector2(1200, 800); // حجم اللعبة الكبير

  @override
  bool get debugMode => false; // إخفاء علامة +

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

    // إضافة الكاميرا الثابتة التي تظهر العالم بالكامل
    final cameraComponent = CameraComponent(
      world: gameWorld,
    );
    // ضبط الكاميرا لتظهر العالم بالكامل
    cameraComponent.viewfinder.position = Vector2(600, 400); // وسط العالم
    cameraComponent.viewfinder.zoom = 1.0; // تكبير طبيعي
    await add(cameraComponent);

    // إضافة HUD للواجهة فوق كل شيء
    final hud = HudComponent(
      aiTiles: aiTiles,
      aiScore: aiScore,
      playerTiles: playerTiles,
      playerScore: playerScore,
      isPlayerTurn: isPlayerTurn,
      onBack: onBack,
      onDrawFromBoneyard: onDrawFromBoneyard,
      onPassTurn: onPassTurn,
    );
    await add(hud);
  }
}

/// مكون HUD للواجهة فوق اللعبة
class HudComponent extends PositionComponent {
  final List<DominoTile> aiTiles;
  final int aiScore;
  final List<DominoTile> playerTiles;
  final int playerScore;
  final bool isPlayerTurn;
  final VoidCallback? onBack;
  final Function()? onDrawFromBoneyard;
  final Function()? onPassTurn;

  HudComponent({
    required this.aiTiles,
    required this.aiScore,
    required this.playerTiles,
    required this.playerScore,
    required this.isPlayerTurn,
    this.onBack,
    this.onDrawFromBoneyard,
    this.onPassTurn,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // منطقة AI في الأعلى - بدون خلفية خضراء
    final aiIcon = CircleComponent(
      radius: 45, // أيقونة أكبر جداً
      position: Vector2(80, 70),
      paint: Paint()
        ..color = Colors.green.shade700
        ..style = PaintingStyle.fill,
    );
    await add(aiIcon);

    final aiText = TextComponent(
      text: 'AI',
      position: Vector2(80, 70),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28, // حجم أكبر جداً
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(aiText);

    final aiScoreText = TextComponent(
      text: '0/$aiScore',
      position: Vector2(140, 70),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32, // حجم أكبر جداً
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(aiScoreText);

    // رسمة بلاطة واحدة عليها العدد
    if (aiTiles.isNotEmpty) {
      // خلفية البلاطة بلون AI مميز
      final tileBackground = RectangleComponent(
        position: Vector2(280, 45),
        size: Vector2(80, 50),
        paint: Paint()
          ..color = Colors.deepPurple.shade600 // لون بنفسجي غامق لـ AI
          ..style = PaintingStyle.fill,
      );
      await add(tileBackground);

      // إطار البلاطة ذهبي
      final tileBorder = RectangleComponent(
        position: Vector2(280, 45),
        size: Vector2(80, 50),
        paint: Paint()
          ..color = Colors.amber.shade700 // إطار ذهبي
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
      await add(tileBorder);

      // خط الفصل في البلاطة ذهبي
      final tileDivider = RectangleComponent(
        position: Vector2(319, 45),
        size: Vector2(2, 50),
        paint: Paint()
          ..color = Colors.amber.shade700 // خط فصل ذهبي
          ..style = PaintingStyle.fill,
      );
      await add(tileDivider);

      // شعار AI في النصف الأيسر
      final aiLogo = TextComponent(
        text: 'AI',
        position: Vector2(300, 70),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      await add(aiLogo);

      // عرض عدد البلاطات في النصف الأيمن
      final tilesCountText = TextComponent(
        text: '${aiTiles.length}',
        position: Vector2(340, 70),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      await add(tilesCountText);
    }

    // منطقة Player في الحد السفلي النهائي للشاشة - أكبر بكثير
    final playerBackground = RectangleComponent(
      position: Vector2(30, 580), // موضع في الحد السفلي النهائي
      size: Vector2(500, 120), // حجم أكبر جداً
      paint: Paint()
        ..color = Colors.blue.withOpacity(0.8) // أكثر وضوحاً
        ..style = PaintingStyle.fill,
    );
    await add(playerBackground);

    final playerIcon = CircleComponent(
      radius: 45, // أيقونة أكبر جداً
      position: Vector2(80, 640), // موضع في الحد السفلي النهائي
      paint: Paint()
        ..color = Colors.blue.shade700
        ..style = PaintingStyle.fill,
    );
    await add(playerIcon);

    final playerText = TextComponent(
      text: 'Player',
      position: Vector2(80, 640), // موضع في الحد السفلي النهائي
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24, // حجم أكبر جداً
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(playerText);

    final playerScoreText = TextComponent(
      text: '0/$playerScore',
      position: Vector2(140, 640), // موضع في الحد السفلي النهائي
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32, // حجم أكبر جداً
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(playerScoreText);

    final playerTilesText = TextComponent(
      text: 'Tiles: ${playerTiles.length}',
      position: Vector2(320, 640), // موضع في الحد السفلي النهائي
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24, // حجم أكبر جداً
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(playerTilesText);

    // أزرار التحكم
    if (isPlayerTurn) {
      // زر السحب
      if (onDrawFromBoneyard != null) {
        final drawButton = RectangleComponent(
          position: Vector2(540, 630), // موضع جديد في الحد السفلي النهائي
          size: Vector2(80, 40),
          paint: Paint()
            ..color = Colors.orange
            ..style = PaintingStyle.fill,
        );
        await add(drawButton);

        final drawText = TextComponent(
          text: 'سحب',
          position: Vector2(560, 645), // موضع جديد في الحد السفلي النهائي
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        await add(drawText);
      }

      // زر المرور
      if (onPassTurn != null) {
        final passButton = RectangleComponent(
          position: Vector2(630, 630), // موضع جديد في الحد السفلي النهائي
          size: Vector2(80, 40),
          paint: Paint()
            ..color = Colors.red
            ..style = PaintingStyle.fill,
        );
        await add(passButton);

        final passText = TextComponent(
          text: 'مرر',
          position: Vector2(650, 645), // موضع جديد في الحد السفلي النهائي
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        await add(passText);
      }

      // زر العودة
      if (onBack != null) {
        final backButton = RectangleComponent(
          position: Vector2(720, 630), // موضع جديد في الحد السفلي النهائي
          size: Vector2(80, 40),
          paint: Paint()
            ..color = Colors.grey
            ..style = PaintingStyle.fill,
        );
        await add(backButton);

        final backText = TextComponent(
          text: 'رجوع',
          position: Vector2(740, 645), // موضع جديد في الحد السفلي النهائي
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        await add(backText);
      }
    }
  }
}

/// منطقة الذكاء الاصطناعي
class AiAreaComponent extends PositionComponent {
  final List<DominoTile> aiTiles;
  final int aiScore;
  final bool isPlayerTurn;

  AiAreaComponent({
    required this.aiTiles,
    required this.aiScore,
    required this.isPlayerTurn,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // خلفية منطقة AI في الأعلى - أكبر وأوضح
    final background = RectangleComponent(
      position: Vector2(50, 20),
      size: Vector2(400, 100), // حجم أكبر
      paint: Paint()
        ..color = isPlayerTurn
            ? Colors.black.withOpacity(0.7)
            : Colors.green.withOpacity(0.5)
        ..style = PaintingStyle.fill,
    );
    await add(background);

    // إطار منطقة AI
    final border = RectangleComponent(
      position: Vector2(50, 20),
      size: Vector2(400, 100),
      paint: Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..strokeWidth = 3 // إطار أسمك
        ..style = PaintingStyle.stroke,
    );
    await add(border);

    // أيقونة AI أكبر
    final aiIcon = CircleComponent(
      radius: 35, // أيقونة أكبر
      position: Vector2(90, 70),
      paint: Paint()
        ..color = Colors.green.shade600
        ..style = PaintingStyle.fill,
    );
    await add(aiIcon);

    // نص AI أكبر
    final aiText = TextComponent(
      text: 'AI',
      position: Vector2(90, 70),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20, // حجم أكبر
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(aiText);

    // عرض النتيجة بجانب الأيقونة
    final scoreText = TextComponent(
      text: '0/$aiScore',
      position: Vector2(140, 70),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22, // حجم أكبر
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(scoreText);

    // عرض عدد البلاطات فقط
    final tilesText = TextComponent(
      text: 'Tiles: ${aiTiles.length}',
      position: Vector2(280, 70),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18, // حجم أكبر
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(tilesText);
  }
}

/// منطقة اللاعب
class PlayerAreaComponent extends PositionComponent {
  final List<DominoTile> playerTiles;
  final int playerScore;
  final bool isPlayerTurn;
  final VoidCallback? onBack;
  final Function()? onDrawFromBoneyard;
  final Function()? onPassTurn;

  PlayerAreaComponent({
    required this.playerTiles,
    required this.playerScore,
    required this.isPlayerTurn,
    this.onBack,
    this.onDrawFromBoneyard,
    this.onPassTurn,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // خلفية منطقة اللاعب في الأسفل
    final background = RectangleComponent(
      position: Vector2(50, 500),
      size: Vector2(300, 80),
      paint: Paint()
        ..color = isPlayerTurn
            ? Colors.blue.withOpacity(0.3)
            : Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.fill,
    );
    await add(background);

    // إطار منطقة اللاعب
    final border = RectangleComponent(
      position: Vector2(50, 500),
      size: Vector2(300, 80),
      paint: Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    await add(border);

    // أيقونة اللاعب
    final playerIcon = CircleComponent(
      radius: 25,
      position: Vector2(80, 540),
      paint: Paint()
        ..color = Colors.blue.shade600
        ..style = PaintingStyle.fill,
    );
    await add(playerIcon);

    // نص Player
    final playerText = TextComponent(
      text: 'Player',
      position: Vector2(80, 540),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(playerText);

    // عرض النتيجة بجانب الأيقونة
    final scoreText = TextComponent(
      text: '0/$playerScore',
      position: Vector2(120, 540),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(scoreText);

    // عرض عدد البلاطات فقط
    final tilesText = TextComponent(
      text: 'Tiles: ${playerTiles.length}',
      position: Vector2(220, 540),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(tilesText);

    // أزرار التحكم
    if (isPlayerTurn) {
      // زر السحب
      if (onDrawFromBoneyard != null) {
        final drawButton = RectangleComponent(
          position: Vector2(400, 530),
          size: Vector2(60, 30),
          paint: Paint()
            ..color = Colors.orange
            ..style = PaintingStyle.fill,
        );
        await add(drawButton);

        final drawText = TextComponent(
          text: 'سحب',
          position: Vector2(415, 540),
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        await add(drawText);
      }

      // زر المرور
      if (onPassTurn != null) {
        final passButton = RectangleComponent(
          position: Vector2(470, 530),
          size: Vector2(60, 30),
          paint: Paint()
            ..color = Colors.red
            ..style = PaintingStyle.fill,
        );
        await add(passButton);

        final passText = TextComponent(
          text: 'مرر',
          position: Vector2(485, 540),
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        await add(passText);
      }

      // زر العودة
      if (onBack != null) {
        final backButton = RectangleComponent(
          position: Vector2(530, 530),
          size: Vector2(60, 30),
          paint: Paint()
            ..color = Colors.grey
            ..style = PaintingStyle.fill,
        );
        await add(backButton);

        final backText = TextComponent(
          text: 'رجوع',
          position: Vector2(545, 540),
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        await add(backText);
      }
    }
  }
}
