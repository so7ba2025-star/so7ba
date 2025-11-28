import 'package:flutter/material.dart';
import 'ai_tile_widget.dart';
class AiHandWidget extends StatelessWidget {
  const AiHandWidget({
    super.key,
    required this.tileCount,
  });

  final int tileCount;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * -8),
          child: Transform.scale(
            scale: value,
            child: child,
          ),
        );
      },
      child: SizedBox(
        height: 100, // نفس ارتفاع بلاطات اللاعب (عمودية 40x80)
        child: ListView.builder(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          itemCount: tileCount,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemBuilder: (context, index) {
            return const AiTileWidget();
          },
        ),
      ),
    );
  }
}
