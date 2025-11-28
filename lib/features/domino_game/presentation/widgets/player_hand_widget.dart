import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/domino_tile.dart';
import '../../providers/match_provider.dart';

class PlayerHandWidget extends ConsumerWidget {
  const PlayerHandWidget({
    super.key,
    required this.tiles,
    required this.onInvalidPlay,
    this.onTileTap,
  });

  final List<DominoTile> tiles;
  final VoidCallback onInvalidPlay;
  final ValueChanged<DominoTile>? onTileTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the new optimized provider instead of processing tiles here
    final playerHand = ref.watch(playerHandProvider);
    
    // Debug: طباعة تفاصيل البلاطات من الـ provider
    if (kDebugMode) {
      print('=== DEBUG: Player Hand Widget ===');
      print('Tiles from provider: ${playerHand.length}');
      for (int i = 0; i < playerHand.length; i++) {
        final tile = playerHand[i];
        print('ProviderTile[$i]: ${tile.left}-${tile.right}');
      }
      print('================================');
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: 100, // Match tile image height to avoid clipping
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 2, right: 10), // Added right padding for better edge spacing
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(playerHand.length, (index) {
              final tile = playerHand[index];
              return Transform.translate(
                offset: Offset(40.0 * index, 0), // زيادة كبيرة في التداخل بين البلاطات
                child: Draggable<DominoTile>(
                  data: tile,
                  // إضافة معرف فريد للـ drag
                  feedback: Material(
                    type: MaterialType.transparency,
                    child: Transform.rotate(
                      angle: 1.5708,
                      child: Container(
                        width: 90,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              '${tile.left}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 30,
                              color: Colors.black,
                            ),
                            Text(
                              '${tile.right}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  onDragStarted: () {
                    if (kDebugMode) print('[Domino][PlayerHand] DRAG STARTED: ${tile.left}-${tile.right}');
                    // عند بدء السحب، نقوم بتشغيل onTileTap
                    onTileTap?.call(tile);
                  },
                  onDragCompleted: () {
                    if (kDebugMode) print('[Domino][PlayerHand] DRAG COMPLETED: ${tile.left}-${tile.right}');
                  },
                  onDraggableCanceled: (velocity, offset) {
                    if (kDebugMode) print('[Domino][PlayerHand] DRAG CANCELED: ${tile.left}-${tile.right}');
                    onInvalidPlay();
                  },
                  onDragEnd: (details) {
                    if (kDebugMode) print('[Domino][PlayerHand] DRAG ENDED: wasAccepted=${details.wasAccepted}');
                    if (!details.wasAccepted) {
                      onInvalidPlay();
                    }
                  },
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _DominoTileView(tile: tile),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      if (kDebugMode) print('[Domino][PlayerHand] TAP: ${tile.left}-${tile.right}');
                      onTileTap?.call(tile);
                    },
                    child: Container(
                      width: 80, // حجم الخارجي أكبر قليلاً
                      height: 140, // حجم الخارجي أكبر قليلاً
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _DominoTileView(tile: tile),
                    ),
                  ),
                ),
              );
            }),
          )
        ),
      ),
    );
  }
}

class _DominoTileView extends StatelessWidget {
  const _DominoTileView({
    required this.tile,
  });

  final DominoTile tile;

  @override
  Widget build(BuildContext context) {
    final assetPath = 'assets/Domino_tiels/domino_${tile.left}-${tile.right}.png';
    
    // Debug: طباعة معلومات أبعاد الصورة
    if (kDebugMode) {
      print('=== DEBUG: Tile Image Dimensions ===');
      print('Tile: ${tile.left}-${tile.right}');
      print('Container size: 50 × 100');
      print('Image size: 50 × 100');
      print('Fit mode: BoxFit.none');
      print('Asset path: $assetPath');
      print('==================================');
    }
    
    return Transform.rotate(
      angle: 1.5708,
      child: Container(
        width: 50,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            assetPath,
            width: 50, // تصغير العرض
            height: 100, // تصغير الارتفاع
            fit: BoxFit.none, // تغيير إلى cover لملء المساحة بالكامل
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                print('ERROR: Failed to load image for tile ${tile.left}-${tile.right}');
                print('Error: $error');
              }
              return Container(
                width: 60, // نفس أبعاد الصورة
                height: 100, // نفس أبعاد الصورة
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Center(
                  child: Text(
                    '${tile.left}|${tile.right}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
