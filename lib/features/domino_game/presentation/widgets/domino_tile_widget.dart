import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:so7ba/features/domino_game/domain/entities/domino_tile.dart';

/// سياق استخدام البلاطة لتحديد الصورة المناسبة
enum TileContext {
  /// بلاطات لوحة اللعب (تظهر دائماً)
  board,
  /// بلاطات يد الخصم (تظهر كصورة ظهر الخصم)
  opponentHand,
  /// بلاطات صندوق السحب (تظهر كصورة ظهر السحب)
  stock,
  /// بلاطات يد اللاعب (تظهر دائماً)
  playerHand,
}

/// مكون مركزي لعرض بلاطة الدومينو
/// يستخدم الصور المناسبة حسب السياق
class DominoTileWidget extends StatelessWidget {
  final DominoTile tile;
  final TileContext context;
  final bool isHorizontal;
  final VoidCallback? onTap;
  final double? customWidth;
  final double? customHeight;

  const DominoTileWidget({
    Key? key,
    required this.tile,
    required this.context,
    this.isHorizontal = true,
    this.onTap,
    this.customWidth,
    this.customHeight,
  }) : super(key: key);

  /// الأبعاد الافتراضية للبلاطة
  static const double defaultTileWidth = 60.0;
  static const double defaultTileHeight = 30.0;

  /// الحصول على أبعاد البلاطة
  double get tileWidth => customWidth ?? (isHorizontal ? defaultTileWidth : defaultTileHeight);
  double get tileHeight => customHeight ?? (isHorizontal ? defaultTileHeight : defaultTileWidth);

  /// الحصول على مسار الصورة المناسبة
  String _getImagePath() {
    switch (context) {
      case TileContext.board:
      case TileContext.playerHand:
        // إظهار وجه البلاطة
        return isHorizontal 
            ? 'assets/Domino_tiels/domino_${tile.left}_${tile.right}.png'
            : 'assets/Domino_tiels/domino_${tile.left}_${tile.right}_v.png';
      
      case TileContext.opponentHand:
        // إظهار ظهر الخصم
        return 'assets/Domino_tiels/domino_back_ai.png';
      
      case TileContext.stock:
        // إظهار ظهر السحب
        return 'assets/Domino_tiels/domino_back.png';
    }
  }

  
  @override
  Widget build(BuildContext context) {
    final imagePath = _getImagePath();
    
    if (kDebugMode) {
      print('Loading image from path: $imagePath');
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: tileWidth,
        height: tileHeight,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Image.asset(
          imagePath,
          width: tileWidth,
          height: tileHeight,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              print('Error loading image: $error');
              print('Stack trace: $stackTrace');
            }
            return Center(
              child: Text(
                '${tile.left}|${tile.right}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Widget مخصص لعرض بلاطة في يد الخصم
class OpponentTileWidget extends StatelessWidget {
  final DominoTile tile;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const OpponentTileWidget({
    Key? key,
    required this.tile,
    this.onTap,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DominoTileWidget(
      tile: tile,
      context: TileContext.opponentHand,
      isHorizontal: true,
      onTap: onTap,
      customWidth: width,
      customHeight: height,
    );
  }
}

/// Widget مخصص لعرض بلاطة في صندوق السحب
class StockTileWidget extends StatelessWidget {
  final DominoTile tile;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const StockTileWidget({
    Key? key,
    required this.tile,
    this.onTap,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DominoTileWidget(
      tile: tile,
      context: TileContext.stock,
      isHorizontal: true,
      onTap: onTap,
      customWidth: width,
      customHeight: height,
    );
  }
}

/// Widget مخصص لعرض بلاطة في يد اللاعب
class PlayerTileWidget extends StatelessWidget {
  final DominoTile tile;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const PlayerTileWidget({
    Key? key,
    required this.tile,
    this.onTap,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DominoTileWidget(
      tile: tile,
      context: TileContext.playerHand,
      isHorizontal: true,
      onTap: onTap,
      customWidth: width,
      customHeight: height,
    );
  }
}

/// Widget مخصص لعرض بلاطة في لوحة اللعب
class BoardTileWidget extends StatelessWidget {
  final DominoTile tile;
  final VoidCallback? onTap;
  final bool isHorizontal;
  final double? width;
  final double? height;

  const BoardTileWidget({
    Key? key,
    required this.tile,
    this.onTap,
    this.isHorizontal = true,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DominoTileWidget(
      tile: tile,
      context: TileContext.board,
      isHorizontal: isHorizontal,
      onTap: onTap,
      customWidth: width,
      customHeight: height,
    );
  }
}
