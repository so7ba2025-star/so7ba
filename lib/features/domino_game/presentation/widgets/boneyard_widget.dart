import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BoneyardWidget extends StatelessWidget {
  const BoneyardWidget({
    super.key,
    required this.tileCount,
    required this.onDrawTile,
    this.isEnabled = true,
  });

  final int tileCount;
  final VoidCallback onDrawTile;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) print('[Domino][Boneyard] building with $tileCount tiles');
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.brown.shade800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.brown.shade600, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الأحجار',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.brown.shade900,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$tileCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: isEnabled && tileCount > 0 ? onDrawTile : null,
            icon: const Icon(Icons.casino, size: 16),
            label: const Text('اسحب', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
