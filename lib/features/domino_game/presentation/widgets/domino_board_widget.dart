import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

// Domain imports
import '../../domain/entities/domino_tile.dart';

// Widget imports
import 'domino_tile_widget.dart';

// Provider imports
import '../../providers/match_provider.dart';

/// كلاس يمثل لوحة الدومينو
/// يحتوي على السلسلة الكاملة للبلاطات وقيم الأطراف المفتوحة
class DominoBoard {
  /// قائمة بلاطات السلسلة بالكامل
  final List<DominoTile> tilesOnBoard;

  /// قيمة الطرف الأول المفتوح (الرأس)
  final int? headValue;

  /// قيمة الطرف الثاني المفتوح (الذيل)
  final int? tailValue;

  const DominoBoard({
    required this.tilesOnBoard,
    this.headValue,
    this.tailValue,
  });

  bool get isEmpty => tilesOnBoard.isEmpty;
}

/// نتيجة تخطيط سلسلة البلاطات
class ChainLayoutResult {
  /// الـ Widget النهائي الذي يحتوي على جميع البلاطات
  final Widget widget;

  /// مواقع كل بلاطة على اللوحة
  final List<Offset> positions;

  /// اتجاه كل بلاطة (true: أفقي, false: عمودي)
  final List<bool> orientations;

  /// العرض الكلي للمحتوى المُخطط
  final double contentWidth;

  /// الارتفاع الكلي للمحتوى المُخطط
  final double contentHeight;

  const ChainLayoutResult({
    required this.widget,
    required this.positions,
    required this.orientations,
    required this.contentWidth,
    required this.contentHeight,
  });
}

/// Widget that displays a board for domino tiles
class DominoBoardWidget extends ConsumerStatefulWidget {
  final Function(DominoTile)? onTilePlayed;
  final bool showPlaceholders;
  final bool showTilesOverride;
  final TileContext tileContext;

  const DominoBoardWidget({
    Key? key,
    this.onTilePlayed,
    this.showPlaceholders = true,
    this.showTilesOverride = true,
    this.tileContext = TileContext.board,
  }) : super(key: key);

  @override
  ConsumerState<DominoBoardWidget> createState() => _DominoBoardWidgetState();
}

class _DominoBoardWidgetState extends ConsumerState<DominoBoardWidget> {
  // أبعاد البلاطات
  static const double _tileUnit = 70.0;
  static const double _tileLength = 140.0;
  static const double _tileGap = 1.0;
  static const double _boardPadding = 16.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_boardPadding),
      decoration: const BoxDecoration(
        color: Color(0xFFF5E6CC), // Light beige background
      ),
      child: Builder(builder: (context) {
        try {
          // Use the new optimized provider for board tiles
          final tilesToDisplay = ref.watch(boardTilesProvider);

          // Debug: Print tiles being displayed
          if (kDebugMode) {
            print('=== DEBUG: DominoBoardWidget Display Tiles ===');
            print('Tiles from provider: ${tilesToDisplay.length}');
            for (int i = 0; i < tilesToDisplay.length; i++) {
              final tile = tilesToDisplay[i];
              print('DisplayTile[$i]: ${tile.left}-${tile.right}');
            }
            print('==========================================');
          }

          if (tilesToDisplay.isEmpty) {
            return const Center(child: Text('ابدأ اللعب بوضع أول بلاطة!'));
          }

          final chainLayout = _calculateChainLayout(tilesToDisplay,
              MediaQuery.of(context).size.width - (_boardPadding * 2));

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chainLayout.contentWidth,
              height: chainLayout.contentHeight,
              child: Stack(
                children: [
                  chainLayout.widget,
                ],
              ),
            ),
          );
        } catch (e, stackTrace) {
          // Error handling - show a fallback UI
          if (kDebugMode) {
            print('DominoBoardWidget ERROR: $e');
            print('Stack trace: $stackTrace');
          }
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  const Text('Error loading board',
                      style: TextStyle(color: Colors.red)),
                  if (kDebugMode)
                    Text('Error: $e', style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          );
        }
      }),
    );
  }

  /// دالة لحساب مواضع واتجاهات البلاطات بناءً على قواعد التخطيط المعتمدة
  ChainLayoutResult _calculateChainLayout(
      List<DominoTile> tiles, double availableWidth) {
    // استخدام Snake Layout للعرض الأفضل مع دعم RTL
    return _calculateSnakeLayout(tiles, availableWidth);
  }

  /// دالة Snake Layout مع دعم RTL لعرض البلاطات بشكل متعرج
  ChainLayoutResult _calculateSnakeLayout(
      List<DominoTile> tiles, double availableWidth) {
    final positions = <Offset>[];
    final orientations = <bool>[];

    double currentX = 0.0;
    double currentY = 0.0;
    double maxContentWidth = availableWidth;
    double maxContentHeight = _tileUnit;

    // إعدادات RTL و Snake Pattern
    final bool isRTL = Directionality.of(context) == TextDirection.rtl;
    int currentRow = 0;
    bool snakeDirection = isRTL; // true = RTL, false = LTR
    currentX = snakeDirection ? availableWidth : 0.0;

    if (kDebugMode) {
      print('=== DEBUG: Snake Layout RTL Processing ===');
      print('Tiles count: ${tiles.length}');
      print('Available width: $availableWidth');
      print('Is RTL: $isRTL');
      print('Initial snake direction: ${snakeDirection ? "RTL" : "LTR"}');
    }

    for (int i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      final isDouble = tile.isDouble;
      final isHorizontal = !isDouble;

      final double tileW = isHorizontal ? _tileLength : _tileUnit;
      final double tileH = isHorizontal ? _tileUnit : _tileLength;

      // التحقق مما إذا كنا بحاجة للالتفاف إلى صف جديد
      bool needsNewRow = false;

      if (snakeDirection) {
        // في RTL: التحقق مما إذا كنا تجاوزنا الحد الأيسر
        if (currentX - tileW < 0) {
          needsNewRow = true;
        }
      } else {
        // في LTR: التحقق مما إذا كنا تجاوزنا الحد الأيمن
        if (currentX + tileW > availableWidth) {
          needsNewRow = true;
        }
      }

      if (needsNewRow && i > 0) {
        // الانتقال إلى صف جديد مع عكس الاتجاه (Snake Pattern)
        currentRow++;
        snakeDirection = !snakeDirection; // عكس الاتجاه
        currentY += _tileUnit + _tileGap;
        maxContentHeight = currentY + (isDouble ? _tileLength : _tileUnit);

        // إعادة تعيين الموقع حسب الاتجاه الجديد
        currentX = snakeDirection ? availableWidth : 0.0;

        if (kDebugMode) {
          print(
              'New row $currentRow at Y: $currentY, new direction: ${snakeDirection ? "RTL" : "LTR"}');
        }
      }

      // تحديد الموضع النهائي مع تعديل الاتجاه
      double finalX = currentX;
      if (snakeDirection) {
        finalX = currentX - tileW;
      }

      final position = Offset(finalX, currentY);
      positions.add(position);
      orientations.add(isHorizontal);

      // تحديث الموقع التالي حسب الاتجاه الحالي
      if (snakeDirection) {
        currentX -= tileW + _tileGap;
      } else {
        currentX += tileW + _tileGap;
      }

      if (kDebugMode) {
        print(
            'Tile[$i]: ${tile.left}-${tile.right} at ($finalX, $currentY) - Row: $currentRow, Direction: ${snakeDirection ? "RTL" : "LTR"}, Horizontal: $isHorizontal');
      }
    }

    // إنشاء الـ Stack النهائي للبلاطات مع تجنب التكرار
    final tilesWidget = Stack(
      children: List.generate(
        positions.length,
        (index) {
          try {
            if (index >= positions.length ||
                index >= orientations.length ||
                index >= tiles.length) {
              return const SizedBox.shrink();
            }

            final position = positions[index];
            final isHorizontal = orientations[index];
            final tile = tiles[index];

            return Positioned(
              left: position.dx,
              top: position.dy,
              child: GestureDetector(
                onTap: () => widget.onTilePlayed?.call(tile),
                child: DominoTileWidget(
                  tile: tile,
                  context: TileContext.board,
                  isHorizontal: isHorizontal,
                ),
              ),
            );
          } catch (e) {
            if (kDebugMode) {
              print('Error rendering tile at index $index: $e');
            }
            return const SizedBox.shrink();
          }
        },
      ),
    );

    return ChainLayoutResult(
      widget: tilesWidget,
      positions: positions,
      orientations: orientations,
      contentWidth: maxContentWidth,
      contentHeight: maxContentHeight + _boardPadding,
    );
  }
}

// -------------------------------------------------------------------
// 5. مكونات واجهة المستخدم الفرعية (AI Hand, Stock, Player Hand)
// -------------------------------------------------------------------

// ويدجت لعرض يد الخصم (AI Hand)
class AIHandWidget extends ConsumerWidget {
  const AIHandWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the new optimized provider
    final aiHand = ref.watch(aiHandProvider);

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.black.withOpacity(0.05),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: aiHand.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: DominoTileWidget(
              tile: aiHand[index],
              context: TileContext
                  .opponentHand, // Use opponentHand instead of aiHand
              isHorizontal: true, // عرض البلاطات أفقياً في اليد
            ),
          );
        },
      ),
    );
  }
}

// ويدجت لعرض صندوق السحب (Stock)
class StockWidget extends ConsumerWidget {
  const StockWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the new optimized provider
    final boneyard = ref.watch(boneyardProvider);

    return GestureDetector(
      onTap: () {
        if (kDebugMode) {
          print(
              'Attempting to draw a tile from Stock. Tiles left: ${boneyard.length}');
        }
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                // عرض بلاطة واحدة فقط تمثل الصندوق، مع صورة الظهر الخاصة به
                DominoTileWidget(
                  tile: DominoTile(left: 0, right: 0), // Dummy tile
                  context: TileContext.stock,
                  isHorizontal: true, // Display stock horizontally
                ),
                Positioned.fill(
                  child: Center(
                    child: Text(
                      '${boneyard.length}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('صندوق السحب'),
          ],
        ),
      ),
    );
  }
}

// ويدجت لعرض يد اللاعب (Player Hand)
class PlayerHandWidget extends ConsumerWidget {
  const PlayerHandWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the new optimized provider
    final playerHand = ref.watch(playerHandProvider);

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.blueGrey.withOpacity(0.1),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: playerHand.length,
        itemBuilder: (context, index) {
          final tile = playerHand[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: GestureDetector(
              onTap: () {
                if (kDebugMode) {
                  print(
                      'Player attempted to play tile: ${tile.left}:${tile.right}');
                }
              },
              child: DominoTileWidget(
                tile: tile,
                context: TileContext.playerHand,
                isHorizontal: true, // Display player's hand horizontally
              ),
            ),
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------------
// 6. شاشة اللعبة الرئيسية (DominoGameScreen)
// -------------------------------------------------------------------

class DominoGameScreen extends StatelessWidget {
  const DominoGameScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' الدومينو'),
        backgroundColor: const Color(0xFFF5E6CC),
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. يد الخصم (AI Hand)
            const AIHandWidget(),

            // 2. لوحة اللعب الرئيسية (Domino Board)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    // صندوق السحب (Stock)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: StockWidget(),
                    ),
                    // لوحة الدومينو (السلسلة)
                    const Expanded(
                      child: DominoBoardWidget(),
                    ),
                  ],
                ),
              ),
            ),
            // 3. يد اللاعب (Player Hand)
            const PlayerHandWidget(),
          ],
        ),
      ),
    );
  }
}
