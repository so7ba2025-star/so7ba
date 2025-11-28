import 'package:flutter/material.dart';

class AiTileWidget extends StatelessWidget {
  const AiTileWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/Domino_tiels/domino_back.png'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.black87,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
