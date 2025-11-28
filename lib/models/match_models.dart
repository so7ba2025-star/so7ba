enum MatchMode { oneVOne, twoVTwo }

class PlayerNames {
  final String a1;
  final String? a2; // only for 2v2
  final String b1;
  final String? b2; // only for 2v2

  const PlayerNames({
    required this.a1,
    this.a2,
    required this.b1,
    this.b2,
  });

  Map<String, dynamic> toJson() => {
        'a1': a1,
        'a2': a2,
        'b1': b1,
        'b2': b2,
      };

  factory PlayerNames.fromJson(Map<String, dynamic> json) => PlayerNames(
        a1: json['a1'] as String,
        a2: json['a2'] as String?,
        b1: json['b1'] as String,
        b2: json['b2'] as String?,
      );
}

class RoundEntry {
  final int points; // points for the winning team in this round
  final Team winner;
  final DateTime timestamp;

  const RoundEntry({
    required this.points,
    required this.winner,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'points': points,
        'winner': winner.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory RoundEntry.fromJson(Map<String, dynamic> json) => RoundEntry(
        points: json['points'] as int,
        winner:
            Team.values.firstWhere((e) => e.name == json['winner'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

enum Team { a, b }

class DominoMatch {
  final String id;
  final MatchMode mode;
  final PlayerNames players;
  final DateTime startTime;
  final List<RoundEntry> rounds;
  final DateTime? finishedAt;
  final String? creatorId;

  DominoMatch({
    required this.id,
    required this.mode,
    required this.players,
    required this.startTime,
    List<RoundEntry>? rounds,
    this.finishedAt,
    this.creatorId,
  }) : rounds = rounds ?? [];

  int get _winThreshold => mode == MatchMode.oneVOne ? 101 : 151;

  int get scoreA => rounds
      .where((r) => r.winner == Team.a)
      .fold(0, (sum, r) => sum + r.points);

  int get scoreB => rounds
      .where((r) => r.winner == Team.b)
      .fold(0, (sum, r) => sum + r.points);

  bool get isFinished => scoreA >= _winThreshold || scoreB >= _winThreshold;

  Team? get winningTeam => isFinished
      ? (scoreA >= _winThreshold && scoreA >= scoreB
          ? Team.a
          : (scoreB >= _winThreshold ? Team.b : null))
      : null;

  DominoMatch copyWith({
    String? id,
    MatchMode? mode,
    PlayerNames? players,
    DateTime? startTime,
    List<RoundEntry>? rounds,
    DateTime? finishedAt,
    String? creatorId,
  }) {
    return DominoMatch(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      players: players ?? this.players,
      startTime: startTime ?? this.startTime,
      rounds: rounds ?? List.from(this.rounds),
      finishedAt: finishedAt ?? this.finishedAt,
      creatorId: creatorId ?? this.creatorId,
    );
  }

  Duration? get elapsedToWinningRound {
    if (!isFinished) return null;
    int accA = 0;
    int accB = 0;
    for (final r in rounds) {
      if (r.winner == Team.a)
        accA += r.points;
      else
        accB += r.points;
      if (accA >= _winThreshold || accB >= _winThreshold) {
        return r.timestamp.difference(startTime);
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.name,
        'players': players.toJson(),
        'startTime': startTime.toIso8601String(),
        'rounds': rounds.map((e) => e.toJson()).toList(),
        'finishedAt': finishedAt?.toIso8601String(),
        'creatorId': creatorId,
      };

  factory DominoMatch.fromJson(Map<String, dynamic> json) => DominoMatch(
        id: json['id'] as String,
        mode: MatchMode.values
            .firstWhere((e) => e.name == json['mode'] as String),
        players: PlayerNames.fromJson(json['players'] as Map<String, dynamic>),
        startTime: DateTime.parse(json['startTime'] as String),
        rounds: (json['rounds'] as List<dynamic>)
            .map((e) => RoundEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        finishedAt: (json['finishedAt'] as String?) != null
            ? DateTime.parse(json['finishedAt'] as String)
            : null,
        creatorId: json['creatorId'] as String?,
      );
}
