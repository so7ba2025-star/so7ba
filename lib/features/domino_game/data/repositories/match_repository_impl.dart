import '../../domain/repositories/match_repository.dart';
import '../datasources/match_local_data_source.dart';

class MatchRepositoryImpl implements MatchRepository {
  final MatchLocalDataSource localDataSource;

  MatchRepositoryImpl(this.localDataSource);

  @override
  Future<void> startMatch(String roomId) {
    return localDataSource.startMatch(roomId);
  }

  @override
  Future<void> endMatch(String roomId) {
    return localDataSource.endMatch(roomId);
  }

  @override
  Future<bool> isMatchRunning(String roomId) {
    return localDataSource.isMatchRunning(roomId);
  }
}
