import '../../domain/repositories/game_repository.dart';
import '../../domain/entities/game_state.dart';
import '../datasources/game_local_data_source.dart';

class GameRepositoryImpl implements GameRepository {
  final GameLocalDataSource localDataSource;

  GameRepositoryImpl(this.localDataSource);

  @override
  Future<GameState?> getGameState(String roomId) {
    return localDataSource.getGameState(roomId);
  }

  @override
  Future<void> saveGameState(GameState state) {
    return localDataSource.saveGameState(state);
  }

  @override
  Future<void> resetGame(String roomId) {
    return localDataSource.deleteGame(roomId);
  }
}
