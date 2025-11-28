import 'package:flutter/material.dart';

import '../../../domino_game/presentation/screens/domino_lobby_screen.dart';

class DominoGameCard extends StatelessWidget {
  const DominoGameCard({super.key});

  @override
  Widget build(BuildContext context) {
    // كارت  الدومينو داخل تبويب "الألعاب" في شاشة اللوبي
    return Directionality(
      textDirection: TextDirection.rtl,
      child: InkWell(
        // التعامل مع الضغط على الكارت لفتح شاشة لعبة الدومينو
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const DominoLobbyScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // نفس فكرة تصميم كارت اللوبي: زوايا دائرية + ظل خفيف + تدرج لوني
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF1F2937),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // أيقونة مناسبة لكارت لعبة الدومينو
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.view_column,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    // اسم اللعبة كما هو مطلوب "دومينو مصري الرباعي"
                    Text(
                      'دومينو  ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
