import '../../domain/entities/game_state.dart';

class GameLocalDataSource {
  final Map<String, GameState> _storage = {};

  Future<GameState?> getGameState(String roomId) async {
    return _storage[roomId];
  }

  Future<void> saveGameState(GameState state) async {
    _storage[state.roomId] = state;
  }

  Future<void> deleteGame(String roomId) async {
    _storage.remove(roomId);
  }
}
