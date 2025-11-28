import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/domino_tile.dart';
import '../widgets/domino_board_widget.dart';
import '../../providers/match_provider.dart';
import '../widgets/domino_tile_widget.dart';

/// شاشة اللعبة الكاملة التي تجمع كل المكونات
/// تظهر يد الخصم، لوحة اللعب، صندوق السحب، ويد اللاعب
class DominoGameScreen extends ConsumerWidget {
  const DominoGameScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only watch what's needed for this screen
    final matchState = ref.watch(matchProvider);
    
    return Scaffold(
      backgroundColor: Colors.green[800],
      body: SafeArea(
        child: Column(
          children: [
            // Opponent's hand (top)
            _buildOpponentHand(),
            
            const SizedBox(height: 20),
            
            // Game board (middle)
            Expanded(
              child: _buildGameBoard(),
            ),
            
            const SizedBox(height: 20),
            
            // Draw pile and player's hand (bottom)
            _buildBottomSection(matchState),
          ],
        ),
      ),
    );
  }

  /// بناء يد الخصم
  Widget _buildOpponentHand() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Text(
            'خصم',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7, // عدد بلاطات الخصم
              itemBuilder: (context, index) {
                final tile = DominoTile(left: index % 7, right: (index + 1) % 7);
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: DominoTileWidget(
                    tile: tile,
                    context: TileContext.opponentHand,
                    isHorizontal: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// بناء لوحة اللعب
  Widget _buildGameBoard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[700],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[900]!, width: 2),
      ),
      child: Column(
        children: [
          const Text(
            'لوحة اللعب',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DominoBoardWidget(
              onTilePlayed: (tile) {
                // Handle tile tap
                if (kDebugMode) {
                  print('تم النقر على بلاطة: ${tile.left}|${tile.right}');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// بناء القسم السفلي (صندوق السحب ويد اللاعب)
  Widget _buildBottomSection(MatchState matchState) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // صندوق السحب
          _buildStockPile(),
          
          const SizedBox(height: 16),
          
          // يد اللاعب
          _buildPlayerHand(),
        ],
      ),
    );
  }

  /// بناء صندوق السحب
  Widget _buildStockPile() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'صندوق السحب',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 16),
        StockTileWidget(
          tile: const DominoTile(left: 0, right: 0), // بلاطة وهمية للصندوق
          width: 50,
          height: 25,
        ),
        const SizedBox(width: 8),
        const Text(
          '14',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// بناء يد اللاعب
  Widget _buildPlayerHand() {
    return Column(
      children: [
        const Text(
          'يدك',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7, // عدد بلاطات اللاعب
            itemBuilder: (context, index) {
              final tile = DominoTile(left: index % 7, right: (index + 1) % 7);
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: PlayerTileWidget(
                  tile: tile,
                  width: 50,
                  height: 25,
                  onTap: () {
                    print('تم النقر على بلاطة اللاعب: ${tile.left}|${tile.right}');
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
