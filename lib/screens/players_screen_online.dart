import 'package:flutter/material.dart';
import 'package:so7ba/models/match_models.dart';

class PlayersScreen extends StatefulWidget {
  final DominoMatch match;
  
  const PlayersScreen({
    Key? key,
    required this.match,
  }) : super(key: key);

  @override
  _PlayersScreenState createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اللاعبون', style: TextStyle(fontFamily: 'Tajawal')),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTeamSection('الفريق الأول', 
                  [widget.match.players.a1, if (widget.match.players.a2 != null) widget.match.players.a2!]),
              const SizedBox(height: 24),
              _buildTeamSection('الفريق الثاني',
                  [widget.match.players.b1, if (widget.match.players.b2 != null) widget.match.players.b2!]),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('تم', style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamSection(String teamName, List<String> players) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teamName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
            const Divider(),
            ...players.map((player) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    player,
                    style: const TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
