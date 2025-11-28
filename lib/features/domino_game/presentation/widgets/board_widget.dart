import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:so7ba/features/domino_game/domain/entities/domino_tile.dart';
import 'package:so7ba/features/domino_game/providers/match_provider.dart';

class DominoBoard {
  final List<DominoTile> centerTiles;
  final List<DominoTile> headBranch;
  final List<DominoTile> tailBranch;
  final int? headValue;
  final int? tailValue;

  const DominoBoard({
    required this.centerTiles,
    this.headBranch = const [],
    this.tailBranch = const [],
    this.headValue,
    this.tailValue,
  });

  DominoTile? get spinner {
    try {
      return centerTiles.firstWhere((tile) => tile.left == tile.right);
    } catch (e) {
      return centerTiles.isNotEmpty ? centerTiles.first : null;
    }
  }

  bool get hasFork => headBranch.isNotEmpty || tailBranch.isNotEmpty;
}

class ChainLayoutResult {
  final Widget widget;
  final List<Offset> positions;
  final List<bool> orientations;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final Offset spinnerPosition;
  final int spinnerIndex;

  const ChainLayoutResult({
    required this.widget,
    required this.positions,
    required this.orientations,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.spinnerPosition,
    required this.spinnerIndex,
  });
}

class DominoBoardWidget extends ConsumerStatefulWidget {
  final List<DominoTile> tiles;
  final bool showPlaceholders;
  final bool? showTilesOverride;
  final Function(DominoTile)? onTilePlayed;
  final Function(DominoTile)? onTileDropped;

  const DominoBoardWidget({
    Key? key,
    required this.tiles,
    this.showPlaceholders = true,
    this.showTilesOverride,
    this.onTilePlayed,
    this.onTileDropped,
  }) : super(key: key);

  @override
  ConsumerState<DominoBoardWidget> createState() => _DominoBoardWidgetState();
}

class _DominoBoardWidgetState extends ConsumerState<DominoBoardWidget> {
  static const double tileWidth = 70.0;
  static const double tileHeight = 140.0;
  static const double tileGap = 2.0;
  static const double boardPadding = 16.0;
  static const double boardBorderWidth = 8.0;
  
  final Map<String, ImageProvider> _imageCache = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _precacheTileImages();
  }

  Future<void> _precacheTileImages() async {
    if (!mounted || _isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final List<String> imagePaths = [];
      
      // إضافة جميع صور البلاطات الممكنة
      for (int i = 0; i <= 6; i++) {
        for (int j = i; j <= 6; j++) {
          imagePaths.add('assets/Domino_tiels/domino_${i}_${j}.png');
          imagePaths.add('assets/Domino_tiels/domino_${i}_${j}_v.png');
        }
      }
      
      // تحميل جميع الصور في الذاكرة المؤقتة
      for (final path in imagePaths) {
        if (!mounted) return;
        try {
          final image = AssetImage(path);
          await precacheImage(image, context);
          _imageCache[path] = image;
        } catch (e) {
          if (kDebugMode) {
            print('خطأ في تحميل الصورة: $path - $e');
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use selective providers for better performance
    final boardTiles = ref.watch(boardTilesProvider);
    final showTiles = widget.showTilesOverride ?? ref.watch(matchProvider.select((state) => state.showTiles));
    
    if (kDebugMode) {
      print('[DominoBoardWidget] showTiles: $showTiles, tiles count: ${boardTiles.length}');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 32;
        final availableHeight = constraints.maxHeight - 32;
        final dominoBoard = DominoBoard(centerTiles: boardTiles);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5E6CC),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // لوحة اللعب
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildDominoBoard(
                    dominoBoard,
                    tileWidth,
                    tileHeight,
                    null, // lastPlayedTile
                    availableWidth,
                    availableHeight,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDominoBoard(
    DominoBoard board,
    double tileWidth,
    double tileHeight,
    DominoTile? lastPlayedTile,
    double availableWidth,
    double availableHeight,
  ) {
    // بناء السلسلة المركزية
    final centerResult = _buildDominoChain(
      tiles: board.centerTiles,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      lastPlayedTile: lastPlayedTile,
      availableWidth: availableWidth,
      availableHeight: availableHeight,
    );

    // بناء الفروع إذا كانت موجودة
    if (board.hasFork) {
      return Stack(
        children: [
          // الفرع الأيمن (الرأس)
          if (board.headBranch.isNotEmpty)
            Positioned(
              left: centerResult.spinnerPosition.dx,
              top: centerResult.spinnerPosition.dy,
              child: _buildDominoChain(
                tiles: board.headBranch,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                lastPlayedTile: lastPlayedTile,
                availableWidth: availableWidth,
                availableHeight: availableHeight,
                startOffset: centerResult.spinnerPosition,
                startDirection: 0, // يمين
              ).widget,
            ),

          // الفرع الأيسر (الذيل)
          if (board.tailBranch.isNotEmpty)
            Positioned(
              left: centerResult.spinnerPosition.dx,
              top: centerResult.spinnerPosition.dy,
              child: _buildDominoChain(
                tiles: board.tailBranch,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                lastPlayedTile: lastPlayedTile,
                availableWidth: availableWidth,
                availableHeight: availableHeight,
                startOffset: centerResult.spinnerPosition,
                startDirection: 2, // يسار
              ).widget,
            ),

          // السلسلة المركزية
          Positioned(
            left: 0,
            top: 0,
            child: centerResult.widget,
          ),
        ],
      );
    }

    return centerResult.widget;
  }

  ChainLayoutResult _buildDominoChain({
    required List<DominoTile> tiles,
    required double tileWidth,
    required double tileHeight,
    required DominoTile? lastPlayedTile,
    required double availableWidth,
    required double availableHeight,
    Offset? startOffset,
    int startDirection = 0, // 0=يمين, 1=أسفل, 2=يسار, 3=أعلى
  }) {
    if (tiles.isEmpty) {
      return ChainLayoutResult(
        widget: const SizedBox.shrink(),
        positions: [],
        orientations: [],
        minX: 0,
        maxX: 0,
        minY: 0,
        maxY: 0,
        spinnerPosition: Offset.zero,
        spinnerIndex: -1,
      );
    }

    final positions = <Offset>[];
    final orientations = <bool>[];
    double currentX = startOffset?.dx ?? availableWidth / 2;
    double currentY = startOffset?.dy ?? availableHeight / 2;
    int currentDirection = startDirection;
    int spinnerIndex = -1;

    // حساب مواضع البلاطات
    for (int i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      final isDouble = tile.left == tile.right;
      
      // تحديد إذا كانت هذه البلاطة هي الـ spinner
      if (isDouble && spinnerIndex == -1) {
        spinnerIndex = i;
      }
      
      // إضافة الموضع الحالي
      positions.add(Offset(currentX, currentY));
      
      // تحديث الموضع التالي بناءً على الاتجاه الحالي
      switch (currentDirection) {
        case 0: // يمين
          currentX += tileWidth + tileGap;
          break;
        case 1: // أسفل
          currentY += tileHeight + tileGap;
          break;
        case 2: // يسار
          currentX -= tileWidth + tileGap;
          break;
        case 3: // أعلى
          currentY -= tileHeight + tileGap;
          break;
      }
    }

    // حساب الحدود
    double minX = positions.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    double maxX = positions.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    double minY = positions.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    double maxY = positions.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    
    // إضافة عرض البلاطة إلى الحد الأقصى
    maxX += tileWidth;
    maxY += tileHeight;

    // حساب موضع الـ spinner بعد التعديل
    Offset spinnerPosition = spinnerIndex != -1 
        ? Offset(
            positions[spinnerIndex].dx - minX,
            positions[spinnerIndex].dy - minY,
          )
        : Offset.zero;

    // بناء الـ widget
    final widget = SizedBox(
      width: maxX - minX,
      height: maxY - minY,
      child: Stack(
        children: List.generate(tiles.length, (index) {
          final tile = tiles[index];
          final position = positions[index];
          final isLastPlayed = lastPlayedTile == tile;
          
          return Positioned(
            left: position.dx - minX,
            top: position.dy - minY,
            child: _buildTileWidget(
              tile,
              tileWidth,
              tileHeight,
              false, // isVertical
              isLastPlayed,
            ),
          );
        }),
      ),
    );

    return ChainLayoutResult(
      widget: widget,
      positions: positions,
      orientations: orientations,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      spinnerPosition: spinnerPosition,
      spinnerIndex: spinnerIndex,
    );
  }

  Widget _buildTileWidget(
    DominoTile tile, 
    double width, 
    double height, 
    bool isVertical,
    bool isLastPlayed,
  ) {
    final assetPath = isVertical
        ? 'assets/Domino_tiels/domino_${tile.left}_${tile.right}_v.png'
        : 'assets/Domino_tiels/domino_${tile.left}_${tile.right}.png';

    return Container(
      width: isVertical ? height : width,
      height: isVertical ? width : height,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: _imageCache[assetPath] ?? AssetImage(assetPath),
          fit: BoxFit.contain,
        ),
        borderRadius: BorderRadius.circular(4),
        border: isLastPlayed
            ? Border.all(color: Colors.blue, width: 2)
            : null,
      ),
    );
  }

  Widget _buildPlaceholderGrid(int count) {
    if (count <= 0) return const SizedBox.shrink();
    
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: count,
      itemBuilder: (context, index) => _buildFlippedTile(),
    );
  }

  Widget _buildFlippedTile() {
    return Container(
      width: tileWidth,
      height: tileHeight,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!, width: 2),
      ),
      child: const Center(
        child: Icon(
          Icons.help_outline,
          color: Colors.white54,
          size: 40,
        ),
      ),
    );
  }
}
