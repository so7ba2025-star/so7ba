import 'dart:ui';

import 'package:flutter/material.dart';

class ScoreBoardWidget extends StatelessWidget {
  const ScoreBoardWidget({
    super.key,
    required this.redScore,
    required this.blueScore,
    required this.isRedTurn,
  });

  final int redScore;
  final int blueScore;
  final bool isRedTurn;

  @override
  Widget build(BuildContext context) {
    final redGlow = isRedTurn;
    final blueGlow = !isRedTurn;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TeamScoreBox(
                label: 'RED',
                score: redScore,
                color: Colors.red,
                glow: redGlow,
              ),
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: Colors.white.withOpacity(0.12),
              ),
              _TeamScoreBox(
                label: 'BLUE',
                score: blueScore,
                color: Colors.blue,
                glow: blueGlow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamScoreBox extends StatelessWidget {
  const _TeamScoreBox({
    required this.label,
    required this.score,
    required this.color,
    required this.glow,
  });

  final String label;
  final int score;
  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: glow ? 1.02 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.7),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$score',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
