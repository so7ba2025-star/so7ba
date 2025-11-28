import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/rooms_repository.dart';
import 'package:so7ba/models/room_models.dart';
import '../data/datasources/room_local_data_source.dart';
import '../data/repositories/room_repository_impl.dart';
import '../domain/repositories/room_repository.dart';

class RoomState {
  final String? currentRoomId;

  const RoomState({this.currentRoomId});

  RoomState copyWith({String? currentRoomId}) {
    return RoomState(
      currentRoomId: currentRoomId ?? this.currentRoomId,
    );
  }
}

class RoomNotifier extends StateNotifier<RoomState> {
  RoomNotifier(this._repository) : super(const RoomState());

  final RoomRepository _repository;

  Future<void> createRoom(String roomId) async {
    await _repository.createRoom(roomId);
    state = state.copyWith(currentRoomId: roomId);
  }

  Future<void> joinRoom(String roomId) async {
    final exists = await _repository.roomExists(roomId);
    if (exists) {
      state = state.copyWith(currentRoomId: roomId);
    }
  }

  Future<void> leaveRoom() async {
    final roomId = state.currentRoomId;
    if (roomId != null) {
      await _repository.deleteRoom(roomId);
      state = const RoomState(currentRoomId: null);
    }
  }
}

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepositoryImpl(RoomLocalDataSource());
});

final roomProvider =
    StateNotifierProvider<RoomNotifier, RoomState>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return RoomNotifier(repository);
});

// Provider for RoomsRepository singleton
final roomsRepositoryProvider = Provider<RoomsRepository>((ref) {
  return RoomsRepository();
});

// Stream provider for current room
final currentRoomProvider = StreamProvider<Room?>((ref) {
  final repository = ref.watch(roomsRepositoryProvider);
  return repository.roomStream;
});
