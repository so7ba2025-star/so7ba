import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

import '../../domain/entities/domino_tile.dart';
import '../../domain/controllers/domino_game_controller.dart';

/// شاشة وضع اللعب بكامل الشاشة (Landscape + Immersive)
/// ماتش مستقل يبدأ مباشرة، مع تصميم متماشي مع game_screen
class DominoFullscreenGameScreen extends StatefulWidget {
  const DominoFullscreenGameScreen({super.key});

  @override
  State<DominoFullscreenGameScreen> createState() =>
      _DominoFullscreenGameScreenState();
}

class _DominoFullscreenGameScreenState extends State<DominoFullscreenGameScreen>
    with SingleTickerProviderStateMixin {
  // حالة اللعبة عبر الكنترولر المشترك
  final DominoGameController _controller = DominoGameController();

  bool isAiThinking = false;
  String? _playerAvatarUrl;
  bool _hasShownGameOverDialog = false;

  // متغيرات الأنيميشن للخلفية
  late AnimationController _animationController;
  final List<Color> _gradientColors = [
    const Color(0xFFFF6B6B),
    const Color(0xFF8A0303),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _enableFullscreenPortrait();
    _initializeGame();
    _loadPlayerAvatar();
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

  Future<void> _initializeGame() async {
    setState(() {
      _controller.initializeGame(resetScores: true);
      isAiThinking = false;
    });

    // لو الكمبيوتر هو اللي يبدأ، نبدأ لعب الكمبيوتر بعد ثانية
    if (!_controller.isPlayerTurn) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_controller.gameOver) {
          _aiPlay();
        }
      });
    }
  }

  String _getTileImagePath(DominoTile tile, {bool isVertical = false}) {
    final suffix = isVertical ? '_v' : '';
    return 'assets/Domino_tiels/domino_${tile.left}_${tile.right}$suffix.png';
  }

  void _playTile(DominoTile tile) {
    if (!_controller.isPlayerTurn || _controller.gameOver) return;

    if (!_controller.canPlayTile(tile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن لعب هذه البلاطة هنا')),
      );
      return;
    }

    if (_controller.boardTiles.isEmpty) {
      setState(() {
        _controller.playerTiles.remove(tile);
        _controller.addTileToBoard(tile);
        _controller.isPlayerTurn = false;
      });
    } else {
      final canL = _controller.canPlayLeft(tile);
      final canR = _controller.canPlayRight(tile);

      // إذا كانت البلاطة يمكن لعبها على كلا الجانبين، نترك الاختيار للاعب
      if (canL && canR) {
        setState(() {
          _controller.pendingTile = tile;
        });
        return;
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

    if (_controller.playerTiles.isEmpty) {
      _endGame(true);
      return;
    }

    if (!_controller.isPlayerTurn) {
      Future.delayed(const Duration(milliseconds: 600), () {
        _aiPlay();
      });
    }
  }

  void _playTileOnSide(DominoTile tile, bool toLeft) {
    setState(() {
      _controller.playerTiles.remove(tile);
      _controller.addTileToBoardOnSide(tile, toLeft: toLeft);
      _controller.isPlayerTurn = false;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_controller.gameOver) {
        _aiPlay();
      }
    });
  }

  Future<void> _aiPlay() async {
    if (_controller.isPlayerTurn || _controller.gameOver || isAiThinking)
      return;

    setState(() => isAiThinking = true);

    // استدعاء دالة aiTurn المحدثة
    await _controller.aiTurn();

    setState(() => isAiThinking = false);
  }

  void _drawFromBoneyard() {
    if (!_controller.isPlayerTurn || _controller.gameOver) return;

    if (_controller.boneyard.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المخزن فارغ')),
      );
      return;
    }

    setState(() {
      final tile =
          _controller.boneyard.removeAt(_controller.boneyard.length - 1);
      _controller.playerTiles.add(tile);
    });

    // لا تفعل شيء بعد السحب - دع اللاعب يقرر ما يفعله
    // يمكنه السحب مرة أخرى إذا لم يجد بلاطة قابلة للعب
  }

  void _endGame(bool playerWon) {
    _controller.endRound(playerWon: playerWon);

    final isMatchOver = _controller.shouldEndMatch();
    final winnerMessage = isMatchOver
        ? _controller.getMatchWinnerMessage(playerWon: playerWon)
        : _controller.getRoundWinnerMessage(playerWon);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isMatchOver ? 'انتهت المباراة!' : 'انتهت الجولة!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(winnerMessage),
            const SizedBox(height: 8),
            Text('نقاطك: ${_controller.playerScore}'),
            Text('نقاط الكمبيوتر: ${_controller.aiScore}'),
          ],
        ),
        actions: [
          if (isMatchOver)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('خروج'),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initializeGame();
              },
              child: const Text('جولة جديدة'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('خروج'),
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
      return SizedBox(
        width: isPlayerHand ? 24.0 : 24.0, // مقاس أصغر للشاشة الرأسية
        height: isPlayerHand ? 48.0 : 48.0, // مقاس أصغر للشاشة الرأسية
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: const Image(
              image: AssetImage('assets/Domino_tiels/domino_back.png'),
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    final isDouble = tile.left == tile.right;
    final displayVertical = forceVertical ?? (isPlayerHand ? true : isDouble);

    final imagePath = _getTileImagePath(tile, isVertical: displayVertical);

    // بلاطات اليد (اللاعب) أصغر من بلاطات اللوحة - مقاسات للشاشة الرأسية
    final double width;
    final double height;

    if (displayVertical) {
      width = isPlayerHand ? 24.0 : 32.0;
      height = isPlayerHand ? 48.0 : 64.0;
    } else {
      width = isPlayerHand ? 48.0 : 64.0;
      height = isPlayerHand ? 24.0 : 32.0;
    }

    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        imagePath,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildBoardArea() {
    return Container(
      width: double.infinity, // امتداد بعرض الشاشة بالكامل
      margin: const EdgeInsets.only(
          left: 8,
          right: 8,
          top: 4,
          bottom: 4), // تقليل الهوامش العلوية والسفلية
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.brown.shade700,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.brown.shade900, width: 2),
      ),
      child: Column(
        children: [
          // أرقام الأطراف في أعلى مساحة اللعب
          if (_controller.boardTiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl, // تصحيح الاتجاه لـ RTL
                children: [
                  // الرقم الأيمن (الطرف الأيمن في RTL يظهر على اليمين)
                  Text(
                    _controller.rightEnd?.toString() ?? '0',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  // الرقم الأيسر (الطرف الأيسر في RTL يظهر على اليسار)
                  Text(
                    _controller.leftEnd?.toString() ?? '0',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          if (_controller.isPlayerTurn &&
              _controller.pendingTile != null &&
              _controller.canPlayLeft(_controller.pendingTile!) &&
              _controller.canPlayRight(_controller.pendingTile!))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                textDirection: TextDirection.rtl, // RTL للترتيب الصحيح
                children: [
                  // السهم الأيمن (الطرف الأيمن - يظهر على اليمين في RTL)
                  Column(
                    children: [
                      IconButton(
                        onPressed: _confirmPlayRight,
                        icon: Icon(
                          Icons.arrow_downward,
                          color: _controller.pendingTile != null &&
                                  _controller
                                      .canPlayLeft(_controller.pendingTile!) &&
                                  _controller
                                      .canPlayRight(_controller.pendingTile!)
                              ? Colors.white
                              : null,
                        ),
                        tooltip: 'اللعب على اليمين',
                      ),
                      const Text(
                        'يمين',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  // زر الإلغاء في المنتصف
                  Column(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _controller.pendingTile = null;
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
                  // السهم الأيسر (الطرف الأيسر - يظهر على اليسار في RTL)
                  Column(
                    children: [
                      IconButton(
                        onPressed: _confirmPlayLeft,
                        icon: Icon(
                          Icons.arrow_downward,
                          color: _controller.pendingTile != null &&
                                  _controller
                                      .canPlayLeft(_controller.pendingTile!) &&
                                  _controller
                                      .canPlayRight(_controller.pendingTile!)
                              ? Colors.white
                              : null,
                        ),
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
                if (_controller.boardTiles.isEmpty) {
                  return const Center(
                    child: Text(
                      'ابدأ اللعب بوضع بلاطة من يدك',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return Directionality(
                        textDirection: TextDirection.rtl,
                        child: _buildSnakeBoard(),
                      );
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
        final tileWidth = 24.0; // تصغير عرض البلاطة الأفقي أكثر
        final doubleTileWidth = 12.0; // تصغير عرض البلاطة العمودي أكثر
        final gap = 1.0; // تصغير المسافة
        
        List<Widget> rows = [];
        List<DominoTile> currentRowTiles = [];
        double currentRowWidth = 0.0;
        bool isRTL = true; // نبدأ من اليمين لـ RTL
        
        for (int i = 0; i < _controller.boardTiles.length; i++) {
          final tile = _controller.boardTiles[i];
          final isDouble = tile.left == tile.right;
          final tileW = isDouble ? doubleTileWidth : tileWidth;
          
          // التحقق إذا احتجنا لصف جديد مع معامل أمان للـ overflow
          if (currentRowWidth + tileW + gap > availableWidth * 0.95 && currentRowTiles.isNotEmpty) {
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
        
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: rows,
          ),
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

  void _confirmPlayLeft() {
    final t = _controller.pendingTile;
    if (t == null) return;
    setState(() {
      _controller.playerTiles.remove(t);
      _controller.addTileToBoardOnSide(t, toLeft: true);
      _controller.pendingTile = null;
      _controller.isPlayerTurn = false;
    });
    if (_controller.playerTiles.isEmpty) {
      _endGame(true);
      return;
    }
    Future.delayed(const Duration(milliseconds: 600), () {
      _aiPlay();
    });
  }

  void _confirmPlayRight() {
    final t = _controller.pendingTile;
    if (t == null) return;
    setState(() {
      _controller.playerTiles.remove(t);
      _controller.addTileToBoardOnSide(t, toLeft: false);
      _controller.pendingTile = null;
      _controller.isPlayerTurn = false;
    });
    if (_controller.playerTiles.isEmpty) {
      _endGame(true);
      return;
    }
    Future.delayed(const Duration(milliseconds: 600), () {
      _aiPlay();
    });
  }

  Widget _buildAiBar() {
    return Container(
      height: 85, // ارتفاع مناسب للشاشة الرأسية
      width: double.infinity, // امتداد بعرض الشاشة بالكامل
      margin: const EdgeInsets.only(
          left: 4, right: 4, top: 4, bottom: 2), // هوامش للشاشة الرأسية
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6), // padding مناسب للشاشة الرأسية
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: !_controller.isPlayerTurn
            ? Border.all(color: Colors.green, width: 2)
            : null,
        boxShadow: !_controller.isPlayerTurn
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24, // نفس مقاس لوجو اللاعب
            backgroundColor: Colors.green.shade600,
            child: const Icon(Icons.smart_toy,
                color: Colors.white, size: 28), // نفس حجم أيقونة اللاعب
          ),
          const SizedBox(width: 8),
          // نتيجة الكمبيوتر باللون الأخضر
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${_controller.aiScore}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                if (_controller.aiScore == 0)
                  const Text(
                    ' (0)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.normal,
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
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // عرض مؤقت لتشخيص المشكلة
                  if (_controller.aiTiles.isEmpty ||
                      _controller.gameOver ||
                      _controller.playerTiles.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'تشخيص:',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AI:${_controller.aiTiles.length}',
                            style: const TextStyle(
                                color: Colors.yellow, fontSize: 10),
                          ),
                          Text(
                            ' P:${_controller.playerTiles.length}',
                            style: const TextStyle(
                                color: Colors.cyan, fontSize: 10),
                          ),
                          Text(
                            ' B:${_controller.boneyard.length}',
                            style: const TextStyle(
                                color: Colors.green, fontSize: 10),
                          ),
                          if (_controller.gameOver)
                            const Text(
                              ' انتهت',
                              style: TextStyle(color: Colors.red, fontSize: 10),
                            ),
                          if (!_controller.gameOver)
                            Text(
                              ' تمرير:${_controller.consecutivePasses}',
                              style: const TextStyle(
                                  color: Colors.orange, fontSize: 10),
                            ),
                          if (_controller.isPlayerTurn)
                            const Text(
                              ' لاعب',
                              style:
                                  TextStyle(color: Colors.green, fontSize: 10),
                            ),
                          if (!_controller.isPlayerTurn)
                            const Text(
                              ' كمبيوتر',
                              style:
                                  TextStyle(color: Colors.purple, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ..._controller.aiTiles.map((tile) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: _buildTile(
                        tile,
                        showBack: true,
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          // زر الرجوع في نهاية الشريط
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            tooltip: 'رجوع',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerBar() {
    return Container(
      height: 85, // ارتفاع مناسب للشاشة الرأسية
      width: double.infinity, // امتداد بعرض الشاشة بالكامل
      margin: const EdgeInsets.only(
          left: 4, right: 4, top: 2, bottom: 4), // هوامش للشاشة الرأسية
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6), // padding مناسب للشاشة الرأسية
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: _controller.isPlayerTurn
            ? Border.all(color: Colors.blue, width: 2)
            : null,
        boxShadow: _controller.isPlayerTurn
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue.shade600,
            backgroundImage: _playerAvatarUrl != null
                ? NetworkImage(_playerAvatarUrl!)
                : null,
            child: _playerAvatarUrl == null
                ? const Icon(Icons.person, color: Colors.white, size: 28)
                : null,
          ),
          const SizedBox(width: 8),
          // نتيجة اللاعب باللون الأزرق
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.blue, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${_controller.playerScore}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                if (_controller.playerScore == 0)
                  const Text(
                    ' (0)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.normal,
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
                children: _controller.playerTiles.map((tile) {
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
          if (!_controller.gameOver &&
              _controller.isPlayerTurn &&
              !_controller.playerHasPlayable() &&
              _controller.boneyard.isNotEmpty)
            Row(
              children: [
                // زر السحب
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
                // زر المرور
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
                    onPressed: () {
                      _controller.passTurn();
                      Future.delayed(const Duration(milliseconds: 600), () {
                        _aiPlay();
                      });
                    },
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

  @override
  Widget build(BuildContext context) {
    // التحقق من انتهاء الجولة
    if (_controller.gameOver && !_hasShownGameOverDialog) {
      _hasShownGameOverDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _endGame(_controller.playerScore > _controller.aiScore);
      });
    } else if (!_controller.gameOver) {
      _hasShownGameOverDialog = false;
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 136, 4, 4),
              Color.fromARGB(255, 194, 2, 2),
            ],
          ),
        ),
        child: Stack(
          children: [
            ...List.generate(
              9,
              (index) => Positioned(
                top: Random().nextDouble() * MediaQuery.of(context).size.height,
                right:
                    Random().nextDouble() * MediaQuery.of(context).size.width,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animationController.value * 2 * pi,
                      child: Opacity(
                        opacity: 0.3,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Column(
              children: [
                _buildAiBar(),
                Expanded(child: _buildBoardArea()),
                _buildPlayerBar(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
