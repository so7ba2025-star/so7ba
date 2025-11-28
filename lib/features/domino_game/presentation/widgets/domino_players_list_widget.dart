import 'package:flutter/material.dart';

import 'package:so7ba/models/room_models.dart';
import 'package:so7ba/models/match_models.dart';

class DominoPlayersListWidget extends StatelessWidget {
  const DominoPlayersListWidget({
    super.key,
    required this.players,
  });

  final List<RoomMember> players;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'اللاعبون في الغرفة',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...players.map(
          (player) {
            final isReady = player.isReady;
            final teamLabel = _teamLabel(player.team);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                boxShadow: isReady
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Text(player.displayName.isNotEmpty
                        ? player.displayName.characters.first
                        : '?'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (teamLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            teamLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isReady ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isReady ? Colors.greenAccent : Colors.white54,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String? _teamLabel(Team? team) {
    if (team == null) return null;
    switch (team) {
      case Team.a:
        return 'الفريق A';
      case Team.b:
        return 'الفريق B';
    }
    return null;
  }
}
