import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/game_local_data_source.dart';
import '../data/repositories/game_repository_impl.dart';
import '../domain/entities/game_state.dart';
import '../domain/repositories/game_repository.dart';

class GameNotifier extends StateNotifier<GameState?> {
  GameNotifier(this._repository) : super(null);

  final GameRepository _repository;

  Future<void> loadGameState(String roomId) async {
    final result = await _repository.getGameState(roomId);
    state = result;
  }

  Future<void> saveGameState(GameState newState) async {
    await _repository.saveGameState(newState);
    state = newState;
  }

  Future<void> resetGame(String roomId) async {
    await _repository.resetGame(roomId);
    state = null;
  }
}

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepositoryImpl(GameLocalDataSource());
});

final gameProvider =
    StateNotifierProvider<GameNotifier, GameState?>((ref) {
  final repository = ref.watch(gameRepositoryProvider);
  return GameNotifier(repository);
});
