import 'package:flutter/material.dart';

import '../widgets/domino_game_card.dart';

class LobbyGamesScreen extends StatelessWidget {
  const LobbyGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // شاشة لوبي تحتوي تبويب "الألعاب" فقط
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 1,
        child: Scaffold(
          appBar: AppBar(
            // إنشاء تبويب جديد باسم "الألعاب" في شاشة اللوبي
            bottom: const TabBar(
              tabs: [
                Tab(text: 'الألعاب'),
              ],
            ),
            title: const Text('اللوبي'),
            centerTitle: true,
          ),
          body: const TabBarView(
            children: [
              // محتوى تبويب "الألعاب" الذي يعرض كارت لعبة الدومينو
              Padding(
                padding: EdgeInsets.all(16.0),
                child: DominoGameCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
