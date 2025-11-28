class RoomLocalDataSource {
  final Set<String> _rooms = <String>{};

  Future<void> createRoom(String roomId) async {
    _rooms.add(roomId);
  }

  Future<bool> roomExists(String roomId) async {
    return _rooms.contains(roomId);
  }

  Future<void> deleteRoom(String roomId) async {
    _rooms.remove(roomId);
  }
}
