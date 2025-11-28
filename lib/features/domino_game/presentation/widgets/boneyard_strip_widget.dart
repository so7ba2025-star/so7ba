import 'dart:math' as math;

import 'package:flutter/material.dart';

class BoneyardStripWidget extends StatelessWidget {
  const BoneyardStripWidget({
    super.key,
    required this.tileCount,
    this.isLandscape = true,
    this.alignLeft = false,
    required this.onDrawTile,
    this.isEnabled = true,
    this.isGameStarted = false,
  });

  final int tileCount;
  final bool isLandscape;
  final bool alignLeft;
  final VoidCallback onDrawTile;
  final bool isEnabled;
  final bool isGameStarted;

  // Reduced width with minimal margins
  double get _stripWidth => isLandscape ? 38 : 32;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _stripWidth,
      child: Container(
        // No background or border
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final effectiveHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 320;
            const desiredHeaderHeight = 42.0;
            final headerHeight = math.min(desiredHeaderHeight, effectiveHeight * 0.5);
            final tileHeight = 18.0;
            final spacing = 4.0;
            final availableForTiles = math.max(0.0, effectiveHeight - headerHeight);
            final maxTiles = availableForTiles <= 0
                ? 0
                : math.max(0, (availableForTiles / (tileHeight + spacing)).floor());
            final visibleTiles = math.min(tileCount, maxTiles);

            Widget buildStack() {
              if (visibleTiles == 0) {
                return Container(
                  width: isLandscape ? 38 : 32,  // Reduced width with minimal margins
                  height: tileHeight,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white30, width: 1.2),
                  ),
                  child: const Icon(Icons.remove, color: Colors.white30, size: 14),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(visibleTiles, (index) {
                  final opacity = visibleTiles <= 1
                      ? 0.6
                      : 0.35 + ((index / (visibleTiles - 1)) * 0.45);
                  return Container(
                    width: isLandscape ? 38 : 32,  // Reduced width with minimal margins
                    height: tileHeight,
                    margin: EdgeInsets.only(
                      bottom: index == visibleTiles - 1 ? 0 : spacing,
                    ).copyWith(
                      left: 0,
                      right: 0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(opacity.clamp(0.25, 0.8)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white30, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.remove,
                      color: Colors.white38,
                      size: 16,
                    ),
                  );
                }),
              );
            }

            // Show empty state when game hasn't started or no tiles
            if (!isGameStarted || tileCount == 0) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 2, bottom: 2),
                  width: double.infinity,
                  height: headerHeight - 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0C9A6).withOpacity(0.5), // Lighter border color with opacity
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.casino_outlined, 
                    size: 24, 
                    color: Colors.white30,
                  ),
                ),
              );
            }
            
            return Column(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: buildStack(),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 0),
                  width: isLandscape ? 38 : 32,  // Same reduced width as tiles
                  height: 36,  // Slightly taller than tiles for better touch target
                  child: ElevatedButton(
                    onPressed: isEnabled ? onDrawTile : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      disabledBackgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),  // Match tile border radius
                      ),
                      elevation: 2,
                    ),
                    child: const Icon(Icons.casino, size: 20),  // Slightly smaller icon
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
