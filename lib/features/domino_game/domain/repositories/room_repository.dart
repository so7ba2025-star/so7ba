abstract class RoomRepository {
  Future<void> createRoom(String roomId);
  Future<bool> roomExists(String roomId);
  Future<void> deleteRoom(String roomId);
}
