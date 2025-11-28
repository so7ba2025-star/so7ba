import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DominoTileWidget extends StatelessWidget {
  const DominoTileWidget({
    super.key,
    required this.isFaceUp,
    this.leftValue,
    this.rightValue,
    this.onTap,
    this.isHighlighted = false,
  });

  final bool isFaceUp;
  final int? leftValue;
  final int? rightValue;
  final VoidCallback? onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isHighlighted ? Colors.blue : Colors.black87,
            width: isHighlighted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: isFaceUp ? _buildFaceUpTile() : _buildFaceDownTile(),
      ),
    );
  }

  Widget _buildFaceUpTile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Text(
                leftValue?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: double.infinity,
            color: Colors.black26,
          ),
          Expanded(
            child: Center(
              child: Text(
                rightValue?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceDownTile() {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/Domino_tiels/domino_back.png'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
