import '../entities/game_state.dart';

abstract class GameRepository {
  Future<GameState?> getGameState(String roomId);
  Future<void> saveGameState(GameState state);
  Future<void> resetGame(String roomId);
}
