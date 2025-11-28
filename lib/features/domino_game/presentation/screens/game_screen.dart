import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

// Domain imports
import '../../domain/entities/domino_tile.dart';
import '../../domain/controllers/domino_game_controller.dart';

// Screen imports
import 'flame_game_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, this.matchId});

  final String? matchId;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  // متغيرات اللعبة الأساسية
  List<DominoTile> playerTiles = [];
  List<DominoTile> aiTiles = [];
  List<DominoTile> boardTiles = [];
  List<DominoTile> boneyard = [];
  int playerScore = 0;
  int aiScore = 0;
  bool isPlayerTurn = true;
  bool isAiThinking = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Random _random = Random();

  // متغيرات اللوحة
  int? leftEnd;
  int? rightEnd;
  DominoTile? pendingTile;
  bool gameOver = false;
  int consecutivePasses = 0;

  // متغيرات الأنيميشن للخلفية
  late AnimationController _animationController;
  final List<Color> _gradientColors = [
    const Color(0xFFFF6B6B),
    const Color(0xFF8A0303),
  ];
  String? _playerAvatarUrl;
  final List<Map<String, double>> _circlePositions = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _enableFullscreenPortrait();
    _initializeGame(resetScores: true);
    _generateCirclePositions();
    _loadPlayerAvatar();
  }

  void _generateCirclePositions() {
    for (int i = 0; i < 9; i++) {
      _circlePositions.add({
        'top': _random.nextDouble(),
        'right': _random.nextDouble(),
      });
    }
  }

  Future<void> _loadPlayerAvatar() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await client
          .from('user_profiles')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();

      final url = (response?['avatar_url'] as String?)?.trim();
      if (mounted) {
        setState(() {
          _playerAvatarUrl = (url != null && url.isNotEmpty) ? url : null;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animationController.dispose();
    _restoreSystemUI();
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

  Future<void> _playSound(String soundName) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$soundName'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  String _getTileImagePath(DominoTile tile, {bool isVertical = false}) {
    final suffix = isVertical ? '_v' : '';
    return 'assets/Domino_tiels/domino_${tile.left}_${tile.right}$suffix.png';
  }

  Future<void> _initializeGame(
      {bool resetScores = false, bool? previousRoundWinner}) async {
    await _playSound('shuffle_d_m.mp3');

    // إنشاء كل قطع  الدومينو
    List<DominoTile> allTiles = [];
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        allTiles.add(DominoTile(left: i, right: j));
      }
    }

    // خلط البلاطات
    allTiles.shuffle(_random);

    setState(() {
      // توزيع البلاطات
      playerTiles = allTiles.take(7).toList();
      aiTiles = allTiles.skip(7).take(7).toList();
      boneyard = allTiles.skip(14).toList();
      boardTiles = [];
      leftEnd = null;
      rightEnd = null;
      if (resetScores) {
        playerScore = 0;
        aiScore = 0;
      }
      gameOver = false;
    });

    // تحديد من يبدأ اللعب
    if (previousRoundWinner != null) {
      // الفائز بالجولة السابقة يبدأ الجولة الجديدة
      isPlayerTurn = previousRoundWinner;
      if (isPlayerTurn) {
        await _playSound('Select_1st.mp3');
      }
      setState(() {});

      // لو الكمبيوتر هو اللي هيبدأ الجولة
      if (!isPlayerTurn) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && !gameOver) {
            _aiPlay();
          }
        });
      }
    } else {
      // استخدام المنطق الحالي لتحديد من يبدأ
      await _determineFirstPlayer();
    }
  }

  Future<void> _determineFirstPlayer() async {
    // البحث عن أكبر دوبل
    DominoTile? playerDouble = _getHighestDouble(playerTiles);
    DominoTile? aiDouble = _getHighestDouble(aiTiles);

    if (playerDouble != null && aiDouble != null) {
      if (playerDouble.left > aiDouble.left) {
        isPlayerTurn = true;
      } else if (aiDouble.left > playerDouble.left) {
        isPlayerTurn = false;
      } else {
        // نفس الدوبل، عشوائي
        isPlayerTurn = _random.nextBool();
      }
    } else if (playerDouble != null) {
      isPlayerTurn = true;
    } else if (aiDouble != null) {
      isPlayerTurn = false;
    } else {
      // لا يوجد دوبل، إعادة التوزيع
      _showRedistributionMessage();
      await _initializeGame();
      return;
    }

    await _playSound('Select_1st.mp3');
    setState(() {});

    // لو الكمبيوتر يبدأ
    if (!isPlayerTurn) {
      Future.delayed(const Duration(seconds: 1), () {
        _aiPlay();
      });
    }
  }

  void _showRedistributionMessage() {}

  DominoTile? _getHighestDouble(List<DominoTile> tiles) {
    DominoTile? highest;
    for (var tile in tiles) {
      if (tile.left == tile.right) {
        if (highest == null || tile.left > highest.left) {
          highest = tile;
        }
      }
    }
    return highest;
  }

  DominoTile _flipTile(DominoTile tile) {
    return DominoTile(left: tile.right, right: tile.left);
  }

  @override
  Widget build(BuildContext context) {
    return FlameGameScreen(
      boardTiles: boardTiles,
      playerTiles: playerTiles,
      aiTiles: aiTiles,
      playerScore: playerScore,
      aiScore: aiScore,
      isPlayerTurn: isPlayerTurn,
      onTilePlayed: _playTile,
      onDrawFromBoneyard: _drawFromBoneyard,
      onPassTurn: _passTurn,
      onBack: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildAiArea() {
    return Container(
      height: 90,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: !isPlayerTurn
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(1.0),
                        blurRadius: 25,
                        spreadRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.green.shade600,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$aiScore',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isAiThinking)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green)),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...aiTiles.map((tile) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: _buildTile(
                        tile,
                        showBack: true,
                        isPlayerHand: false,
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (boardTiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    rightEnd?.toString() ?? '0',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    leftEnd?.toString() ?? '0',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          if (isPlayerTurn &&
              pendingTile != null &&
              _canPlayLeft(pendingTile!) &&
              _canPlayRight(pendingTile!))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                textDirection: TextDirection.rtl,
                children: [
                  Column(
                    children: [
                      IconButton(
                        onPressed: _confirmPlayRight,
                        icon: const Icon(Icons.arrow_downward,
                            color: Colors.white),
                        tooltip: 'اللعب على اليمين',
                      ),
                      const Text(
                        'يمين',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  Column(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            pendingTile = null;
                          });
                        },
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const Text(
                        '',
                        style:
                            TextStyle(color: Colors.transparent, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  Column(
                    children: [
                      IconButton(
                        onPressed: _confirmPlayLeft,
                        icon: const Icon(Icons.arrow_downward,
                            color: Colors.white),
                        tooltip: 'اللعب على اليسار',
                      ),
                      const Text(
                        'يسار',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  height: constraints.maxHeight,
                  child: boardTiles.isEmpty
                      ? const Center(
                          child: Text(
                            'ابدأ اللعب بوضع بلاطة من يدك',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Directionality(
                          textDirection: TextDirection.rtl,
                          child: _buildSnakeBoard(),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// بناء لوحة اللعب بأسلوب Snake Layout مع دعم RTL
  Widget _buildSnakeBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final tileWidth = 30.0; // تصغير عرض البلاطة الأفقي
        final doubleTileWidth = 15.0; // تصغير عرض البلاطة العمودي (الدوبل)
        final gap = 1.0; // تصغير المسافة

        List<Widget> rows = [];
        List<DominoTile> currentRowTiles = [];
        double currentRowWidth = 0.0;
        bool isRTL = true; // نبدأ من اليمين لـ RTL

        for (int i = 0; i < boardTiles.length; i++) {
          final tile = boardTiles[i];
          final isDouble = tile.left == tile.right;
          final tileW = isDouble ? doubleTileWidth : tileWidth;

          // التحقق إذا احتجنا لصف جديد مع معامل أمان للـ overflow
          if (currentRowWidth + tileW + gap > availableWidth * 0.95 &&
              currentRowTiles.isNotEmpty) {
            // إضافة الصف الحالي
            rows.add(_buildSnakeRow(currentRowTiles, isRTL));

            // بدء صف جديد مع عكس الاتجاه
            currentRowTiles = [tile];
            currentRowWidth = tileW;
            isRTL = !isRTL;
          } else {
            currentRowTiles.add(tile);
            currentRowWidth += tileW + (currentRowTiles.isNotEmpty ? gap : 0);
          }
        }

        // إضافة الصف الأخير
        if (currentRowTiles.isNotEmpty) {
          rows.add(_buildSnakeRow(currentRowTiles, isRTL));
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }

  /// بناء صف واحد في Snake Layout
  Widget _buildSnakeRow(List<DominoTile> tiles, bool isRTL) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        mainAxisSize: MainAxisSize.min,
        children: tiles.map((tile) {
          final isDouble = tile.left == tile.right;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
            child: _buildTile(
              tile,
              forceVertical: isDouble,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlayerHand() {
    return Container(
      height: 90,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: isPlayerTurn
                  ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(1.0),
                        blurRadius: 25,
                        spreadRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade600,
              backgroundImage: _playerAvatarUrl != null
                  ? NetworkImage(_playerAvatarUrl!)
                  : null,
              child: _playerAvatarUrl == null
                  ? const Icon(Icons.person, color: Colors.white, size: 28)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$playerScore',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: playerTiles.map((tile) {
                  return GestureDetector(
                    onTap: () => _playTile(tile),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _buildTile(
                        tile,
                        isPlayerHand: true,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // زر سحب من المخزن
          if (!gameOver &&
              isPlayerTurn &&
              !_playerHasPlayable() &&
              boneyard.isNotEmpty)
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _drawFromBoneyard,
                    icon: const Icon(Icons.download, color: Colors.orange),
                    tooltip: 'سحب من المخزن',
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _passTurn,
                    icon: const Icon(Icons.skip_next, color: Colors.red),
                    tooltip: 'مرر الدور',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTile(
    DominoTile tile, {
    bool showBack = false,
    bool? forceVertical,
    bool isPlayerHand = false,
  }) {
    if (showBack) {
      // عرض ظهر البلاطة (رأسية لتوفير المساحة) - مقاس أصغر للشاشة الرأسية
      return Container(
        width: isPlayerHand ? 20.0 : 20.0,
        height: isPlayerHand ? 40.0 : 40.0,
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/Domino_tiels/domino_back.png'),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    final isDouble = tile.left == tile.right;
    final displayVertical = forceVertical ?? (isPlayerHand ? true : isDouble);

    // الحصول على مسار الصورة مع القيم كما هي
    final imagePath = _getTileImagePath(tile, isVertical: displayVertical);

    // تحديد الأبعاد - مقاس أصغر للشاشة الرأسية
    final double width = displayVertical
        ? (isPlayerHand ? 20.0 : 32.0)
        : (isPlayerHand ? 40.0 : 60.0);
    final double height = displayVertical
        ? (isPlayerHand ? 40.0 : 60.0)
        : (isPlayerHand ? 20.0 : 32.0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: isPlayerHand ? null : Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover,
        width: width,
        height: height,
      ),
    );
  }

  void _playTile(DominoTile tile) {
    if (!isPlayerTurn) return;

    if (!_canPlayTile(tile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن لعب هذه البلاطة هنا')),
      );
      return;
    }

    if (boardTiles.isEmpty) {
      setState(() {
        playerTiles.remove(tile);
        _addTileToBoard(tile);
        consecutivePasses = 0;
        isPlayerTurn = false;
      });
    } else {
      final canL = _canPlayLeft(tile);
      final canR = _canPlayRight(tile);

      // إذا كانت البلاطة يمكن لعبها على كلا الجانبين، نترك الاختيار للاعب
      if (canL && canR) {
        setState(() {
          pendingTile = tile;
        });
      }
      // إذا كانت البلاطة يمكن لعبها على الجانب الأيسر فقط
      else if (canL) {
        _playTileOnSide(tile, true);
      }
      // إذا كانت البلاطة يمكن لعبها على الجانب الأيمن فقط
      else if (canR) {
        _playTileOnSide(tile, false);
      }
    }

    // التحقق من نهاية اللعبة
    if (playerTiles.isEmpty) {
      _endGame(true);
      return;
    }

    // إذا انتهى دور اللاعب، ننتقل لدور الكمبيوتر
    if (!isPlayerTurn) {
      Future.delayed(const Duration(seconds: 1), () {
        _aiPlay();
      });
    }
  }

  // دالة مساعدة للعب البلاطة على جانب معين
  void _playTileOnSide(DominoTile tile, bool toLeft) {
    setState(() {
      playerTiles.remove(tile);
      _addTileToBoardOnSide(tile, toLeft: toLeft);
      consecutivePasses = 0;
      // لا نقوم بتعيين isPlayerTurn إلى false هنا، سيتم ذلك بعد التأكد من صحة الإضافة
    });

    // ننتقل لدور الكمبيوتر بعد التأكد من صحة الإضافة
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          isPlayerTurn = false;
        });
        _aiPlay();
      }
    });
  }

  // دالة مساعدة للحصول على عدد البلاطات على اليسار
  // تم التبسيط لتعيد 1 دائمًا لأن الطرف الأيسر في سلسلة الدومينو هو نقطة واحدة فقط
  int _getLeftTilesCount() {
    return 1;
  }

  // دالة مساعدة للحصول على عدد البلاطات على اليمين
  // تم التبسيط لتعيد 1 دائمًا لأن الطرف الأيمن في سلسلة الدومينو هو نقطة واحدة فقط
  int _getRightTilesCount() {
    return 1;
  }

  // دالة مساعدة لتحديد الجانب الأفضل للعب
  bool _getBetterSideToPlay(DominoTile tile) {
    // في هذه الحالة، نختار الجانب الذي به أقل عدد من البلاطات
    return _getLeftTilesCount() <= _getRightTilesCount();
  }

  bool _canPlayTile(DominoTile tile) {
    if (boardTiles.isEmpty) return true;

    return tile.left == leftEnd ||
        tile.right == leftEnd ||
        tile.left == rightEnd ||
        tile.right == rightEnd;
  }

  bool _canPlayLeft(DominoTile tile) {
    if (boardTiles.isEmpty) return true;
    return tile.left == leftEnd || tile.right == leftEnd;
  }

  bool _canPlayRight(DominoTile tile) {
    if (boardTiles.isEmpty) return true;
    return tile.left == rightEnd || tile.right == rightEnd;
  }

  // التحقق مما إذا كانت اللعبة مقفولة رياضيًا في الحالة الخاصة:
  // الطرفان نفس الرقم، وكل ٧ بلاطات الخاصة بهذا الرقم على الطاولة
  bool _isMathematicallyBlocked() {
    if (leftEnd == null || rightEnd == null) return false;
    if (leftEnd != rightEnd) return false;

    final int n = leftEnd!;
    int countOnBoard = 0;
    for (final tile in boardTiles) {
      if (tile.left == n || tile.right == n) {
        countOnBoard++;
      }
    }

    // في دومينو 6x6، هناك ٧ بلاطات فقط لكل رقم
    return countOnBoard >= 7;
  }

  bool _playerHasPlayable() {
    for (final t in playerTiles) {
      if (_canPlayTile(t)) return true;
    }
    return false;
  }

  void _addTileToBoard(DominoTile tile) {
    debugPrint(
        '\n🎲🎲🎲 [_addTileToBoard] - بدء إضافة بلاطة: ${tile.left}-${tile.right} 🎲🎲🎲');
    debugPrint('📊 الحالة الحالية - الأطراف: يسار=$leftEnd، يمين=$rightEnd');
    debugPrint('📋 البلاطة: ${tile.left}-${tile.right}');

    if (boardTiles.isEmpty) {
      boardTiles.add(tile);
      leftEnd = tile.left;
      rightEnd = tile.right;
      debugPrint('✅ الحالة 0: إضافة أول بلاطة [${tile.left}|${tile.right}]');
    } else if (tile.left == leftEnd || tile.right == leftEnd) {
      final orientedTile = tile.right == leftEnd ? tile : _flipTile(tile);
      boardTiles.insert(0, orientedTile);
      leftEnd = orientedTile.left;
      debugPrint(
          '✅ إضافة البلاطة إلى اليسار: [${orientedTile.left}|${orientedTile.right}]');
    } else if (tile.left == rightEnd || tile.right == rightEnd) {
      final orientedTile = tile.left == rightEnd ? tile : _flipTile(tile);
      boardTiles.add(orientedTile);
      rightEnd = orientedTile.right;
      debugPrint(
          '✅ إضافة البلاطة إلى اليمين: [${orientedTile.left}|${orientedTile.right}]');
    } else {
      debugPrint(
          '❌ خطأ: البلاطة ${tile.left}-${tile.right} لا يمكن لعبها على أي جانب');
      return;
    }

    debugPrint('🔄 الأطراف الجديدة: يسار=$leftEnd، يمين=$rightEnd');
    debugPrint(
        '📋 البلاطات الحالية: ${boardTiles.map((t) => '${t.left}-${t.right}').toList()}');
    debugPrint('----------------------------------------');
  }

  void _addTileToBoardOnSide(DominoTile tile, {required bool toLeft}) {
    if (boardTiles.isEmpty) {
      debugPrint(
          '🎲 إضافة أول بلاطة (اختيار جانب محدد): ${tile.left}-${tile.right}');
      _addTileToBoard(tile);
      return;
    }

    debugPrint(
        '\n🎴 محاولة إضافة بلاطة: ${tile.left}-${tile.right} إلى ${toLeft ? 'اليسار' : 'اليمين'}');
    debugPrint('📊 الأطراف الحالية: يسار=$leftEnd، يمين=$rightEnd');

    if (toLeft) {
      if (tile.left == leftEnd || tile.right == leftEnd) {
        final orientedTile = tile.right == leftEnd ? tile : _flipTile(tile);
        boardTiles.insert(0, orientedTile);
        leftEnd = orientedTile.left;
        debugPrint(
            '✅ تمت الإضافة إلى اليسار: [${orientedTile.left}|${orientedTile.right}]');
      } else {
        debugPrint(
            '❌ خطأ: البلاطة ${tile.left}-${tile.right} لا يمكن لعبها على اليسار');
      }
    } else {
      if (tile.left == rightEnd || tile.right == rightEnd) {
        final orientedTile = tile.left == rightEnd ? tile : _flipTile(tile);
        boardTiles.add(orientedTile);
        rightEnd = orientedTile.right;
        debugPrint(
            '✅ تمت الإضافة إلى اليمين: [${orientedTile.left}|${orientedTile.right}]');
      } else {
        debugPrint(
            '❌ خطأ: البلاطة ${tile.left}-${tile.right} لا يمكن لعبها على اليمين');
      }
    }

    debugPrint('🔄 الأطراف الجديدة: يسار=$leftEnd، يمين=$rightEnd');
    debugPrint('----------------------------------------');
  }

  void _confirmPlayLeft() {
    final t = pendingTile;
    if (t == null) return;
    setState(() {
      playerTiles.remove(t);
      _addTileToBoardOnSide(t, toLeft: true);
      pendingTile = null;
      consecutivePasses = 0;
      isPlayerTurn = false;
    });
    if (playerTiles.isEmpty) {
      _endGame(true);
      return;
    }
    Future.delayed(const Duration(seconds: 1), () {
      _aiPlay();
    });
  }

  void _confirmPlayRight() {
    final t = pendingTile;
    if (t == null) return;
    setState(() {
      playerTiles.remove(t);
      _addTileToBoardOnSide(t, toLeft: false);
      pendingTile = null;
      consecutivePasses = 0;
      isPlayerTurn = false;
    });
    if (playerTiles.isEmpty) {
      _endGame(true);
      return;
    }
    Future.delayed(const Duration(seconds: 1), () {
      _aiPlay();
    });
  }

  Future<void> _aiPlay() async {
    if (gameOver) return;
    if (aiTiles.isEmpty) return;

    setState(() {
      isAiThinking = true;
    });

    // انتظر تفكير الكمبيوتر
    await Future.delayed(const Duration(milliseconds: 800));
    if (gameOver) {
      setState(() {
        isAiThinking = false;
      });
      return;
    }

    // البحث عن بلاطة قابلة للعب
    DominoTile? playableTile = _findPlayableTile(aiTiles);

    if (playableTile != null) {
      setState(() {
        aiTiles.remove(playableTile);
        _addTileToBoard(playableTile);
        isPlayerTurn = true;
        isAiThinking = false;
        consecutivePasses = 0;
      });

      if (aiTiles.isEmpty) {
        _endGame(false);
      }
    } else {
      // محاولة السحب من المخزن
      if (!gameOver) {
        await _aiDrawFromBoneyard();
      }
    }
  }

  DominoTile? _findPlayableTile(List<DominoTile> tiles) {
    for (var tile in tiles) {
      if (_canPlayTile(tile)) {
        return tile;
      }
    }
    return null;
  }

  Future<void> _aiDrawFromBoneyard() async {
    // في حالة الإغلاق الرياضي للعبة، لا نحاول السحب من المخزن
    if (_isMathematicallyBlocked()) {
      final playerRemaining = _calculatePoints(playerTiles);
      final aiRemaining = _calculatePoints(aiTiles);

      if (playerRemaining == aiRemaining) {
        // تعادل: نبدأ جولة جديدة بدون نقاط مضافة
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('الجولة محجوبة'),
            content: const Text('تعادل في النقاط. بدء جولة جديدة.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _initializeGame();
                },
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
        return;
      }

      final playerWins = playerRemaining < aiRemaining;
      _endGame(playerWins);
      return;
    }

    while (boneyard.isNotEmpty) {
      final tile = boneyard.removeAt(_random.nextInt(boneyard.length));
      aiTiles.add(tile);

      if (_canPlayTile(tile)) {
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          aiTiles.remove(tile);
          _addTileToBoard(tile);
          isPlayerTurn = true;
          isAiThinking = false;
        });
        return;
      }
    }

    // لا يمكن اللعب، Pass
    setState(() {
      isPlayerTurn = true;
      isAiThinking = false;
    });
  }

  Future<void> _drawFromBoneyard() async {
    // في حالة الإغلاق الرياضي للعبة، لا نحاول السحب من المخزن
    if (_isMathematicallyBlocked()) {
      final playerRemaining = _calculatePoints(playerTiles);
      final aiRemaining = _calculatePoints(aiTiles);

      if (playerRemaining == aiRemaining) {
        // تعادل: نبدأ جولة جديدة بدون نقاط مضافة
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('الجولة محجوبة'),
            content: const Text('تعادل في النقاط. بدء جولة جديدة.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _initializeGame();
                },
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
        return;
      }

      final playerWins = playerRemaining < aiRemaining;
      _endGame(playerWins);
      return;
    }

    if (boneyard.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المخزن فارغ! Pass')),
      );
      _passTurn();
      return;
    }

    setState(() {
      isAiThinking = true;
    });

    while (boneyard.isNotEmpty) {
      final tile = boneyard.removeAt(_random.nextInt(boneyard.length));
      playerTiles.add(tile);

      if (_canPlayTile(tile)) {
        setState(() {
          isAiThinking = false;
        });
        return;
      }
    }

    setState(() {
      isAiThinking = false;
    });
    _passTurn();
  }

  void _passTurn() {
    setState(() {
      isPlayerTurn = false;
      consecutivePasses += 1;
    });
    if (consecutivePasses >= 2 && !gameOver) {
      // الجولة محجوبة: الأقل نقاطًا يفوز ويأخذ نقاط خصمه
      final playerRemaining = _calculatePoints(playerTiles);
      final aiRemaining = _calculatePoints(aiTiles);
      if (playerRemaining == aiRemaining) {
        // تعادل: نبدأ جولة جديدة بدون نقاط مضافة
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('الجولة محجوبة'),
            content: const Text('تعادل في النقاط. بدء جولة جديدة.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _initializeGame();
                },
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
        return;
      }
      final playerWins = playerRemaining < aiRemaining;
      _endGame(playerWins);
      return;
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (!gameOver) {
        _aiPlay();
      }
    });
  }

  void _endGame(bool playerWon) {
    gameOver = true;
    // حساب نقاط القطع المتبقية لدى الخصم وإضافتها للفائز
    final playerRemaining = _calculatePoints(playerTiles);
    final aiRemaining = _calculatePoints(aiTiles);
    if (playerWon) {
      playerScore += aiRemaining;
    } else {
      aiScore += playerRemaining;
    }

    final matchTarget = 100;
    final playerReached = playerScore > matchTarget;
    final aiReached = aiScore > matchTarget;

    if (playerReached || aiReached) {
      final winner = playerReached ? 'أنت' : 'الكمبيوتر';
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('انتهت المباراة!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الفائز بالمباراة: $winner'),
              const SizedBox(height: 8),
              Text('مجموع نقاطك: $playerScore'),
              Text('مجموع نقاط الكمبيوتر: $aiScore'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initializeGame(resetScores: true);
              },
              child: const Text('مباراة جديدة'),
            ),
          ],
        ),
      );
      return;
    }

    final roundWinner = playerWon ? 'أنت' : 'الكمبيوتر';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انتهت الجولة!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الفائز بالجولة: $roundWinner'),
            const SizedBox(height: 8),
            Text('مجموع نقاطك: $playerScore'),
            Text('مجموع نقاط الكمبيوتر: $aiScore'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeGame(
                  previousRoundWinner:
                      playerWon); // جولة جديدة مع تحديد الفائز بالجولة السابقة
            },
            child: const Text('جولة جديدة'),
          ),
        ],
      ),
    );
  }

  int _calculatePoints(List<DominoTile> tiles) {
    return tiles.fold(0, (sum, tile) => sum + tile.left + tile.right);
  }
}
