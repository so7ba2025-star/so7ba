import 'package:flutter/material.dart';

class TeamSwitcher extends StatelessWidget {
  final bool isTeam1Selected;
  final Function(bool) onTeamSelected;
  final String team1Name;
  final String team2Name;

  const TeamSwitcher({
    Key? key,
    required this.isTeam1Selected,
    required this.onTeamSelected,
    required this.team1Name,
    required this.team2Name,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTeamButton(team1Name, true),
          _buildTeamButton(team2Name, false),
        ],
      ),
    );
  }

  Widget _buildTeamButton(String label, bool isTeam1) {
    final isSelected = isTeam1 ? isTeam1Selected : !isTeam1Selected;
    
    return Builder(
      builder: (context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: ElevatedButton(
            onPressed: () => onTeamSelected(isTeam1),
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey[300],
              foregroundColor: isSelected ? Colors.white : Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: isSelected ? 4 : 0,
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
