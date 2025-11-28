abstract class MatchRepository {
  Future<void> startMatch(String roomId);
  Future<void> endMatch(String roomId);
  Future<bool> isMatchRunning(String roomId);
}
