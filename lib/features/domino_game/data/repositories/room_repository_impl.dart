import '../../domain/repositories/room_repository.dart';
import '../datasources/room_local_data_source.dart';

class RoomRepositoryImpl implements RoomRepository {
  final RoomLocalDataSource localDataSource;

  RoomRepositoryImpl(this.localDataSource);

  @override
  Future<void> createRoom(String roomId) {
    return localDataSource.createRoom(roomId);
  }

  @override
  Future<bool> roomExists(String roomId) {
    return localDataSource.roomExists(roomId);
  }

  @override
  Future<void> deleteRoom(String roomId) {
    return localDataSource.deleteRoom(roomId);
  }
}
