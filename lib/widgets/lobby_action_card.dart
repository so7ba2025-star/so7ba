import 'package:flutter/material.dart';

/// ويدجت لعرض بطاقات الإجراءات في شاشة اللوبي
class LobbyActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const LobbyActionCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  }) : super(key: key);

  @override
  State<LobbyActionCard> createState() => _LobbyActionCardState();
}

class _LobbyActionCardState extends State<LobbyActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()
          ..scale(_isPressed ? 0.95 : 1.0, _isPressed ? 0.95 : 1.0, 1.0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.first.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.icon,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
