import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room_models.dart';
import '../models/match_models.dart';
import 'profile_repository.dart';
import '../utils/realtime_utils.dart';

// Helper function to avoid 'unawaited' warning
void _unawaited(Future<void> future) {
  // ignore: unawaited_futures
  future.then((_) {}).catchError((e) => print('Error in unawaited future: $e'));
}

class RoomsRepository {
  static final RoomsRepository _instance = RoomsRepository._internal();
  factory RoomsRepository() => _instance;
  RoomsRepository._internal() {
    // Initialize with empty room
    _currentRoom = null;
  }

  /// Replace the local cache and stream with the provided messages list.
  void syncMessages(String roomId, List<RoomMessage> messages) {
    final sortedMessages = List<RoomMessage>.from(messages)
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

    _roomMessagesCache[roomId] = sortedMessages;

    if (_currentRoom != null && _currentRoom!.id == roomId) {
      _currentRoom = _currentRoom!.copyWith(
        messages: List<RoomMessage>.from(sortedMessages),
      );
      _roomController.add(_currentRoom);
    }

    _messagesController.add(List<RoomMessage>.from(sortedMessages));
  }

  Future<void> _addMessage(
    RoomMessage message, {
    bool persist = false,
    bool broadcast = false,
  }) async {
    try {
      final roomId = message.roomId;
      final currentUserId = this.currentUserId;
      final isCurrentUser = currentUserId != null && message.userId == currentUserId;

      print('🔄 [_addMessage] Adding message:');
      print('   - ID: ${message.id}');
      print('   - Room ID: $roomId');
      print('   - User ID: ${message.userId}');
      print('   - Is Current User: $isCurrentUser');
      print('   - Content: ${message.content}');

      // Initialize cache list with existing messages if available
      final cache = _roomMessagesCache.putIfAbsent(roomId, () {
        if (_currentRoom != null && _currentRoom!.id == roomId) {
          return List<RoomMessage>.from(_currentRoom!.messages);
        }
        return <RoomMessage>[];
      });

      // For current user's messages, check if we have a message with the same content and timestamp
      // to avoid duplicates when the same message is received multiple times
      final existingIndex = isCurrentUser 
          ? cache.indexWhere((m) => 
              m.userId == message.userId && 
              m.content == message.content &&
              m.sentAt.difference(message.sentAt).inSeconds.abs() < 5)
          : -1;

      if (existingIndex >= 0) {
        // Update existing message
        print('🔄 [_addMessage] Updating existing message at index $existingIndex');
        cache[existingIndex] = message;
      } else if (!cache.any((m) => m.id == message.id)) {
        // Only add if not already in the cache
        print('➕ [_addMessage] Adding new message to cache');
        cache.add(message);
        cache.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      } else {
        print('⏩ [_addMessage] Message already exists in cache, skipping');
      }

      // Always send all messages to the UI to ensure consistency
      print('📤 [_addMessage] Sending ${cache.length} messages to UI');
      _messagesController.add(List<RoomMessage>.from(cache));

      if (_currentRoom != null && _currentRoom!.id == roomId) {
        final updatedRoom = _currentRoom!.copyWith(
          messages: List<RoomMessage>.from(cache),
        );
        _currentRoom = updatedRoom;
        _roomController.add(updatedRoom);
      }

      if (persist) {
        if (_currentRoom != null && _currentRoom!.id == roomId) {
          await _saveRoomToDatabase(_currentRoom!);
        } else {
          await _supabase.from('rooms').update({
            'messages': cache.map((m) => m.toJson()).toList(),
          }).eq('id', roomId);
        }
      }

      if (broadcast) {
        await _currentRoomChannel?.broadcastMessage(
          event: _messageSentEvent,
          payload: message.toJson(),
        );
      }
    } catch (e) {
      print('Error adding message: $e');
      rethrow;
    }
  }

  static const String _roomsChannel = 'rooms';
  // Removed unused constant
  static const String _broadcastEvent = 'broadcast';
  static const String _memberJoinedEvent = 'member_joined';
  static const String _memberLeftEvent = 'member_left';
  static const String _memberUpdatedEvent = 'member_updated';
  static const String _messageSentEvent = 'message_sent';
  static const String _gameStartedEvent = 'game_started';
  static const String _roomClosedEvent = 'room_closed';

  // Supabase client and repositories
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProfileRepository _profileRepository = ProfileRepository();
  // Removed _deliveredMessageIds as we're now sending all messages to ensure consistency

  // Room state
  Room? _currentRoom;
  String? _currentRoomId;
  RealtimeChannel? _currentRoomChannel;
  RealtimeChannel? _roomsChannelSubscription;

  // Stream controllers
  final StreamController<Room?> _roomController =
      StreamController<Room?>.broadcast();
  final StreamController<List<RoomMessage>> _messagesController =
      StreamController<List<RoomMessage>>.broadcast();
  final StreamController<Map<String, dynamic>> _presenceController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Cache for full message history per room
  final Map<String, List<RoomMessage>> _roomMessagesCache = {};

  // Track initialization state
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get isDisposed => _roomController.isClosed;

  // Getters
  Stream<Room?> get roomStream => _roomController.stream;
  Stream<List<RoomMessage>> get messagesStream => _messagesController.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;

  // Ensure repository is attached to a specific room when UI navigates directly
  Future<void> enterRoom(Room room) async {
    try {
      _currentRoom = room;
      _currentRoomId = room.id;
      _roomController.add(room);
      await _subscribeToRoomChannel(room.id);
      await _trackPresence(room.id);
      await _refreshRoom();
    } catch (e) {
      rethrow;
    }
  }

  // Get current user ID and profile info
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Get current user display name
  String? get displayName =>
      _supabase.auth.currentUser?.userMetadata?['name'] as String? ?? 'Player';

  // Get current user profile
  Map<String, dynamic> get profile =>
      _supabase.auth.currentUser?.userMetadata ?? {};

  // Save room to database
  Future<void> _saveRoomToDatabase(Room room) async {
    try {
      await _supabase.from('rooms').upsert({
        'id': room.id,
        'code': room.code,
        'name': room.name,
        'host_id': room.hostId,
        'game_mode': 'public',
        'status': room.status.toString().split('.').last,
        'created_at': room.createdAt.toIso8601String(),
        'members': room.members.map((m) => m.toJson()).toList(),
        'messages': room.messages.map((m) => m.toJson()).toList(),
      });
    } catch (e) {
      print('Error saving room to database: $e');
      rethrow;
    }
  }

  // Load public rooms from database
  Future<List<Room>> getPublicRooms() async {
    try {
      print('\n🔍 [getPublicRooms] Starting to fetch public rooms...');

      // Check authentication
      final currentUser = _supabase.auth.currentUser;
      final currentSession = _supabase.auth.currentSession;

      print(
          '👤 [getPublicRooms] Current user: ${currentUser?.id ?? 'Not logged in'}');
      print(
          '🔑 [getPublicRooms] Session: ${currentSession != null ? 'Active' : 'No session'}');

      if (currentUser == null || currentSession == null) {
        print('❌ [getPublicRooms] No active user session');
        return [];
      }

      // Debug: Print the actual query we're about to make
      final statusFilter = RoomStatus.waiting.toString().split('.').last;
      print(
          '🔎 [getPublicRooms] Query: SELECT * FROM rooms WHERE status = "$statusFilter" ORDER BY created_at DESC');

      // Add timeout and print timing
      print('⏳ [getPublicRooms] Executing query...');
      final stopwatch = Stopwatch()..start();

      final response = await _supabase
          .from('rooms')
          .select()
          .eq('status', statusFilter)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      stopwatch.stop();
      print(
          '✅ [getPublicRooms] Query completed in ${stopwatch.elapsedMilliseconds}ms');

      if (response == null) {
        print('⚠️ [getPublicRooms] Received null response from database');
        return [];
      }

      if (response is! List) {
        print(
            '⚠️ [getPublicRooms] Unexpected response format: ${response.runtimeType}');
        print('⚠️ [getPublicRooms] Response content: $response');
        return [];
      }

      print(
          '✅ [getPublicRooms] Received ${response.length} rooms from database');

      final rooms = <Room>[];

      for (var data in response) {
        try {
          if (data == null) continue;

          print('🔄 [getPublicRooms] Processing room data: $data');

          // Parse room data with null safety
          final roomId = data['id']?.toString();
          if (roomId == null || roomId.isEmpty) {
            print('⚠️ [getPublicRooms] Skipping room with invalid ID');
            continue;
          }

          final room = Room(
            id: roomId,
            code: data['code']?.toString() ?? '??????',
            name: data['name']?.toString() ?? 'غرفة جديدة',
            hostId: data['host_id']?.toString() ?? '',
            status: RoomStatus.values.firstWhere(
              (e) => e.toString() == 'RoomStatus.${data['status']}',
              orElse: () => RoomStatus.waiting,
            ),
            createdAt:
                DateTime.tryParse(data['created_at']?.toString() ?? '') ??
                    DateTime.now(),
            members: (data['members'] is List ? data['members'] : <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .map((m) {
                  try {
                    return RoomMember.fromJson(m);
                  } catch (e) {
                    print('⚠️ [getPublicRooms] Error parsing member: $e');
                    return null;
                  }
                })
                .whereType<RoomMember>()
                .toList(),
          );

          rooms.add(room);
          print('✅ [getPublicRooms] Added room: ${room.name} (${room.id})');
        } catch (e) {
          print('❌ [getPublicRoams] Error parsing room data: $e');
          print('❌ [getPublicRoams] Problematic data: $data');
        }
      }

      print('✨ [getPublicRoams] Successfully parsed ${rooms.length} rooms');
      return rooms;
    } catch (e) {
      print('❌ [getPublicRoams] Error loading public rooms: $e');
      rethrow;
    }
  }

  // Initialize the repository
  Future<void> initialize() async {
    if (_isInitialized) return;

    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Load initial rooms
      final rooms = await getPublicRooms();
      for (var room in rooms) {
        _roomController.add(room);
      }

      // Subscribe to public rooms updates
      _subscribeToRoomsChannel();

      _isInitialized = true;
      print('RoomsRepository initialized successfully');
    } catch (e) {
      _isInitialized = false;
      print('Error initializing RoomsRepository: $e');
      rethrow;
    }
  }

  // Create a new room
  Future<Room> createRoom({
    required String name,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get current user profile for host info
      final profile = await _profileRepository.getProfile(userId);

      // Generate a random 6-character room code
      final code = _generateRoomCode();

      // Create room state with a unique ID
      final roomId =
          'room_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
      final now = DateTime.now();

      final firstName = (profile['first_name'] ?? '').toString().trim();
      final lastName = (profile['last_name'] ?? '').toString().trim();
      final displayName =
          [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();

      final hostMember = RoomMember(
        userId: userId,
        displayName: displayName.isNotEmpty ? displayName : 'مستخدم',
        avatarUrl: profile['avatar_url'] as String?,
        isHost: true,
        isReady: true,
      );

      final room = Room(
        id: roomId,
        code: code,
        name: name,
        hostId: userId,
        status: RoomStatus.waiting,
        createdAt: now,
        members: [hostMember],
      );

      // Set current room before tracking presence
      _currentRoom = room;
      _currentRoomId = roomId;

      // Save room to database
      await _saveRoomToDatabase(room);

      // Subscribe to room channel
      await _subscribeToRoomChannel(roomId);

      // Track presence in this room
      await _trackPresence(roomId);

      // Update the room stream with the new room
      _roomController.add(room);

      // Broadcast room creation (for public rooms list)
      await _broadcastRoomUpdate(room);

      // Force a refresh of the rooms list
      final updatedRooms = await getPublicRooms();
      for (var r in updatedRooms) {
        _roomController.add(r);
      }

      // Send a welcome message
      await _sendSystemMessage(roomId, 'أنشأ ${hostMember.displayName} الغرفة', hostMember.avatarUrl);

      return room;
    } catch (e) {
      print('Error creating room: $e');
      rethrow;
    }
  }

  // Leave the current room
  Future<void> leaveRoom({String? roomId}) async {
    String? userId;
    String? displayName;
    
    try {
      userId = currentUserId;
      roomId ??= _currentRoomId; // Use provided roomId or fallback to _currentRoomId
      
      if (userId == null) {
        print('❌ [leaveRoom] User not logged in');
        throw Exception('User not logged in');
      }
      
      if (roomId == null) {
        print('⚠️ [leaveRoom] No room ID provided, trying to find active room...');
        // Try to find the room that contains this user
        try {
          // First get all rooms
          final allRooms = await _supabase
              .from('rooms')
              .select();
              
          // Filter rooms where the user is a member
          final userRooms = allRooms.where((room) {
            final members = (room['members'] as List<dynamic>?) ?? [];
            return members.any((member) => 
              member is Map && member['user_id'] == userId);
          }).toList();
          
          if (userRooms.isNotEmpty) {
            roomId = userRooms.first['id'] as String?;
            print('ℹ️ [leaveRoom] Found active room: $roomId');
          }
          
          if (roomId == null) {
            print('❌ [leaveRoom] No active room found for user $userId');
            throw Exception('No active room found');
          }
        } catch (e) {
          print('⚠️ [leaveRoom] Error finding user rooms: $e');
          throw Exception('Error finding active room');
        }
      }

      print('🚪 [leaveRoom] User $userId is leaving room $roomId');

      // 1. First, get the current room data
      final response = await _supabase
          .from('rooms')
          .select()
          .eq('id', roomId)
          .single();

      if (response == null) {
        print('❌ [leaveRoom] Room not found: $roomId');
        throw Exception('Room not found');
      }

      // Parse room data
      final room = _roomFromJson(response);
      if (room == null) {
        print('❌ [leaveRoom] Failed to parse room data');
        throw Exception('Failed to parse room data');
      }

      // 2. Store display name before any cleanup
      final member = room.members.firstWhere(
        (m) => m.userId == userId,
        orElse: () => RoomMember(
          userId: userId!,
          displayName: 'مستخدم',
          isHost: false,
          isReady: false,
        ),
      );
      displayName = member.displayName;

      // 3. Update the room in the database
      final updatedMembers = room.members.where((m) => m.userId != userId).toList();
      
      if (updatedMembers.isEmpty) {
        // Delete the room if no members left
        await _supabase.from('rooms').delete().eq('id', roomId);
        print('🗑️ [leaveRoom] Room $roomId deleted (no members left)');
      } else {
        // Check if the leaving user was the host
        String newHostId = room.hostId;
        if (room.hostId == userId) {
          // Assign new host (first member in the list)
          newHostId = updatedMembers.first.userId;
          print('👑 [leaveRoom] Assigned new host: $newHostId');
        }
        
        // Update the room with the new members and host
        await _supabase.from('rooms').update({
          'members': updatedMembers.map((m) => m.toJson()).toList(),
          'host_id': newHostId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', roomId);
        
        print('✅ [leaveRoom] User $userId removed from room $roomId');
      }
      
      // 4. Get channel reference BEFORE cleanup
      final channel = _currentRoomChannel;
      print('🔍 [leaveRoom] Channel status check:');
      print('   - Channel exists: ${channel != null}');
      if (channel != null) {
        print('   - Room ID: $roomId');
      }
      
      // 5. Notify others that we're leaving BEFORE cleaning up local state
      if (channel != null) {
        try {
          print('📢 [leaveRoom] Sending leave notification...');
          print('📢 [leaveRoom] Payload: {user_id: $userId, display_name: $displayName}');
          print('📢 [leaveRoom] Channel exists: ${channel != null}');
          
          await channel.broadcastMessage(
            event: _memberLeftEvent,
            payload: {
              'user_id': userId,
              'display_name': displayName ?? 'مستخدم',
              'avatar_url': _currentRoom!.members.firstWhere(
                (m) => m.userId == userId,
                orElse: () => RoomMember(
                  userId: userId ?? 'unknown', 
                  displayName: displayName ?? 'مستخدم', 
                  avatarUrl: null,
                  isHost: false,
                  isReady: false,
                  isSpectator: false,
                ),
              ).avatarUrl,
            },
          );
          print('✅ [leaveRoom] Left notification sent successfully');
        } catch (e) {
          print('❌ [leaveRoom] Error sending leave notification: $e');
          // Continue even if notification fails
        }
      } else {
        print('⚠️ [leaveRoom] No channel available for leave notification');
      }
      
      // 6. Clean up local state AFTER sending notifications
      await _cleanupRoomState();
      
      print('✅ [leaveRoom] Successfully left room $roomId');
    } catch (e, stackTrace) {
      print('❌ [leaveRoom] Error leaving room: $e');
      print('Stack trace: $stackTrace');
      
      // Try to clean up even if there was an error
      try {
        await _cleanupRoomState();
      } catch (cleanupError) {
        print('⚠️ [leaveRoom] Error during cleanup: $cleanupError');
      }
      
      rethrow;
    }
  }

  // Join an existing room
  Future<Room> joinRoom(String roomId, {String? code}) async {
    try {
      print('🚀 [joinRoom] ===== STARTING ROOM JOIN PROCESS =====');
      print('🚀 [joinRoom] Room ID: $roomId');

      final userId = currentUserId;
      if (userId == null) {
        print('❌ [joinRoom] User not authenticated');
        throw Exception('User not authenticated');
      }

      print('\n🔍 [joinRoom] 1. Fetching user profile...');
      final profile = await _profileRepository.getProfile(userId);
      if (profile.isEmpty) {
        print('❌ [joinRoom] User profile not found');
        throw Exception('User profile not found');
      }

      final displayName = '${profile['first_name']} ${profile['last_name']}';
      final avatarUrl = profile['avatar_url'] as String?;
      print('✅ [joinRoom] Profile found: $displayName');

      // Check if already in a room; leave only if it's a DIFFERENT room
      if (_currentRoom != null && _currentRoomId != roomId) {
        print(
            'ℹ️ [joinRoom] Already in room ${_currentRoom!.id}, leaving before joining $roomId');
        await leaveRoom();
      }

      // Fetch room from database
      print('\n🔍 [joinRoom] 2. Fetching room data from database...');
      final response =
          await _supabase.from('rooms').select().eq('id', roomId).single();

      // Parse room data
      print('\n🔍 [joinRoom] 3. Parsing room data...');
      final room = _roomFromJson(Map<String, dynamic>.from(response));

      if (room == null) {
        print('❌ [joinRoom] Failed to parse room data');
        throw Exception('Failed to parse room data');
      }

      // Check room code if provided
      if (code != null && room.code != code) {
        print('❌ [joinRoom] Invalid room code');
        throw Exception('Invalid room code');
      }

      
      // Check if user is already a member
      final memberIndex = room.members.indexWhere((m) => m.userId == userId);
      Room updatedRoom;

      if (memberIndex == -1) {
        // Add user as a new member
        print('🔍 [joinRoom] 4. Adding user as a new member');
        final newMember = RoomMember(
          userId: userId,
          displayName: displayName,
          avatarUrl: avatarUrl,
          isHost: false,
          isReady: false,
        );

        // Update room with new member
        updatedRoom = room.copyWith(
          members: [...room.members, newMember],
        );

        // Save to database
        print('💾 [joinRoom] 5. Saving updated room to database');
        await _saveRoomToDatabase(updatedRoom);

        // Subscribe to room channel
        print('🔔 [joinRoom] 6. Subscribing to room channel');
        await _subscribeToRoomChannel(roomId);

        // Track presence
        print('👥 [joinRoom] 7. Tracking presence');
        await _trackPresence(roomId);

        // Notify others
        print('📢 [joinRoom] 8. Broadcasting member joined event');
        print('📢 [joinRoom] Channel exists: ${_currentRoomChannel != null}');
        print('📢 [joinRoom] Broadcasting payload: {user_id: $userId, display_name: $displayName}');
        
        await _currentRoomChannel?.broadcastMessage(
          event: _memberJoinedEvent,
          payload: {
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': avatarUrl,
            'is_host': false,
            'is_ready': false,
          },
        );
        print('✅ [joinRoom] Member joined broadcast sent successfully');
      } else {
        // User already in room, update their status
        print('\n🔍 [joinRoom] 9. User already in room, updating status...');

        // Create updated member with current info
        final updatedMember = room.members[memberIndex].copyWith(
          displayName: displayName,
          avatarUrl: avatarUrl,
          isReady:
              room.members[memberIndex].isReady, // Keep existing ready status
        );

        // Update members list
        final updatedMembers = List<RoomMember>.from(room.members);
        updatedMembers[memberIndex] = updatedMember;

        // Update room
        updatedRoom = room.copyWith(members: updatedMembers);

        // Save to database
        print('   - Saving updated room to database');
        try {
          await _saveRoomToDatabase(updatedRoom);
        } catch (e) {
          print(
              '⚠️ [joinRoom] Error updating room, trying to rejoin as new member: $e');
          // If update fails, try to rejoin as a new member
          final newMember = RoomMember(
            userId: userId,
            displayName: displayName,
            avatarUrl: avatarUrl,
            isHost: false,
            isReady: false,
          );

          updatedRoom = room.copyWith(
            members: [...room.members, newMember],
          );

          await _saveRoomToDatabase(updatedRoom);
        }

        // Subscribe to room channel if not already
        if (_currentRoomChannel == null) {
          print('   - Subscribing to room channel');
          await _subscribeToRoomChannel(roomId);
          await _trackPresence(roomId);
        }

        // Update current room state
        _currentRoom = updatedRoom;
        _currentRoomId = roomId;
        _roomController.add(updatedRoom);

        // Broadcast member reconnected
        await _currentRoomChannel?.broadcastMessage(
          event: _memberUpdatedEvent,
          payload: {
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': avatarUrl,
            'is_ready': updatedMember.isReady,
          },
        );
      }

      // Update local state
      _currentRoom = updatedRoom;
      _currentRoomId = roomId;
      _roomController.add(updatedRoom);

      print('✅ [joinRoom] Successfully joined room $roomId');
      return updatedRoom;
    } catch (e, stackTrace) {
      print('❌ [joinRoom] Error joining room: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Join a room as a spectator (no player capacity limit)
  Future<Room> joinAsSpectator(String roomId) async {
    try {
      print('👀 [joinAsSpectator] Joining as spectator for room $roomId');

      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Load user profile
      final profile = await _profileRepository.getProfile(userId);
      final displayName = '${profile['first_name']} ${profile['last_name']}';
      final avatarUrl = profile['avatar_url'] as String?;

      // If already in some room, leave first
      if (_currentRoom != null) {
        await leaveRoom();
      }

      // Fetch room
      final response = await _supabase.from('rooms').select().eq('id', roomId).single();
      final room = _roomFromJson(Map<String, dynamic>.from(response));
      if (room == null) {
        throw Exception('Failed to parse room data');
      }

      // If already member, just update flags to spectator if needed
      final idx = room.members.indexWhere((m) => m.userId == userId);
      Room updatedRoom;
      if (idx >= 0) {
        final updatedMember = room.members[idx].copyWith(
          displayName: displayName,
          avatarUrl: avatarUrl,
          isSpectator: true,
          isReady: false,
        );
        final updatedMembers = List<RoomMember>.from(room.members);
        updatedMembers[idx] = updatedMember;
        updatedRoom = room.copyWith(members: updatedMembers);
      } else {
        // Add as new spectator member
        final spectator = RoomMember(
          userId: userId,
          displayName: displayName,
          avatarUrl: avatarUrl,
          isHost: false,
          isReady: false,
          isSpectator: true,
        );
        updatedRoom = room.copyWith(members: [...room.members, spectator]);
      }

      // Persist
      print('💾 [joinAsSpectator] Saving updated room...');
      await _saveRoomToDatabase(updatedRoom);
      print('✅ [joinAsSpectator] Room saved');

      // Set local state before async subscriptions to allow UI to proceed
      _currentRoom = updatedRoom;
      _currentRoomId = roomId;
      _roomController.add(updatedRoom);

      // Start subscribe/track without blocking the caller
      () async {
        print('🔔 [joinAsSpectator] Subscribing to room channel (async)...');
        try {
          await _subscribeToRoomChannel(roomId).timeout(const Duration(seconds: 5));
          print('✅ [joinAsSpectator] Subscribed to room channel');
        } catch (e) {
          print('⚠️ [joinAsSpectator] Subscribe timeout or error: $e');
        }
        print('👥 [joinAsSpectator] Tracking presence (async)...');
        try {
          await _trackPresence(roomId).timeout(const Duration(seconds: 5));
          print('✅ [joinAsSpectator] Presence tracked');
        } catch (e) {
          print('⚠️ [joinAsSpectator] Presence timeout or error: $e');
        }
        // Broadcast join as spectator
        await _currentRoomChannel?.broadcastMessage(
          event: _memberJoinedEvent,
          payload: {
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': avatarUrl,
            'is_host': false,
            'is_ready': false,
            'is_spectator': true,
          },
        );
      }();

      print('✅ [joinAsSpectator] Joined room $roomId as spectator');
      return updatedRoom;
    } catch (e, stackTrace) {
      print('❌ [joinAsSpectator] Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  Future<void> sendMessage(
    String content, {
      String? userId,
  }) async {
    try {
      if (content.trim().isEmpty) return;

      // Use provided userId or fall back to currentUserId
      final effectiveUserId = userId ?? currentUserId;
      if (_currentRoomId == null || effectiveUserId == null) {
        print('❌ [sendMessage] No user ID or room ID');
        return;
      }

      print('📤 [sendMessage] Sending message: $content');
      print('👤 [sendMessage] Sending as user ID: $effectiveUserId');
      print('🏠 [sendMessage] Current room ID: $_currentRoomId');

      // Get user profile for display name
      Map<String, dynamic> profile;
      try {
        profile = await _profileRepository.getProfile(effectiveUserId);
        print('👤 [sendMessage] Profile data: $profile');
      } catch (e) {
        print('⚠️ [sendMessage] Error getting profile, using fallback: $e');
        profile = {};
      }

      final now = DateTime.now();
      final firstName = (profile['first_name'] ?? '').toString().trim();
      final lastName = (profile['last_name'] ?? '').toString().trim();
      final displayName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();
      final avatarUrl = profile['avatar_url'] as String?;

      print('👤 [sendMessage] Display name: $displayName');
      print('🖼️ [sendMessage] Avatar URL: $avatarUrl');

      final message = RoomMessage(
        id: 'msg_${now.millisecondsSinceEpoch}_${effectiveUserId.substring(0, 4)}',
        roomId: _currentRoomId!,
        userId: effectiveUserId,
        displayName: displayName.isNotEmpty ? displayName : 'مستخدم',
        content: content,
        sentAt: now,
        isSystem: false,
        avatarUrl: avatarUrl,
      );

      print('📝 [sendMessage] Created message: ${message.id}');
      print('📝 [sendMessage] Message content: ${message.content}');
      print('📝 [sendMessage] Message user ID: ${message.userId}');
      print('📝 [sendMessage] Message room ID: ${message.roomId}');
      print('📝 [sendMessage] Message timestamp: ${message.sentAt}');

      // First add the message locally for immediate feedback
      await _addMessage(
        message,
        persist: true,
        broadcast: false, // Don't broadcast yet, we'll do it after persisting
      );

      try {
        // Then persist to the database
        final response = await _supabase
            .from('rooms')
            .select('messages')
            .eq('id', _currentRoomId!)
            .single();

        List<dynamic> messages = List.from(response['messages'] ?? []);
        messages.add(message.toJson());

        await _supabase
            .from('rooms')
            .update({'messages': messages, 'updated_at': now.toIso8601String()})
            .eq('id', _currentRoomId!);

        print('✅ [sendMessage] Message persisted to database');

        // Broadcast the message to other users
        if (_currentRoomChannel != null) {
          await _currentRoomChannel!.broadcastMessage(
            event: _messageSentEvent,
            payload: message.toJson(),
          );
          print('📡 [sendMessage] Message broadcasted to channel');
        }
      } catch (e) {
        print('⚠️ [sendMessage] Error persisting message: $e');
        // Even if persistence fails, keep the message in the UI
        // but show an error to the user
        _messagesController.addError('⚠️ فشل حفظ الرسالة: $e');
        rethrow;
      }
    } catch (e) {
      print('❌ [sendMessage] Error sending message: $e');
      rethrow;
    }
  }

  // Send a rich message with emoji and images
  Future<void> sendRichMessage({
    String? content,
    String? emoji,
    List<String>? images,
    List<String>? animatedImages,
  }) async {
    try {
      print('🎨 [sendRichMessage] Starting rich message send...');
      print('   - Content: $content');
      print('   - Emoji: $emoji');
      print('   - Images: $images');
      print('   - Animated: $animatedImages');
      
      if (content == null && emoji == null && (images == null || images.isEmpty) && (animatedImages == null || animatedImages.isEmpty)) {
        print('⚠️ [sendRichMessage] No content to send');
        return;
      }

      final userId = currentUserId;
      if (_currentRoomId == null || userId == null) {
        print('❌ [sendRichMessage] No user or room ID');
        return;
      }

      print('✅ [sendRichMessage] User ID: $userId, Room ID: $_currentRoomId');

      // Get user profile for display name
      final profile = await _profileRepository.getProfile(userId);
      final now = DateTime.now();

      final firstName = (profile['first_name'] ?? '').toString().trim();
      final lastName = (profile['last_name'] ?? '').toString().trim();
      final displayName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();

      print('👤 [sendRichMessage] Display name: $displayName');
      print('🖼️ [sendRichMessage] Avatar URL: ${profile['avatar_url']}');

      final message = RoomMessage(
        id: 'msg_${now.millisecondsSinceEpoch}',
        roomId: _currentRoomId!,
        userId: userId,
        displayName: displayName.isNotEmpty ? displayName : 'مستخدم',
        content: content ?? '',
        sentAt: now,
        isSystem: false,
        avatarUrl: profile['avatar_url'] as String?,
        emoji: emoji,
        images: images,
        animatedImages: animatedImages,
      );

      print('📝 [sendRichMessage] Created message: ${message.id}');
      print('📝 [sendRichMessage] Message emoji: ${message.emoji}');

      await _addMessage(
        message,
        persist: true,
        broadcast: true,
      );
      
      print('✅ [sendRichMessage] Rich message sent successfully');
    } catch (e) {
      print('❌ [sendRichMessage] Error sending rich message: $e');
      rethrow;
    }
  }

  // Toggle ready status
  Future<void> toggleReady(bool isReady) async {
    final userId = currentUserId;
    if (_currentRoomId == null || userId == null) return;
    try {
      // Fetch latest room from DB to avoid stale state
      final latest = await _supabase
          .from('rooms')
          .select()
          .eq('id', _currentRoomId!)
          .single();
      final latestRoom = _roomFromJson(Map<String, dynamic>.from(latest));
      if (latestRoom == null) {
        throw Exception('Failed to load latest room');
      }
      final idx = latestRoom.members.indexWhere((m) => m.userId == userId);
      if (idx < 0) {
        throw Exception('Member not found in room');
      }
      final m = latestRoom.members[idx];
      final newMembers = List<RoomMember>.from(latestRoom.members);
      newMembers[idx] = RoomMember(
        userId: m.userId,
        displayName: m.displayName,
        avatarUrl: m.avatarUrl,
        isHost: m.isHost,
        isReady: isReady,
        team: m.team,
      );
      // Persist first
      await _supabase.from('rooms').update({
        'members': newMembers.map((m) => m.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', latestRoom.id);
      // Refresh from server as the single source of truth
      await _refreshRoom();
    } catch (e) {
      rethrow;
    }

    await _currentRoomChannel?.broadcastMessage(
      event: _memberUpdatedEvent,
      payload: {
        'user_id': userId,
        'is_ready': isReady,
      },
    );

    try {
      await _currentRoomChannel?.track({
        'user_id': userId,
        'is_ready': isReady,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // Start the game (host only)
  Future<void> startGame({required MatchMode mode}) async {
    try {
      final room = _currentRoom;
      if (room == null) return;

      // Only host can start the game
      if (room.hostId != currentUserId) {
        throw Exception('Only the host can start the game');
      }

      // Update room status
      final updatedRoom = room.copyWith(status: RoomStatus.inGame);
      _currentRoom = updatedRoom;
      _roomController.add(updatedRoom);

      // Save to database
      await _saveRoomToDatabase(updatedRoom);

      // Notify all clients
      await _currentRoomChannel?.broadcastMessage(
        event: _gameStartedEvent,
        payload: {
          'room_id': updatedRoom.id,
          'status': updatedRoom.status.toString(),
          'mode': mode.name,
        },
      );
    } catch (e) {
      print('Error starting game: $e');
      rethrow;
    }
  }

  // Close the room (host only)
  Future<void> closeRoom() async {
    try {
      final room = _currentRoom;
      if (room == null) return;

      // Only host can close the room
      if (room.hostId != currentUserId) {
        throw Exception('Only the host can close the room');
      }

      // Notify all clients
      await _currentRoomChannel?.broadcastMessage(
        event: _roomClosedEvent,
        payload: {'room_id': room.id},
      );

      // Clean up
      await leaveRoom();
    } catch (e) {
      print('Error closing room: $e');
      rethrow;
    }
  }

  // Private methods

  void _subscribeToRoomsChannel() {
    print('Subscribing to rooms channel...');

    _roomsChannelSubscription = _supabase.realtime.channel(_roomsChannel);

    // Handle broadcast messages (manual updates)
    _roomsChannelSubscription!
        .onBroadcast(
          event: _broadcastEvent,
          callback: (payload) {
            try {
              print('Received room broadcast: $payload');
              final data = Map<String, dynamic>.from(payload as Map);
              final room = _roomFromJson(data);
              if (room != null) {
                _roomController.add(room);
                print(
                    'Added/Updated room from broadcast: ${room.name} (${room.id})');
              }
            } catch (e) {
              print('Error handling room broadcast: $e');
            }
          },
        )
        // Handle PostgreSQL changes (automatic from database)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rooms',
          callback: (payload) {
            try {
              print('Room inserted: ${payload.newRecord}');
              final data = Map<String, dynamic>.from(payload.newRecord);
              final room = _roomFromJson(data);
              if (room != null) {
                _roomController.add(room);
                print('Added room from insert: ${room.name} (${room.id})');
              }
            } catch (e) {
              print('Error handling room insert: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rooms',
          callback: (payload) {
            try {
              print('Room updated: ${payload.newRecord}');
              final data = Map<String, dynamic>.from(payload.newRecord);
              final room = _roomFromJson(data);
              if (room != null) {
                _roomController.add(room);
                print('Updated room: ${room.name} (${room.id})');
              }
            } catch (e) {
              print('Error handling room update: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'rooms',
          callback: (payload) {
            try {
              print('Room deleted: ${payload.oldRecord}');
              // Notify that a room was removed
              _roomController.add(null);
            } catch (e) {
              print('Error handling room delete: $e');
            }
          },
        )
        .subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('Successfully subscribed to rooms channel');
      } else if (error != null) {
        print('Error subscribing to rooms channel: $error');
      }
    });
  }

  Room? _roomFromJson(Map<String, dynamic> data) {
    print('🔄 [roomFromJson] Parsing room data: $data');
    try {
      // Extract basic fields with null safety
      final id = data['id']?.toString() ?? '';
      if (id.isEmpty) {
        print('❌ [roomFromJson] Invalid room ID in data');
        return null;
      }

      final code = data['code']?.toString() ?? '';
      final name = data['name']?.toString() ?? 'غرفة جديدة';
      final hostId = data['host_id']?.toString() ?? '';

      // Parse status with fallback
      RoomStatus status;
      try {
        final statusStr = data['status']?.toString() ?? '';
        status = RoomStatus.values.firstWhere(
          (e) => e.toString() == 'RoomStatus.$statusStr',
          orElse: () => RoomStatus.waiting,
        );
      } catch (e) {
        print('⚠️ [roomFromJson] Error parsing status, defaulting to waiting');
        status = RoomStatus.waiting;
      }

      // Parse created_at with fallback
      DateTime createdAt;
      try {
        createdAt = DateTime.parse(
            data['created_at']?.toString() ?? DateTime.now().toIso8601String());
      } catch (e) {
        print('⚠️ [roomFromJson] Error parsing created_at, using current time');
        createdAt = DateTime.now();
      }

      // Parse members with robust error handling
      final members = <RoomMember>[];
      try {
        final membersData = data['members'] is List ? data['members'] : [];
        print('👥 [roomFromJson] Found ${membersData.length} members to parse');

        for (var i = 0; i < membersData.length; i++) {
          try {
            final memberData = membersData[i];
            if (memberData is Map<String, dynamic>) {
              final member = RoomMember.fromJson(memberData);
              members.add(member);
            } else if (memberData is Map) {
              final member =
                  RoomMember.fromJson(Map<String, dynamic>.from(memberData));
              members.add(member);
            } else {
              print(
                  '⚠️ [roomFromJson] Invalid member data at index $i: $memberData');
            }
          } catch (e) {
            print('⚠️ [roomFromJson] Error parsing member at index $i: $e');
          }
        }
      } catch (e) {
        print('⚠️ [roomFromJson] Error parsing members: $e');
      }

      return Room(
        id: id,
        code: code,
        name: name,
        hostId: hostId,
        status: status,
        createdAt: createdAt,
        members: members,
      );
    } catch (e) {
      print('Error parsing room data: $e');
      return null;
    }
  }

  void _handlePresenceSync(dynamic _) {
    try {
      final states =
          _currentRoomChannel?.presenceState() ?? <SinglePresenceState>[];
      final presenceMap = <String, dynamic>{};
      for (final s in states) {
        for (final presence in s.presences) {
          final payload = presence.payload;
          final uid = payload['user_id']?.toString();
          if (uid != null) presenceMap[uid] = payload;
        }
      }
      _presenceController.add(presenceMap);
    } catch (e) {
      print('Error processing presence state: $e');
    }
  }

  Future<void> _subscribeToRoomChannel(String roomId) async {
    // Unsubscribe from previous room if any
    if (_currentRoomChannel != null) {
      await _currentRoomChannel?.unsubscribe();
    }

    _currentRoomId = roomId;
    _currentRoomChannel = _supabase.realtime.channel(_roomChannel(roomId));
    final completer = Completer<void>();

    print('🔗 [Realtime] Subscribing to room channel: ${_roomChannel(roomId)}');
    print('🔗 [Realtime] Current room ID: $roomId');

    _currentRoomChannel!
        .onPresenceSync((presenceState) {
          print('👥 [Realtime] Presence sync received: $presenceState');
          _handlePresenceSync(presenceState);
        })
        .onBroadcast(
          event: _memberJoinedEvent,
          callback: (payload) async {
            print('📢 [Realtime] Member joined event received: $payload');
            await _handleMemberJoined(payload);
          },
        )
        .onBroadcast(
          event: _memberLeftEvent,
          callback: (payload) async {
            print('📢 [Realtime] Member left event received: $payload');
            print('   - Event type: $_memberLeftEvent');
            print('   - Current room: ${_currentRoom?.id}');
            print('   - Payload type: ${payload.runtimeType}');
            
            // Handle different payload formats
            dynamic actualPayload = payload;
            if (payload is Map && payload.containsKey('payload')) {
              actualPayload = payload['payload'];
              print('   - Extracted nested payload: $actualPayload');
            }
            
            await _handleMemberLeft(actualPayload);
          },
        )
        .onBroadcast(
          event: _memberUpdatedEvent,
          callback: (payload) {
            print('📢 [Realtime] Member updated event received: $payload');
            _handleMemberUpdated(payload);
          },
        )
        .onBroadcast(
          event: _messageSentEvent,
          callback: (payload) {
            print('📢 [Realtime] Message sent event received: $payload');
            _handleMessageSent(payload);
          },
        )
        .onBroadcast(
          event: _gameStartedEvent,
          callback: (payload) {
            print('📢 [Realtime] Game started event received: $payload');
            _handleGameStarted(payload);
          },
        )
        .onBroadcast(
          event: _roomClosedEvent,
          callback: (payload) {
            print('📢 [Realtime] Room closed event received: $payload');
            _handleRoomClosed(payload);
          },
        )
        .subscribe((status, error) {
          print('📡 [Realtime] Subscription status: $status');
          if (error != null) {
            print('❌ [Realtime] Subscription error: $error');
          }
          if (status == RealtimeSubscribeStatus.subscribed) {
            print('✅ [Realtime] Successfully subscribed to room channel');
            completer.complete();
          } else if (error != null) {
            print('❌ [Realtime] Failed to subscribe: $error');
            completer.completeError(error);
          }
        });

    return completer.future;
  }

  Future<void> _trackPresence(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final profile = await _profileRepository.getProfile(userId);
      final firstName = (profile['first_name'] ?? '').toString().trim();
      final lastName = (profile['last_name'] ?? '').toString().trim();
      final displayName =
          [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();

      // Check if this user is the host of the current room
      final isHost = _currentRoom != null && _currentRoom!.hostId == userId;

      // Update the current room's members list if this is the host
      if (isHost && _currentRoom != null) {
        bool hostExists = _currentRoom!.members.any((m) => m.userId == userId);
        if (!hostExists) {
          final hostMember = RoomMember(
            userId: userId,
            displayName: displayName.isNotEmpty ? displayName : 'مستخدم',
            avatarUrl: profile['avatar_url'] as String?,
            isHost: true,
            isReady: true,
          );
          _currentRoom = _currentRoom!.copyWith(
            members: [..._currentRoom!.members, hostMember],
          );
          _roomController.add(_currentRoom);
        }
      }

      await _currentRoomChannel?.track({
        'user_id': userId,
        'display_name': displayName.isNotEmpty ? displayName : 'مستخدم',
        'avatar_url': profile['avatar_url'],
        'is_host': isHost,
        'is_ready': isHost, // Host is ready by default
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Immediately update the presence list after tracking
      _handlePresenceSync(null);
    } catch (e) {
      print('Error tracking presence: $e');
    }
  }

  Future<void> _broadcastRoomUpdate(Room room) async {
    try {
      print('Broadcasting room update for room: ${room.id}');

      // First, ensure the room is saved to the database
      await _saveRoomToDatabase(room);

      // Then broadcast the update to all connected clients
      await _roomsChannelSubscription?.broadcastMessage(
        event: _broadcastEvent,
        payload: {
          'id': room.id,
          'code': room.code,
          'name': room.name,
          'host_id': room.hostId,
          'status': room.status.toString().split('.').last,
          'created_at': room.createdAt.toIso8601String(),
          'members': room.members.map((m) => m.toJson()).toList(),
        },
      );

      // Also update the room in the local state
      _roomController.add(room);

      print('Room update broadcasted successfully');
    } catch (e) {
      print('Error broadcasting room update: $e');
      // If broadcast fails, try to refresh the rooms list
      try {
        final rooms = await getPublicRooms();
        for (var r in rooms) {
          _roomController.add(r);
        }
      } catch (e) {
        print('Error refreshing rooms list: $e');
      }
    }
  }

  // Handle member joined event
  Future<void> _handleMemberJoined(dynamic payload) async {
    print('🔄 [handleMemberJoined] Processing member join event');
    try {
      if (_currentRoom == null) {
        print('⚠️ [handleMemberJoined] No current room');
        return;
      }

      final data = payload is Map ? Map<String, dynamic>.from(payload) : null;
      if (data == null) {
        print('⚠️ [handleMemberJoined] Invalid payload format');
        return;
      }

      print('👤 [handleMemberJoined] Member joined: $data');
      final uid = (data['user_id'] ?? '').toString();
      if (uid.isEmpty) {
        print('⚠️ [handleMemberJoined] Empty user ID in payload');
        return;
      }

      // Create a safe copy of members list
      final currentMembers = List<RoomMember>.from(_currentRoom!.members);

      // Check if member already exists
      final memberExists = currentMembers.any((m) => m.userId == uid);
      if (memberExists) {
        print('ℹ️ [handleMemberJoined] Member $uid already in room');
        return;
      }

      try {
        print('➕ [handleMemberJoined] Adding new member: $uid');
        final member = RoomMember(
          userId: uid,
          displayName: (data['display_name'] ?? 'مستخدم').toString(),
          avatarUrl: data['avatar_url'] as String?,
          isHost: (data['is_host'] as bool?) ?? false,
          isReady: (data['is_ready'] as bool?) ?? false,
          isSpectator: (data['is_spectator'] as bool?) ?? false,
        );

        // Create new members list and update room
        final updatedMembers = [...currentMembers, member];
        final updatedRoom = _currentRoom!.copyWith(members: updatedMembers);

        print(
            '✅ [handleMemberJoined] Added member: ${member.displayName} (${member.userId})');
        print('   - New member count: ${updatedMembers.length}');

        // Create join message
        final joinMessage = RoomMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          roomId: _currentRoom!.id,
          userId: uid,
          displayName: member.displayName,
          content: 'انضم ${member.displayName} إلى الغرفة',
          sentAt: DateTime.now(),
          isSystem: true,
          avatarUrl: member.avatarUrl,
        );

        // Add join message to chat
        await _addMessage(
          joinMessage,
          persist: true,
          broadcast: true,
        );

        // Update state
        _currentRoom = updatedRoom;
        _roomController.add(updatedRoom);

        // Persist to database
        await _saveRoomToDatabase(updatedRoom);
        print('💾 [handleMemberJoined] Room updated in database');
      } catch (e, stackTrace) {
        print('❌ [handleMemberJoined] Error processing member join: $e');
        print('Stack trace: $stackTrace');
      }
    } catch (e) {
      print('Error handling member joined: $e');
    }
  }

  // Clean up room state
  Future<void> _cleanupRoomState() async {
    print('🧹 [cleanupRoomState] Starting room state cleanup');
    
    try {
      // Store references to channel and room ID before cleanup
      final channel = _currentRoomChannel;
      final roomId = _currentRoomId;
      
      // Clear local state first to prevent any race conditions
      _currentRoom = null;
      _currentRoomId = null;
      _roomController.add(null);
      
      // Stop tracking presence if channel exists
      if (channel != null) {
        try {
          print('👋 [cleanupRoomState] Stopping presence tracking');
          await channel.untrack();
          print('✅ [cleanupRoomState] Successfully stopped presence tracking');
        } catch (e) {
          print('⚠️ [cleanupRoomState] Error stopping presence tracking: $e');
          // Continue with cleanup even if this fails
        }
        
        try {
          print('📭 [cleanupRoomState] Unsubscribing from room channel');
          await channel.unsubscribe();
          print('✅ [cleanupRoomState] Successfully unsubscribed from room channel');
        } catch (e) {
          print('⚠️ [cleanupRoomState] Error unsubscribing from channel: $e');
          // Continue with cleanup even if this fails
        }
      } else {
        print('ℹ️ [cleanupRoomState] No active channel to clean up');
      }
      
      // Clear any cached messages
      if (roomId != null) {
        _roomMessagesCache.remove(roomId);
      }
      
      print('✅ [cleanupRoomState] Room state cleanup completed');
    } catch (e, stackTrace) {
      print('❌ [cleanupRoomState] Error during cleanup: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  // Handle member left event
  Future<void> _handleMemberLeft(dynamic payload) async {
    try {
      if (_currentRoom == null) {
        print('⚠️ [handleMemberLeft] No current room');
        return;
      }
      
      final data = payload is Map ? Map<String, dynamic>.from(payload) : null;
      if (data == null) {
        print('⚠️ [handleMemberLeft] Invalid payload format');
        return;
      }
      
      final uid = (data['user_id'] ?? '').toString();
      if (uid.isEmpty) {
        print('⚠️ [handleMemberLeft] Empty user ID in payload');
        return;
      }

      print('👋 [handleMemberLeft] Member left: $data');
      
      // Get the member who left (before removing from list)
      final member = _currentRoom!.members.firstWhere(
        (m) => m.userId == uid,
        orElse: () => RoomMember(
          userId: uid,
          displayName: (data['display_name'] ?? 'مستخدم').toString(),
          avatarUrl: data['avatar_url'] as String?, // Get avatar from payload
          isHost: false,
          isReady: false,
        ),
      );

      // Create leave message with avatar info
      final leaveMessage = RoomMessage(
        id: 'sys_${DateTime.now().millisecondsSinceEpoch}_$uid',
        roomId: _currentRoom!.id,
        userId: uid,
        displayName: member.displayName,
        content: 'غادر ${member.displayName} الغرفة',
        sentAt: DateTime.now(),
        isSystem: true,
        avatarUrl: member.avatarUrl,
      );

      // Add leave message to chat FIRST (before removing member)
      print('💬 [handleMemberLeft] Adding leave message');
      await _addMessage(
        leaveMessage,
        persist: true,
        broadcast: false, // Don't broadcast - we're already in a broadcast handler
      );

      // Update local state AFTER sending the message
      final updatedMembers = _currentRoom!.members.where((m) => m.userId != uid).toList();
      if (updatedMembers.length != _currentRoom!.members.length) {
        print('🔄 [handleMemberLeft] Updating local state for user $uid');
        
        // Check if the user who left was the host
        final wasHost = _currentRoom!.hostId == uid;
        String newHostId = _currentRoom!.hostId;
        
        // If host left and there are other members, assign new host
        if (wasHost && updatedMembers.isNotEmpty) {
          newHostId = updatedMembers.first.userId;
          print('👑 [handleMemberLeft] Reassigned host to: $newHostId');
        }
        
        // Create updated room
        final updatedRoom = _currentRoom!.copyWith(
          members: updatedMembers,
          hostId: newHostId,
        );
        
        // Update local state
        _currentRoom = updatedRoom;
        _roomController.add(updatedRoom);
        
        // Update database
        print('💾 [handleMemberLeft] Updating room in database');
        try {
          await _supabase.from('rooms').update({
            'members': updatedMembers.map((m) => m.toJson()).toList(),
            'host_id': newHostId,
          }).eq('id', _currentRoom!.id);
          
          print('✅ [handleMemberLeft] Room updated in database');
        } catch (e) {
          print('❌ [handleMemberLeft] Error updating room in database: $e');
          // If update fails, try to refresh the room state
          try {
            await _refreshRoom();
          } catch (e) {
            print('❌ [handleMemberLeft] Error refreshing room state: $e');
          }
        }
      }
    } catch (e) {
      print('Error handling member left: $e');
    }
  }

  // Refresh the current room data from the database
  Future<void> _refreshRoom() async {
    if (_currentRoomId == null) return;
    
    try {
      print('🔄 [refreshRoom] Refreshing room data for room $_currentRoomId');
      
      final response = await _supabase
          .from('rooms')
          .select()
          .eq('id', _currentRoomId!)
          .single();
          
      if (response != null) {
        final room = _roomFromJson(response);
        if (room != null) {
          _currentRoom = room;
          _roomController.add(room);
          print('✅ [refreshRoom] Room data refreshed');
        } else {
          print('❌ [refreshRoom] Failed to parse room data');
        }
      } else {
        print('❌ [refreshRoom] Room not found in database');
        _currentRoom = null;
        _currentRoomId = null;
        _roomController.add(null);
      }
    } catch (e) {
      print('❌ [refreshRoom] Error refreshing room: $e');
      rethrow;
    }
  }

  // Handle member updated event
  void _handleMemberUpdated(dynamic payload) {
    try {
      if (_currentRoom == null) return;
      final data = payload is Map ? Map<String, dynamic>.from(payload) : null;
      if (data == null) return;
      final uid = (data['user_id'] ?? '').toString();
      if (uid.isEmpty) return;

      print('Member updated: $data');
      final idx = _currentRoom!.members.indexWhere((m) => m.userId == uid);
      if (idx >= 0) {
        final m = _currentRoom!.members[idx];
        final updated = RoomMember(
          userId: m.userId,
          displayName: (data['display_name'] ?? m.displayName).toString(),
          avatarUrl: (data['avatar_url'] as String?) ?? m.avatarUrl,
          isHost: (data['is_host'] as bool?) ?? m.isHost,
          isReady: (data['is_ready'] as bool?) ?? m.isReady,
        );
        final newMembers = [..._currentRoom!.members];
        newMembers[idx] = updated;
        _currentRoom = _currentRoom!.copyWith(members: newMembers);
        _roomController.add(_currentRoom);
        _saveRoomToDatabase(_currentRoom!);
      }
    } catch (e) {
      print('Error handling member updated: $e');
    }
  }

  // Handle chat message broadcast
  void _handleMessageSent(dynamic payload) {
    try {
      if (payload is Map<String, dynamic>) {
        print('🔍 [handleMessageSent] Received payload: $payload');
        final message =
            RoomMessage.fromJson(Map<String, dynamic>.from(payload));
        print('🔍 [handleMessageSent] Parsed message avatar: ${message.avatarUrl}');
        // Add the message to the local cache and broadcast full history
        unawaited(_addMessage(message));
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  void _handleGameStarted(Map<String, dynamic> payload) {
    // Update room status to inGame
    // In a real app, you'd update the room's status and notify the UI
    _currentRoom = _currentRoom!.copyWith(status: RoomStatus.inGame);
    _roomController.add(_currentRoom);
    _saveRoomToDatabase(_currentRoom!);
  }

  void _handleRoomClosed(Map<String, dynamic> payload) {
    // Handle room closure
    _roomController.add(null);
    _currentRoomId = null;
    _currentRoomChannel = null;
  }

  // Send a system message to the room
  Future<void> _sendSystemMessage(String roomId, String message, [String? avatarUrl]) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final roomMessage = RoomMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        userId: userId,
        displayName: 'النظام',
        content: message,
        sentAt: DateTime.now(),
        isSystem: true,
        avatarUrl: avatarUrl,
      );

      unawaited(_addMessage(roomMessage));
    } catch (e) {
      print('Error sending system message: $e');
    }
  }

  // Helper methods
  String _roomChannel(String roomId) {
    return roomId;
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (i) => chars[random.nextInt(chars.length)]).join();
  }

  // Clean up resources
  Future<void> dispose() async {
    try {
      // Close all stream controllers
      await _roomController.close();
      await _messagesController.close();
      await _presenceController.close();

      // Unsubscribe from channels
      await _roomsChannelSubscription?.unsubscribe();
      await _currentRoomChannel?.unsubscribe();

      // Clear references
      _roomsChannelSubscription = null;
      _currentRoomChannel = null;
      _currentRoom = null;
      _currentRoomId = null;
      _isInitialized = false;

      print('RoomsRepository disposed successfully');
    } catch (e) {
      print('Error disposing RoomsRepository: $e');
      rethrow;
    }
  }

  // Add missing methods that were causing errors
  Future<void> _broadcastRoomUpdate(Room room) async {
    try {
      await _currentRoomChannel?.broadcastMessage(
        event: 'room_updated',
        payload: room.toJson(),
      );
    } catch (e) {
      print('Error broadcasting room update: $e');
    }
  }

  // Add missing method implementation
  void _subscribeToRoomsChannel() {
    try {
      _roomsChannelSubscription = _supabase.realtime.channel('public:rooms');
      _roomsChannelSubscription?.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'rooms',
        callback: (payload) {
          try {
            final room = _roomFromJson(payload.newRecord);
            if (room != null) {
              _roomController.add(room);
            }
          } catch (e) {
            print('Error handling room insert: $e');
          }
        },
      ).subscribe();
    } catch (e) {
      print('Error subscribing to rooms channel: $e');
    }
  }
}
