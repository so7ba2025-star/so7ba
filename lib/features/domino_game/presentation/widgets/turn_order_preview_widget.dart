import 'package:flutter/material.dart';

import 'package:so7ba/models/room_models.dart';

class TurnOrderPreviewWidget extends StatelessWidget {
  const TurnOrderPreviewWidget({
    super.key,
    required this.players,
  });

  final List<RoomMember> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayPlayers = players.take(4).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ترتيب اللعب',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < displayPlayers.length; i++) ...[
              _TurnCircle(
                index: i + 1,
                label: displayPlayers[i].displayName,
              ),
              if (i < displayPlayers.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Colors.white70,
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TurnCircle extends StatelessWidget {
  const _TurnCircle({
    required this.index,
    required this.label,
  });

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.blueGrey.shade800,
          child: Text(
            '$index',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 72,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
