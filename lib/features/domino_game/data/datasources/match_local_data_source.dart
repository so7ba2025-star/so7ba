class MatchLocalDataSource {
  final Set<String> _runningMatches = <String>{};

  Future<void> startMatch(String roomId) async {
    _runningMatches.add(roomId);
  }

  Future<void> endMatch(String roomId) async {
    _runningMatches.remove(roomId);
  }

  Future<bool> isMatchRunning(String roomId) async {
    return _runningMatches.contains(roomId);
  }
}
