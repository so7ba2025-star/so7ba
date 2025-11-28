import 'dart:async';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:so7ba/models/room_models.dart';
import 'package:supabase/supabase.dart';
import 'package:so7ba/models/match_models.dart';
import 'package:so7ba/data/profile_repository.dart';
import 'package:realtime_client/src/types.dart';

class RoomsRepository {
  static final RoomsRepository _instance = RoomsRepository._internal();
  factory RoomsRepository() => _instance;
  RoomsRepository._internal();

  final _supabase = Supabase.instance.client;
  final _profileRepository = ProfileRepository();

  String _buildDisplayName(Map<String, dynamic> profile) {
    final nickname = (profile['nickname'] ?? '').toString().trim();
    final discriminator =
        (profile['nickname_discriminator'] ?? '').toString().trim();
    if (nickname.isNotEmpty) {
      if (discriminator.length == 4) {
        return '$nickname#$discriminator';
      }
      return nickname;
    }

    final firstName = (profile['first_name'] ?? '').toString().trim();
    final lastName = (profile['last_name'] ?? '').toString().trim();
    final fallback =
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return 'مستخدم';
  }

  // Stream Controllers
  final _roomController = StreamController<Room?>.broadcast();
  final _messagesController = StreamController<List<RoomMessage>>.broadcast();
  final _presenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _buzzController = StreamController<Map<String, dynamic>>.broadcast();
  final _cheerController = StreamController<Map<String, dynamic>>.broadcast();

  // State
  Room? _currentRoom;
  String? _currentRoomId;
  RealtimeChannel? _currentRoomChannel;
  static const Duration _roomCodeRotationInterval = Duration(hours: 3);

  // Helper method to get the current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;
  RealtimeChannel? _roomsChannelSubscription;
  bool _isInitialized = false;
  final Map<String, List<RoomMessage>> _roomMessagesCache = {};

  // Getters
  bool get isInitialized => _isInitialized;
  Stream<Room?> get roomStream => _roomController.stream;
  Stream<List<RoomMessage>> get messagesStream => _messagesController.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;
  Stream<Map<String, dynamic>> get buzzStream => _buzzController.stream;
  Stream<Map<String, dynamic>> get cheerStream => _cheerController.stream;
  Room? get currentRoom => _currentRoom;
  String? get currentUserId => _supabase.auth.currentUser?.id;
  String get displayName =>
      _supabase.auth.currentUser?.userMetadata?['full_name'] ?? 'مستخدم';

  // Async method to get display name with nickname logic
  Future<String> getDisplayNameAsync() async {
    final userId = currentUserId;
    if (userId == null) return 'مستخدم';

    try {
      final profile = await _profileRepository.getProfile(userId);
      return _buildDisplayName(profile);
    } catch (e) {
      return displayName; // Fallback to old logic
    }
  }

  // Initialize the repository
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    _subscribeToRoomsChannel();
  }

  // Room Management
  Future<Room> createRoom({
    required String name,
    RoomPrivacyType privacyType = RoomPrivacyType.public,
    RoomJoinMode? joinMode,
    bool discoverable = true,
    String? description,
    RoomLogoSource logoSource = RoomLogoSource.preset,
    String? logoAssetKey,
    String? logoUrl,
    int? maxMembers,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      final profile = await _profileRepository.getProfile(userId);
      final displayName = _buildDisplayName(profile);
      final avatarUrl = profile['avatar_url'];

      final resolvedJoinMode = joinMode ??
          (privacyType == RoomPrivacyType.public
              ? RoomJoinMode.instant
              : RoomJoinMode.approval);

      // Ensure we always have a code (even if not required) for sharing/invitations.
      final roomCode = _generateRoomCode();
      final now = DateTime.now();

      final room = Room(
        id: 'room_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        code: roomCode,
        hostId: userId,
        status: RoomStatus.waiting,
        privacyType: privacyType,
        joinMode: resolvedJoinMode,
        discoverable: discoverable,
        description: description,
        logoSource: logoSource,
        logoAssetKey: logoSource == RoomLogoSource.preset ? logoAssetKey : null,
        logoUrl: logoSource == RoomLogoSource.upload ? logoUrl : null,
        maxMembers: maxMembers,
        createdAt: now,
        updatedAt: now,
        members: [
          RoomMember(
            userId: userId,
            displayName: displayName,
            avatarUrl: avatarUrl,
            isHost: true,
            isReady: false,
          ),
        ],
        metadata: {
          'code_rotated_at': now.toIso8601String(),
        },
        codeRotatedAt: now,
      );

      await _saveRoomToDatabase(room);
      _currentRoom = room;
      _currentRoomId = room.id;
      _roomController.add(room);

      await _subscribeToRoomChannel(room.id);
      await _trackPresence(room.id);

      return room;
    } catch (e) {
      print('خطأ في إنشاء الغرفة: $e');
      rethrow;
    }
  }

  Future<Room> ensureJoinedRoom(Room room) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('المستخدم غير مسجل الدخول');
    }

    final alreadyMember = room.members.any((member) => member.userId == userId);
    if (alreadyMember) {
      return room;
    }

    return joinRoom(room.id, code: room.code);
  }

  Future<Room> joinRoom(String roomId, {String? code}) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      final profile = await _profileRepository.getProfile(userId);
      final displayName = _buildDisplayName(profile);
      final avatarUrl = profile['avatar_url'];

      // Get room data
      final response =
          await _supabase.from('rooms').select('*').eq('id', roomId).single();

      if (response == null) throw Exception('الغرفة غير موجودة');

      print('Room data: $response');

      // Get existing members
      final membersResponse = await _supabase
          .from('room_members')
          .select('*')
          .eq('room_id', roomId);

      final members = <RoomMember>[];
      for (var memberData in membersResponse) {
        Team? team;
        if (memberData['team'] != null) {
          team = Team.values.firstWhere(
            (t) => t.toString() == 'Team.${memberData['team']}',
            orElse: () => Team.a,
          );
        }

        members.add(RoomMember(
          userId: memberData['user_id'] as String,
          displayName: memberData['display_name'] as String? ?? 'لاعب',
          avatarUrl: memberData['avatar_url'] as String?,
          isHost: memberData['is_host'] as bool? ?? false,
          isReady: memberData['is_ready'] as bool? ?? false,
          isSpectator: memberData['is_spectator'] as bool? ?? false,
          team: team,
        ));
      }

      // Get messages from room_messages table
      final messagesResponse = await _supabase
          .from('room_messages')
          .select('*')
          .eq('room_id', roomId)
          .order('sent_at', ascending: true);

      final messages = <RoomMessage>[];
      if (messagesResponse != null) {
        for (var messageData in messagesResponse) {
          try {
            messages.add(RoomMessage.fromJson(messageData));
          } catch (e) {
            print('Error parsing message: $e');
          }
        }
      }

      final baseRoom = _roomFromDatabaseRow(
        Map<String, dynamic>.from(response as Map),
        members: members,
        messages: messages,
      );

      if (baseRoom.requiresJoinCode) {
        if (code == null || code.trim().isEmpty) {
          throw Exception('هذه الغرفة تتطلب كود انضمام');
        }
        final normalizedProvidedCode = code.trim().toUpperCase();
        final normalizedRoomCode = baseRoom.code.trim().toUpperCase();
        if (normalizedProvidedCode != normalizedRoomCode) {
          throw Exception('كود الغرفة غير صحيح');
        }
      }

      // Check if user is already a member
      if (members.any((m) => m.userId == userId)) {
        final room = baseRoom;
        // Cache messages
        _roomMessagesCache[roomId] = messages;

        return room;
      }

      // Add user as new member
      final newMember = RoomMember(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        isHost: false,
        isReady: false,
      );

      final updatedMembers = [...members, newMember];

      // Save new member to room_members table
      await _supabase.from('room_members').insert({
        'room_id': roomId,
        'user_id': userId,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'is_host': false,
        'is_ready': false,
        'is_spectator': false,
      });

      final updatedRoom = baseRoom.copyWith(
        members: updatedMembers,
        messages: messages,
        updatedAt: DateTime.now(),
      );

      _currentRoom = updatedRoom;
      _currentRoomId = roomId;

      // Cache messages
      _roomMessagesCache[roomId] = messages;

      await _subscribeToRoomChannel(roomId);
      await _trackPresence(roomId);

      await _sendSystemMessage(
          roomId, 'انضم $displayName إلى الغرفة', avatarUrl);

      return updatedRoom;
    } catch (e) {
      print('خطأ في الانضمام إلى الغرفة: $e');
      rethrow;
    }
  }

  Future<Room> joinAsSpectator(String roomId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      final profile = await _profileRepository.getProfile(userId);
      final displayName = _buildDisplayName(profile);
      final avatarUrl = profile['avatar_url'];

      // Get room data
      final response =
          await _supabase.from('rooms').select().eq('id', roomId).single();

      if (response == null) throw Exception('الغرفة غير موجودة');

      final room = _roomFromJson(response);

      // Add user as spectator
      final spectator = RoomMember(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        isHost: false,
        isReady: false,
        isSpectator: true,
      );

      final updatedMembers = [...room.members, spectator];
      final updatedRoom = room.copyWith(members: updatedMembers);

      await _saveRoomToDatabase(updatedRoom);
      _currentRoom = updatedRoom;
      _currentRoomId = roomId;

      await _subscribeToRoomChannel(roomId);
      await _trackPresence(roomId);

      await _sendSystemMessage(roomId, 'انضم $displayName كمشاهد', avatarUrl);

      return updatedRoom;
    } catch (e) {
      print('خطأ في الانضمام كمشاهد: $e');
      rethrow;
    }
  }

  Future<void> toggleReady([bool? isReady]) async {
    try {
      if (_currentRoom == null || _currentRoomId == null) return;

      final userId = currentUserId;
      if (userId == null) return;

      final memberIndex =
          _currentRoom!.members.indexWhere((m) => m.userId == userId);
      if (memberIndex == -1) return;

      final updatedMembers = List<RoomMember>.from(_currentRoom!.members);
      final currentMember = updatedMembers[memberIndex];
      final desiredReadyState = isReady ?? !currentMember.isReady;
      updatedMembers[memberIndex] =
          currentMember.copyWith(isReady: desiredReadyState);

      _currentRoom = _currentRoom!.copyWith(members: updatedMembers);
      _roomController.add(_currentRoom);

      await _saveRoomToDatabase(_currentRoom!);

      await _broadcastRoomUpdate(_currentRoom!);

      await _sendReadyStatusMessage(currentMember, desiredReadyState);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> startGame({required String mode}) async {
    if (_currentRoom == null) return;

    _currentRoom = _currentRoom!.copyWith(
      status: RoomStatus.inGame,
    );

    _roomController.add(_currentRoom!);
    await _saveRoomToDatabase(_currentRoom!);
    await _broadcastRoomUpdate(_currentRoom!);
    await _sendSystemMessage(_currentRoom!.id, 'بدأت اللعبة!');
  }

  Future<void> closeRoom() async {
    if (_currentRoom == null) return;

    final roomId = _currentRoomId;
    await _cleanupRoomState();

    if (roomId != null) {
      await _supabase.from('rooms').delete().eq('id', roomId);
      await _sendSystemMessage(roomId, 'تم إغلاق الغرفة');
    }
  }

  Future<void> leaveRoom() async {
    try {
      if (_currentRoom == null || _currentRoomId == null) return;

      final userId = currentUserId;
      if (userId == null) return;

      final leavingMember = _currentRoom!.members.firstWhere(
        (member) => member.userId == userId,
        orElse: () => RoomMember(
          userId: userId,
          displayName: 'مستخدم',
          isHost: false,
          isReady: false,
        ),
      );
      final wasHost = leavingMember.isHost;

      // Remove user from members
      final updatedMembers = _currentRoom!.members
          .where((member) => member.userId != userId)
          .toList();

      // Remove membership row from database to keep room_members in sync
      await _supabase.from('room_members').delete().match({
        'room_id': _currentRoomId!,
        'user_id': userId,
      });

      if (updatedMembers.isEmpty) {
        // Delete room only if the host is leaving and no one else remains
        if (wasHost) {
          await _supabase.from('rooms').delete().eq('id', _currentRoomId!);
        }
      } else if (wasHost) {
        // Transfer host role to the next member when the host leaves
        final newHost = updatedMembers.first;
        final reassignedMembers = <RoomMember>[
          newHost.copyWith(isHost: true),
          ...updatedMembers.skip(1).map((m) => m.copyWith(isHost: false)),
        ];

        final updatedRoom = _currentRoom!.copyWith(
          members: reassignedMembers,
          hostId: newHost.userId,
        );

        await _saveRoomToDatabase(updatedRoom);
      } else {
        // Non-hosts don't need to update the room record (RLS-restricted)
        _currentRoom = _currentRoom!.copyWith(members: updatedMembers);
      }

      // Send leave notification
      await _sendSystemMessage(
        _currentRoomId!,
        'غادر ${leavingMember.displayName} الغرفة',
        leavingMember.avatarUrl,
      );

      // Clean up local state
      await _cleanupRoomState();
    } catch (e) {
      print('خطأ في مغادرة الغرفة: $e');
      rethrow;
    }
  }

  Future<List<Room>> getPublicRooms() async {
    try {
      print('Fetching public rooms...');

      // Get rooms in waiting status, filter in Dart to support legacy data
      final roomsResponseRaw = await _supabase
          .from('rooms')
          .select('*')
          .eq('status', 'waiting')
          .order('created_at', ascending: false);

      final roomsResponse =
          (roomsResponseRaw as List<dynamic>? ?? const []).cast<dynamic>();

      if (roomsResponse.isEmpty) {
        print('No rooms found');
        return [];
      }

      // Convert to Room objects and fetch members for each room
      final rooms = <Room>[];
      final userId = currentUserId;
      for (var roomData in roomsResponse) {
        try {
          var roomMap = Map<String, dynamic>.from(roomData as Map);
          roomMap = await _ensureFreshRoomCode(roomMap);
          final roomId = roomMap['id']?.toString();
          if (roomId == null) {
            continue;
          }
          // Fetch members for this room
          final membersResponseRaw = await _supabase
              .from('room_members')
              .select('*')
              .eq('room_id', roomId);

          final membersResponse =
              (membersResponseRaw as List<dynamic>? ?? const [])
                  .cast<dynamic>();

          final members = <RoomMember>[];
          for (final rawMember in membersResponse) {
            final memberData = Map<String, dynamic>.from(rawMember as Map);
            Team? team;
            if (memberData['team'] != null) {
              team = Team.values.firstWhere(
                (t) => t.toString() == 'Team.${memberData['team']}',
                orElse: () => Team.a,
              );
            }

            members.add(RoomMember(
              userId: memberData['user_id'] as String,
              displayName: memberData['display_name'] as String? ?? 'لاعب',
              avatarUrl: memberData['avatar_url'] as String?,
              isHost: memberData['is_host'] as bool? ?? false,
              isReady: memberData['is_ready'] as bool? ?? false,
              isSpectator: memberData['is_spectator'] as bool? ?? false,
              team: team,
            ));
          }

          // Create room with members
          final room = _roomFromDatabaseRow(
            roomMap,
            members: members,
          );

          final isMember = userId != null &&
              members.any((member) => member.userId == userId);

          if (!isMember && (!room.isPublic || !room.discoverable)) {
            continue;
          }

          rooms.add(room);
        } catch (e) {
          print('Error processing room entry: $e');
        }
      }

      print('Fetched ${rooms.length} public rooms');
      return rooms;
    } catch (e) {
      print('خطأ في جلب الغرف العامة: $e');
      return [];
    }
  }

  // Get rooms where current user is a member
  Future<List<Room>> getUserRooms() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        print('User not logged in');
        return [];
      }

      print('Fetching user rooms for user: $userId');

      // Simple approach: get all rooms and filter in Dart
      final allRoomsResponseRaw = await _supabase
          .from('rooms')
          .select('*')
          .order('updated_at', ascending: false);

      final allRoomsResponse =
          (allRoomsResponseRaw as List<dynamic>? ?? const []).cast<dynamic>();

      final rooms = <Room>[];
      for (var roomData in allRoomsResponse) {
        try {
          var roomMap = Map<String, dynamic>.from(roomData as Map);
          roomMap = await _ensureFreshRoomCode(roomMap);
          final roomId = roomMap['id']?.toString();
          if (roomId == null) {
            continue;
          }

          // Check if user is a member of this room
          final membershipCheck = await _supabase
              .from('room_members')
              .select('*')
              .eq('room_id', roomId)
              .eq('user_id', userId)
              .maybeSingle();

          if (membershipCheck == null) {
            continue; // User is not a member
          }

          // Fetch all members for this room
          final membersResponseRaw = await _supabase
              .from('room_members')
              .select('*')
              .eq('room_id', roomId);

          final membersResponse =
              (membersResponseRaw as List<dynamic>? ?? const [])
                  .cast<dynamic>();

          final members = <RoomMember>[];
          for (final rawMember in membersResponse) {
            final memberData = Map<String, dynamic>.from(rawMember as Map);
            Team? team;
            if (memberData['team'] != null) {
              team = Team.values.firstWhere(
                (t) => t.toString() == 'Team.${memberData['team']}',
                orElse: () => Team.a,
              );
            }

            members.add(RoomMember(
              userId: memberData['user_id'] as String,
              displayName: memberData['display_name'] as String? ?? 'لاعب',
              avatarUrl: memberData['avatar_url'] as String?,
              isHost: memberData['is_host'] as bool? ?? false,
              isReady: memberData['is_ready'] as bool? ?? false,
              isSpectator: memberData['is_spectator'] as bool? ?? false,
              team: team,
            ));
          }

          // Create room with members
          final room = _roomFromDatabaseRow(
            roomMap,
            members: members,
          );

          rooms.add(room);
        } catch (e) {
          print('Error processing room entry: $e');
        }
      }

      print('Fetched ${rooms.length} user rooms');
      return rooms;
    } catch (e) {
      print('خطأ في جلب غرف المستخدم: $e');
      return [];
    }
  }

  Future<void> enterRoom(Room room) async {
    try {
      _currentRoom = room;
      _currentRoomId = room.id;
      _roomController.add(room);

      // Subscribe to room channel
      await _subscribeToRoomChannel(room.id);

      // Only track presence if user is not already tracked
      final userId = currentUserId;
      final isAlreadyMember = room.members.any((m) => m.userId == userId);

      if (isAlreadyMember) {
        print('User is already a member of this room');
        // Still try to track presence but handle errors gracefully
        try {
          await _trackPresence(room.id);
        } catch (e) {
          print('Warning: Could not track presence for existing member: $e');
          // Don't rethrow - user is already in the room
        }
      } else {
        await _trackPresence(room.id);
      }

      // Load previous messages if needed
      if (_roomMessagesCache[room.id] == null) {
        await syncMessages(room.id);
      }
    } catch (e) {
      print('خطأ في الدخول إلى الغرفة: $e');
      rethrow;
    }
  }

  Future<Room?> getRoomById(String roomId,
      {bool includeMessages = true}) async {
    try {
      final roomResponse = await _supabase
          .from('rooms')
          .select('*')
          .eq('id', roomId)
          .maybeSingle();

      if (roomResponse == null) {
        developer.log('Room not found while fetching by id',
            name: 'RoomsRepository', error: {'roomId': roomId});
        return null;
      }

      var roomMap = Map<String, dynamic>.from(roomResponse as Map);
      roomMap = await _ensureFreshRoomCode(roomMap);

      final membersResponseRaw = await _supabase
          .from('room_members')
          .select('*')
          .eq('room_id', roomId);

      final membersResponse =
          (membersResponseRaw as List<dynamic>? ?? const []).cast<dynamic>();

      final members = <RoomMember>[];
      for (final rawMember in membersResponse) {
        final memberData = Map<String, dynamic>.from(rawMember as Map);
        Team? team;
        final teamValue = memberData['team'] as String?;
        if (teamValue != null && teamValue.isNotEmpty) {
          team = Team.values.firstWhere(
            (t) => t.toString() == 'Team.$teamValue',
            orElse: () => Team.a,
          );
        }

        members.add(RoomMember(
          userId: memberData['user_id'] as String,
          displayName: memberData['display_name'] as String? ?? 'لاعب',
          avatarUrl: memberData['avatar_url'] as String?,
          isHost: memberData['is_host'] as bool? ?? false,
          isReady: memberData['is_ready'] as bool? ?? false,
          isSpectator: memberData['is_spectator'] as bool? ?? false,
          team: team,
        ));
      }

      final messages = <RoomMessage>[];
      if (includeMessages) {
        final messagesResponseRaw = await _supabase
            .from('room_messages')
            .select('*')
            .eq('room_id', roomId)
            .order('sent_at', ascending: true);

        final messagesResponse =
            (messagesResponseRaw as List<dynamic>? ?? const []).cast<dynamic>();

        if (messagesResponse.isNotEmpty) {
          for (final rawMessage in messagesResponse) {
            try {
              final messageData = Map<String, dynamic>.from(rawMessage as Map);
              messages.add(RoomMessage.fromJson(messageData));
            } catch (e, stackTrace) {
              developer.log('Error parsing message while fetching room',
                  name: 'RoomsRepository', error: e, stackTrace: stackTrace);
            }
          }
        }
      }

      final createdAtRaw = roomResponse['created_at'];
      DateTime createdAt;
      if (createdAtRaw is String) {
        createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
      } else if (createdAtRaw is DateTime) {
        createdAt = createdAtRaw;
      } else {
        createdAt = DateTime.now();
      }

      final room = _roomFromDatabaseRow(
        roomMap,
        members: members,
        messages: includeMessages ? messages : [],
        createdAtOverride: createdAt,
      );

      if (includeMessages) {
        _roomMessagesCache[roomId] = messages;
        _messagesController.add(messages);
      }

      return room;
    } catch (e, stackTrace) {
      developer.log('Failed to fetch room by id',
          name: 'RoomsRepository', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<Room?> getRoomByCode(String code) async {
    try {
      final trimmedCode = code.trim();
      if (trimmedCode.isEmpty) {
        return null;
      }
      final normalizedCode = trimmedCode.toUpperCase();

      final roomResponse = await _supabase
          .from('rooms')
          .select('*')
          .eq('code', normalizedCode)
          .maybeSingle();

      if (roomResponse == null) {
        return null;
      }

      var roomMap = Map<String, dynamic>.from(roomResponse as Map);
      roomMap = await _ensureFreshRoomCode(roomMap);
      final roomId = roomMap['id']?.toString();
      if (roomId == null) {
        return null;
      }

      final membersResponseRaw = await _supabase
          .from('room_members')
          .select('*')
          .eq('room_id', roomId);

      final membersResponse =
          (membersResponseRaw as List<dynamic>? ?? const []).cast<dynamic>();

      final members = <RoomMember>[];
      for (final rawMember in membersResponse) {
        final memberData = Map<String, dynamic>.from(rawMember as Map);
        Team? team;
        final teamValue = memberData['team'] as String?;
        if (teamValue != null && teamValue.isNotEmpty) {
          team = Team.values.firstWhere(
            (t) => t.toString() == 'Team.$teamValue',
            orElse: () => Team.a,
          );
        }

        members.add(RoomMember(
          userId: memberData['user_id'] as String,
          displayName: memberData['display_name'] as String? ?? 'لاعب',
          avatarUrl: memberData['avatar_url'] as String?,
          isHost: memberData['is_host'] as bool? ?? false,
          isReady: memberData['is_ready'] as bool? ?? false,
          isSpectator: memberData['is_spectator'] as bool? ?? false,
          team: team,
        ));
      }

      return _roomFromDatabaseRow(
        roomMap,
        members: members,
      );
    } catch (e, stackTrace) {
      developer.log('Failed to fetch room by code',
          name: 'RoomsRepository', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  // Get messages directly from cache
  List<RoomMessage>? getRoomMessages(String roomId) {
    return _roomMessagesCache[roomId];
  }

  Future<void> syncMessages(String roomId) async {
    try {
      final allMessages = <RoomMessage>[];

      // 1. Load old messages from rooms.messages (JSONB)
      try {
        final roomResponse = await _supabase
            .from('rooms')
            .select('messages')
            .eq('id', roomId)
            .single();

        if (roomResponse != null && roomResponse['messages'] != null) {
          final oldMessages = (roomResponse['messages'] as List)
              .map((m) => RoomMessage.fromJson(m as Map<String, dynamic>))
              .toList();
          allMessages.addAll(oldMessages);
        }
      } catch (e) {
        // Error loading old messages - continue with new messages
      }

      // 2. Load new messages from room_messages table
      try {
        final newMessagesResponse = await _supabase
            .from('room_messages')
            .select('*')
            .eq('room_id', roomId)
            .order('sent_at', ascending: true);

        if (newMessagesResponse != null && newMessagesResponse.isNotEmpty) {
          final newMessages = <RoomMessage>[];
          for (int i = 0; i < newMessagesResponse.length; i++) {
            try {
              final messageData =
                  newMessagesResponse[i] as Map<String, dynamic>;
              final message = RoomMessage.fromJson(messageData);

              // Only add if not already in the list (avoid duplicates)
              if (!allMessages.any((m) => m.id == message.id)) {
                newMessages.add(message);
              }
            } catch (e) {
              // Error parsing message - skip it
            }
          }
          allMessages.addAll(newMessages);
        }
      } catch (e) {
        // Error loading new messages - continue with what we have
      }

      // Sort all messages by sent_at using milliseconds for consistent comparison
      allMessages.sort((a, b) {
        final aTime = a.sentAt.millisecondsSinceEpoch;
        final bTime = b.sentAt.millisecondsSinceEpoch;
        int comparison = aTime.compareTo(bTime);
        if (comparison == 0) {
          // If same time, sort by ID to maintain consistent order
          return a.id.compareTo(b.id);
        }
        return comparison;
      });

      // Update cache and controller
      _roomMessagesCache[roomId] = allMessages;
      _messagesController.add(allMessages);
    } catch (e) {
      // Error syncing messages
    }
  }

  Future<void> sendMessage(String roomId, String content) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      final profile = await _profileRepository.getProfile(userId);
      final displayName = _buildDisplayName(profile);
      final avatarUrl = profile['avatar_url'];

      // تحديد ما إذا كانت رسالة نظام (مثل البوسة)
      final isSystemMessage = content == '💋' || content == '👏';

      final message = RoomMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        userId: userId,
        displayName: displayName,
        content: content,
        sentAt: DateTime.now(),
        isSystem: isSystemMessage,
        avatarUrl: avatarUrl,
        emoji: isSystemMessage ? content : null,
      );

      await _addMessage(message, persist: true, broadcast: true);
    } catch (e) {
      print('خطأ في إرسال الرسالة: $e');
      rethrow;
    }
  }

  Future<void> sendAudioMessage({
    required String roomId,
    required String audioUrl,
    required int audioDurationMs,
    String? transcription,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      final profile = await _profileRepository.getProfile(userId);
      final displayName = _buildDisplayName(profile);
      final avatarUrl = profile['avatar_url'];

      final fallbackContent = transcription?.trim().isNotEmpty == true
          ? transcription!.trim()
          : 'رسالة صوتية 🎙️';

      final message = RoomMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        userId: userId,
        displayName: displayName,
        content: fallbackContent,
        sentAt: DateTime.now(),
        isSystem: false,
        avatarUrl: avatarUrl,
        audioUrl: audioUrl,
        audioDurationMs: audioDurationMs,
      );

      await _addMessage(message, persist: true, broadcast: true);
    } catch (e) {
      print('خطأ في إرسال الرسالة الصوتية: $e');
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      // Delete from database
      await _supabase.from('room_messages').delete().eq('id', messageId);

      // Remove from cache
      if (_currentRoomId != null &&
          _roomMessagesCache[_currentRoomId] != null) {
        _roomMessagesCache[_currentRoomId]!
            .removeWhere((msg) => msg.id == messageId);
        _messagesController.add(_roomMessagesCache[_currentRoomId]!);
      }

      // Broadcast deletion
      if (_currentRoomChannel != null) {
        await _broadcastToChannel(
          channel: _currentRoomChannel!,
          event: 'message_deleted',
          payload: {
            'message_id': messageId,
          },
        );
      }
    } catch (e) {
      print('خطأ في حذف الرسالة: $e');
      rethrow;
    }
  }

  Future<void> toggleMessageReaction(String messageId, String emoji) async {
    final normalizedEmoji = emoji.trim();
    if (normalizedEmoji.isEmpty) {
      return;
    }

    final userId = currentUserId;
    if (userId == null) {
      throw Exception('المستخدم غير مسجل الدخول');
    }

    final roomId = _currentRoomId ?? _currentRoom?.id;
    if (roomId == null) {
      throw Exception('لا توجد غرفة نشطة');
    }

    final cachedMessages = _roomMessagesCache[roomId];
    if (cachedMessages == null) {
      throw Exception('لا توجد رسائل محملة');
    }

    final messageIndex = cachedMessages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) {
      throw Exception('الرسالة غير موجودة');
    }

    final previousMessages = List<RoomMessage>.from(cachedMessages);
    final targetMessage = cachedMessages[messageIndex];

    final mutableReactions = <String, List<String>>{};
    targetMessage.reactions.forEach((key, value) {
      mutableReactions[key] = List<String>.from(value);
    });

    final userList = mutableReactions[normalizedEmoji] ?? <String>[];
    if (userList.contains(userId)) {
      userList.removeWhere((id) => id == userId);
      if (userList.isEmpty) {
        mutableReactions.remove(normalizedEmoji);
      } else {
        mutableReactions[normalizedEmoji] = userList;
      }
    } else {
      userList.add(userId);
      mutableReactions[normalizedEmoji] = userList;
    }

    final normalizedReactions =
        RoomMessage.normalizeReactions(mutableReactions);
    final updatedMessage =
        targetMessage.copyWith(reactions: normalizedReactions);
    final updatedMessages = List<RoomMessage>.from(cachedMessages);
    updatedMessages[messageIndex] = updatedMessage;

    _roomMessagesCache[roomId] = updatedMessages;
    _messagesController.add(updatedMessages);

    try {
      final encodedReactions = _encodeReactions(normalizedReactions);
      await _supabase
          .from('room_messages')
          .update({'reactions': encodedReactions}).eq('id', messageId);

      if (_currentRoomChannel != null) {
        await _broadcastToChannel(
          channel: _currentRoomChannel!,
          event: 'reaction_updated',
          payload: {
            'message_id': messageId,
            'room_id': roomId,
            'reactions': encodedReactions,
          },
        );
      }
    } catch (e) {
      _roomMessagesCache[roomId] = previousMessages;
      _messagesController.add(previousMessages);
      rethrow;
    }
  }

  Future<void> sendRichMessage({
    required String roomId,
    required String content,
    List<String>? images,
    List<String>? animatedImages,
    String? emoji,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      final profile = await _profileRepository.getProfile(userId);
      final displayName = _buildDisplayName(profile);
      final avatarUrl = profile['avatar_url'];

      final message = RoomMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        userId: userId,
        displayName: displayName,
        content: content,
        sentAt: DateTime.now(),
        isSystem: false,
        avatarUrl: avatarUrl,
        emoji: emoji,
        images: images,
        animatedImages: animatedImages,
      );

      await _addMessage(message, persist: true, broadcast: true);
    } catch (e) {
      print('خطأ في إرسال الرسالة الغنية: $e');
      rethrow;
    }
  }

  Future<void> sendBuzz(String roomId) async {
    try {
      print('🔵 ===== بدء إرسال البوز =====');
      final userId = currentUserId;
      if (userId == null) {
        final error = 'المستخدم غير مسجل الدخول';
        print('❌ $error');
        throw Exception(error);
      }

      print('🔵 جلب بيانات المستخدم...');
      final profile = await _profileRepository.getProfile(userId);
      final displayName = _buildDisplayName(profile);
      print('🔵 اسم المستخدم: $displayName');

      // إرسال Buzz عبر الـ broadcast مباشرة بدون حفظ في قاعدة البيانات
      if (_currentRoomChannel == null) {
        final error = 'قناة الغرفة غير متصلة. تأكد من أنك داخل الغرفة.';
        print('❌ $error');
        throw Exception(error);
      }

      print('🔵 إعداد بيانات البوز...');
      final buzzPayload = {
        'user_id': userId,
        'display_name': displayName,
        'room_id': roomId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('🔵 إرسال البوز عبر القناة: ${_currentRoomChannel!.topic}');
      print('🔵 بيانات البوز: $buzzPayload');

      await _broadcastToChannel(
        channel: _currentRoomChannel!,
        event: 'buzz',
        payload: buzzPayload,
      );

      print('✅ تم إرسال البوز بنجاح من $displayName');
    } catch (e) {
      print('❌ خطأ في إرسال Buzz: $e');
      rethrow;
    }
  }

  Future<void> sendCheer(String roomId) async {
    try {
      print('🎵 ===== بدء إرسال التصفيق (Cheer) =====');
      final userId = currentUserId;
      if (userId == null) {
        final error = 'المستخدم غير مسجل الدخول';
        print('❌ $error');
        throw Exception(error);
      }

      print('🎵 جلب بيانات المستخدم للتصفيق...');
      final profile = await _profileRepository.getProfile(userId);
      final displayName = _buildDisplayName(profile);
      print('🎵 اسم المستخدم: $displayName');

      if (_currentRoomChannel == null) {
        final error = 'قناة الغرفة غير متصلة. تأكد من أنك داخل الغرفة.';
        print('❌ $error');
        throw Exception(error);
      }

      print('🎵 إعداد بيانات التصفيق...');
      final cheerPayload = {
        'user_id': userId,
        'display_name': displayName,
        'room_id': roomId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('🎵 إرسال التصفيق عبر القناة: ${_currentRoomChannel!.topic}');
      print('🎵 بيانات التصفيق: $cheerPayload');

      await _broadcastToChannel(
        channel: _currentRoomChannel!,
        event: 'cheer',
        payload: cheerPayload,
      );

      print('✅ تم إرسال التصفيق بنجاح من $displayName');
    } catch (e) {
      print('❌ خطأ في إرسال التصفيق (Cheer): $e');
      rethrow;
    }
  }

  // Private Methods
  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (i) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _subscribeToRoomChannel(String roomId) async {
    try {
      await _currentRoomChannel?.unsubscribe();
      _currentRoomChannel = _supabase.realtime.channel('room_$roomId');

      // Handle member joined
      _currentRoomChannel?.onBroadcast(
        event: 'member_joined',
        callback: _handleMemberJoined,
      );

      // Handle member left
      _currentRoomChannel?.onBroadcast(
        event: 'member_left',
        callback: _handleMemberLeft,
      );

      // Handle member updated
      _currentRoomChannel?.onBroadcast(
        event: 'member_updated',
        callback: _handleMemberUpdated,
      );

      // Handle message sent
      _currentRoomChannel?.onBroadcast(
        event: 'message_sent',
        callback: _handleMessageSent,
      );

      _currentRoomChannel?.onBroadcast(
        event: 'reaction_updated',
        callback: _handleReactionUpdated,
      );

      // Handle buzz
      _currentRoomChannel?.onBroadcast(
        event: 'buzz',
        callback: _handleBuzz,
      );

      // Handle cheer (تصفيق)
      _currentRoomChannel?.onBroadcast(
        event: 'cheer',
        callback: _handleCheer,
      );

      // Handle game started
      _currentRoomChannel?.onBroadcast(
        event: 'game_started',
        callback: _handleGameStarted,
      );

      // Handle room closed
      _currentRoomChannel?.onBroadcast(
        event: 'room_closed',
        callback: _handleRoomClosed,
      );

      await _currentRoomChannel?.subscribe();
    } catch (e) {
      print('خطأ في الاشتراك بقناة الغرفة: $e');
      rethrow;
    }
  }

  Future<void> _subscribeToRoomsChannel() async {
    try {
      _roomsChannelSubscription = _supabase.channel('rooms_list');

      _roomsChannelSubscription!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'rooms',
            callback: (payload) => _handleRoomCreated(payload.newRecord),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'rooms',
            callback: (payload) => _handleRoomUpdated(payload.newRecord),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'rooms',
            callback: (payload) => _handleRoomDeleted(payload.oldRecord),
          )
          .subscribe();
    } catch (e) {
      print('خطأ في الاشتراك في قناة الغرف: $e');
      rethrow;
    }
  }

  // Room event handlers
  void _handleRoomCreated(Map<String, dynamic> roomData) {
    try {
      final room = Room.fromJson(roomData);
      // Handle room created event
      print('Room created: ${room.id}');
    } catch (e) {
      print('Error handling room created: $e');
    }
  }

  void _handleRoomUpdated(Map<String, dynamic> roomData) {
    try {
      var room = Room.fromJson(roomData);

      // The real-time payload from Postgres doesn't include members/messages.
      // Preserve the existing lists so the UI doesn't lose players or chat history.
      if (_currentRoom != null && _currentRoom!.id == room.id) {
        if (room.members.isEmpty && _currentRoom!.members.isNotEmpty) {
          room = room.copyWith(members: _currentRoom!.members);
        }
        if (room.messages.isEmpty && _currentRoom!.messages.isNotEmpty) {
          room = room.copyWith(messages: _currentRoom!.messages);
        }

        _currentRoom = room;
        _roomController.add(room);
      }
    } catch (e) {
      print('Error handling room updated: $e');
    }
  }

  void _handleRoomDeleted(Map<String, dynamic> roomData) {
    try {
      final room = Room.fromJson(roomData);
      // Handle room deleted event
      if (_currentRoom?.id == room.id) {
        _currentRoom = null;
        _roomController.add(null);
      }
    } catch (e) {
      print('Error handling room deleted: $e');
    }
  }

  Future<void> _trackPresence(String roomId) async {
    try {
      final presenceChannel =
          _supabase.realtime.channel('room_presence_$roomId');

      // Fixed: Use onPresenceSync instead of onPresence
      presenceChannel.onPresenceSync((state) {
        _presenceController.add({
          'state': state,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });

      // Subscribe first, then track presence
      await presenceChannel.subscribe();

      await presenceChannel.track({
        'user_id': _supabase.auth.currentUser?.id,
        'user_name': _supabase.auth.currentUser?.userMetadata?['full_name'],
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('خطأ في تتبع الحضور: $e');
      rethrow;
    }
  }

  Future<RoomMessage> _addMessage(
    RoomMessage message, {
    bool persist = true,
    bool broadcast = true,
  }) async {
    try {
      if (_roomMessagesCache[message.roomId] == null) {
        _roomMessagesCache[message.roomId] = [];
      }

      // إضافة الرسالة للذاكرة المؤقتة
      _roomMessagesCache[message.roomId]!.add(message);

      // تحديث واجهة المستخدم بقائمة الرسائل الجديدة
      _messagesController.add(_roomMessagesCache[message.roomId]!);

      if (persist) {
        // Insert into room_messages table
        await _supabase.from('room_messages').insert({
          'id': message.id,
          'room_id': message.roomId,
          'user_id': message.userId == 'system' ? null : message.userId,
          'display_name': message.displayName,
          'content': message.content,
          'sent_at': message.sentAt.toIso8601String(),
          'is_system': message.isSystem,
          'avatar_url': message.avatarUrl,
          'emoji': message.emoji,
          'images': message.images,
          'animated_images': message.animatedImages,
          'audio_url': message.audioUrl,
          'audio_duration_ms': message.audioDurationMs,
          'reactions': _encodeReactions(message.reactions),
        });

        if (!message.isSystem && message.userId != 'system') {
          unawaited(_triggerChatNotification(message));
        }
      }

      if (broadcast && _currentRoomChannel != null) {
        await _broadcastToChannel(
          channel: _currentRoomChannel!,
          event: 'new_message',
          payload: message.toJson(),
        );
      }

      return message;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _triggerChatNotification(RoomMessage message) async {
    try {
      final trimmedContent = message.content.trim();
      String? roomName =
          _currentRoom?.id == message.roomId ? _currentRoom?.name : null;

      if ((roomName == null || roomName.isEmpty) && message.roomId.isNotEmpty) {
        try {
          final response = await _supabase
              .from('rooms')
              .select('name')
              .eq('id', message.roomId)
              .maybeSingle();

          if (response != null) {
            final data = Map<String, dynamic>.from(response as Map);
            final fetchedName = data['name']?.toString().trim();
            if (fetchedName != null && fetchedName.isNotEmpty) {
              roomName = fetchedName;
            }
          }
        } catch (error, stack) {
          developer.log(
            'Failed to resolve room name for notification',
            name: 'RoomsRepository',
            error: error,
            stackTrace: stack,
          );
        }
      }

      final response =
          await _supabase.functions.invoke('send-room-message', body: {
        'room_id': message.roomId,
        'message_id': message.id,
        'sender_id': message.userId,
        'sender_name': message.displayName,
        'content': trimmedContent,
        if (roomName != null && roomName.isNotEmpty) 'room_name': roomName,
        if (message.avatarUrl != null && message.avatarUrl!.isNotEmpty)
          'sender_avatar': message.avatarUrl,
      });

      developer.log(
        'send-room-message result',
        name: 'RoomsRepository',
        error: {
          'status': response.status,
          'data': response.data,
        },
      );
    } catch (e, stackTrace) {
      developer.log('Failed to trigger chat notification',
          name: 'RoomsRepository', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _saveRoomToDatabase(Room room) async {
    try {
      final now = DateTime.now();
      final roomData = {
        'id': room.id,
        'name': room.name,
        'code': room.code,
        'host_id': room.hostId,
        'status': room.status.name,
        'game_mode': 'public',
        'privacy_type': room.privacyType.name,
        'join_mode': room.joinMode.name,
        'discoverable': room.discoverable,
        'description': room.description,
        'logo_source': room.logoSource.name,
        'logo_asset_key': room.logoAssetKey,
        'logo_url': room.logoUrl,
        'max_members': room.maxMembers,
        'metadata': room.metadata,
        'created_at': room.createdAt.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      await _supabase.from('rooms').upsert(roomData, onConflict: 'id');

      for (final member in room.members) {
        await _supabase.from('room_members').upsert({
          'room_id': room.id,
          'user_id': member.userId,
          'display_name': member.displayName,
          'avatar_url': member.avatarUrl,
          'is_host': member.isHost,
          'is_ready': member.isReady,
          'is_spectator': member.isSpectator,
          'team': member.team?.name,
          'role': member.isHost ? 'owner' : 'member',
          'muted_until': null,
          'kicked_at': null,
          'metadata': const <String, dynamic>{},
        }, onConflict: 'room_id,user_id');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _broadcastRoomUpdate(Room room) async {
    try {
      if (_currentRoomChannel?.isJoined == true) {
        final roomJson = room.toJson();

        await _broadcastToChannel(
          channel: _currentRoomChannel!,
          event: 'room_updated',
          payload: roomJson,
        );
      } else {}
    } catch (e) {}
  }

  Future<void> _sendSystemMessage(String roomId, String message,
      [String? avatarUrl]) async {
    try {
      final systemMessage = RoomMessage(
        id: 'sys_${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        userId: 'system',
        displayName: 'النظام',
        content: message,
        sentAt: DateTime.now(),
        isSystem: true,
        avatarUrl: avatarUrl,
      );

      await _addMessage(systemMessage);
    } catch (e) {
      print('خطأ في إرسال رسالة النظام: $e');
    }
  }

  Future<void> _sendReadyStatusMessage(RoomMember member, bool isReady) async {
    try {
      final roomId = _currentRoomId ?? _currentRoom?.id;
      if (roomId == null) return;

      final displayName = member.displayName.trim().isNotEmpty
          ? member.displayName.trim()
          : 'لاعب';
      final content = isReady ? 'أنا جاهز ✅' : 'أنا مش جاهز ⏳';

      final statusMessage = RoomMessage(
        id: 'ready_${member.userId}_${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        userId: member.userId,
        displayName: displayName,
        content: content,
        sentAt: DateTime.now(),
        isSystem: false,
        avatarUrl: member.avatarUrl,
      );

      await _addMessage(statusMessage);
    } catch (e) {
      developer.log('Failed to send ready status message',
          name: 'RoomsRepository', error: e);
    }
  }

  Future<void> _cleanupRoomState() async {
    await _currentRoomChannel?.unsubscribe();
    _currentRoomChannel = null;
    _currentRoom = null;
    _currentRoomId = null;
    _roomController.add(null);
    _messagesController.add([]);
  }

  // Event Handlers
  void _handleMemberJoined(dynamic payload) {
    try {
      final member =
          RoomMember.fromJson(payload['member'] as Map<String, dynamic>);
      if (_currentRoom != null &&
          !_currentRoom!.members.any((m) => m.userId == member.userId)) {
        final updatedMembers = [..._currentRoom!.members, member];
        _currentRoom = _currentRoom!.copyWith(members: updatedMembers);
        _roomController.add(_currentRoom);
      }
    } catch (e) {
      print('خطأ في معالجة انضمام العضو: $e');
    }
  }

  void _handleMemberLeft(dynamic payload) {
    try {
      final userId = payload['user_id'] as String;
      if (_currentRoom != null) {
        final updatedMembers = _currentRoom!.members
            .where((member) => member.userId != userId)
            .toList();
        _currentRoom = _currentRoom!.copyWith(members: updatedMembers);
        _roomController.add(_currentRoom);
      }
    } catch (e) {
      print('خطأ في معالجة مغادرة العضو: $e');
    }
  }

  void _handleMemberUpdated(dynamic payload) {
    try {
      final updatedMember =
          RoomMember.fromJson(payload['member'] as Map<String, dynamic>);
      if (_currentRoom != null) {
        final updatedMembers = _currentRoom!.members.map((member) {
          return member.userId == updatedMember.userId ? updatedMember : member;
        }).toList();

        _currentRoom = _currentRoom!.copyWith(members: updatedMembers);
        _roomController.add(_currentRoom);
      }
    } catch (e) {
      print('خطأ في معالجة تحديث العضو: $e');
    }
  }

  void _handleMessageSent(dynamic payload) {
    try {
      if (_currentRoom == null) return;

      final message = RoomMessage.fromJson(payload as Map<String, dynamic>);

      // تحديث الذاكرة المؤقتة والواجهة
      if (_roomMessagesCache[message.roomId] == null) {
        _roomMessagesCache[message.roomId] = [];
      }

      // تجنب تكرار الرسائل
      if (!_roomMessagesCache[message.roomId]!.any((m) => m.id == message.id)) {
        _roomMessagesCache[message.roomId]!.add(message);
        _messagesController.add(_roomMessagesCache[message.roomId]!);
      }
    } catch (e) {
      print('خطأ في معالجة الرسالة الواردة: $e');
    }
  }

  void _handleReactionUpdated(dynamic payload) {
    try {
      final messageId = payload['message_id']?.toString();
      final roomId = payload['room_id']?.toString() ?? _currentRoomId;
      if (messageId == null || roomId == null) {
        return;
      }

      Map<String, List<String>> normalizedReactions = const {};
      final rawReactions = payload['reactions'];
      if (rawReactions is Map) {
        final mapped = rawReactions.map(
          (key, value) => MapEntry(
            key.toString(),
            value is List
                ? value.map((e) => e.toString()).toList()
                : <String>[],
          ),
        );
        normalizedReactions = RoomMessage.normalizeReactions(mapped);
      }

      final cachedMessages = _roomMessagesCache[roomId];
      if (cachedMessages == null) {
        return;
      }

      final index =
          cachedMessages.indexWhere((message) => message.id == messageId);
      if (index == -1) {
        return;
      }

      final updatedMessages = List<RoomMessage>.from(cachedMessages);
      updatedMessages[index] =
          updatedMessages[index].copyWith(reactions: normalizedReactions);

      _roomMessagesCache[roomId] = updatedMessages;
      _messagesController.add(updatedMessages);
    } catch (e) {
      print('خطأ في تحديث ردود الأفعال: $e');
    }
  }

  void _handleBuzz(dynamic payload) {
    try {
      print('🔵 ===== بدء استقبال بوز جديد =====');
      print('🔵 البايانات المستلمة: $payload');

      if (payload == null) {
        print('❌ خطأ: لا توجد بيانات بوز (payload is null)');
        return;
      }

      print('🔵 تحويل البايانات إلى خريطة...');
      final payloadMap = Map<String, dynamic>.from(payload as Map);
      final userId = payloadMap['user_id']?.toString();
      final roomId = payloadMap['room_id']?.toString();
      final displayName = payloadMap['display_name']?.toString();

      print('🔵 تفاصيل البوز:');
      print('   - المستخدم: $displayName ($userId)');
      print('   - الغرفة: $roomId');
      print('   - المستخدم الحالي: $_currentUserId');

      if (userId == null || roomId == null) {
        print('❌ خطأ: بيانات البوز غير مكتملة');
        return;
      }

      // إرسال Buzz event إلى الـ UI (حتى من نفس المستخدم للاختبار)
      // يمكن للمستخدم الآخرين رؤيته، والـ UI سيتجاهل Buzz من نفس المستخدم
      print('🔵 إضافة حدث البوز إلى الـ Stream...');
      _buzzController.add(payloadMap);
      print('✅ تم إضافة حدث البوز بنجاح إلى الـ Stream');
    } catch (e) {
      print('❌ خطأ في معالجة Buzz: $e');
    }
  }

  void _handleCheer(dynamic payload) {
    try {
      print('🎵 ===== بدء استقبال تصفيق جديد (Cheer) =====');
      print('🎵 البيانات المستلمة: $payload');

      if (payload == null) {
        print('❌ خطأ: لا توجد بيانات للتصفيق (payload is null)');
        return;
      }

      print('🎵 تحويل بيانات التصفيق إلى خريطة...');
      final payloadMap = Map<String, dynamic>.from(payload as Map);
      final userId = payloadMap['user_id']?.toString();
      final roomId = payloadMap['room_id']?.toString();
      final displayName = payloadMap['display_name']?.toString();

      print('🎵 تفاصيل التصفيق:');
      print('   - المستخدم: $displayName ($userId)');
      print('   - الغرفة: $roomId');
      print('   - المستخدم الحالي: $_currentUserId');

      if (userId == null || roomId == null) {
        print('❌ خطأ: بيانات التصفيق غير مكتملة');
        return;
      }

      print('🎵 إضافة حدث التصفيق إلى الـ Stream...');
      _cheerController.add(payloadMap);
      print('✅ تم إضافة حدث التصفيق بنجاح إلى الـ Stream');
    } catch (e) {
      print('❌ خطأ في معالجة التصفيق (Cheer): $e');
    }
  }

  void _handleGameStarted(dynamic payload) {
    try {
      final roomId = payload['room_id'] as String?;
      if (roomId == _currentRoomId) {
        _currentRoom = _currentRoom?.copyWith(
          status: RoomStatus.inGame,
        );
        _roomController.add(_currentRoom!);
      }
    } catch (e) {
      print('خطأ في بدء اللعبة: $e');
    }
  }

  void _handleRoomClosed(dynamic payload) {
    try {
      final roomId = payload['room_id'] as String?;
      if (roomId == _currentRoomId) {
        _cleanupRoomState();
        _sendSystemMessage(roomId!, 'تم إغلاق الغرفة');
      }
    } catch (e) {
      print('خطأ في إغلاق الغرفة: $e');
    }
  }

  // Helper: Convert JSON to Room
  Room _roomFromDatabaseRow(
    Map<String, dynamic> data, {
    List<RoomMember>? members,
    List<RoomMessage>? messages,
    DateTime? createdAtOverride,
  }) {
    final statusValue = data['status']?.toString();
    final roomStatus = RoomStatus.values.firstWhere(
      (e) => e.toString() == 'RoomStatus.$statusValue',
      orElse: () => RoomStatus.waiting,
    );

    final isPrivateLegacy = data['is_private'] == true;
    final privacyValue = data['privacy_type']?.toString().toLowerCase();
    final privacyType = RoomPrivacyType.values.firstWhere(
      (privacy) =>
          privacy.name ==
          (privacyValue ?? (isPrivateLegacy ? 'private' : 'public')),
      orElse: () =>
          isPrivateLegacy ? RoomPrivacyType.private : RoomPrivacyType.public,
    );

    final joinValue = data['join_mode']?.toString();
    final joinValueNormalized = joinValue?.toLowerCase();
    final fallbackJoin = privacyType == RoomPrivacyType.public
        ? RoomJoinMode.instant
        : RoomJoinMode.approval;
    final joinMode = joinValueNormalized != null
        ? RoomJoinMode.values.firstWhere(
            (mode) => mode.name.toLowerCase() == joinValueNormalized,
            orElse: () => fallbackJoin,
          )
        : fallbackJoin;

    final logoSourceValue = data['logo_source']?.toString().toLowerCase();
    final hasLogoUrl = (data['logo_url'] as String?)?.isNotEmpty ?? false;
    final defaultLogoSource =
        hasLogoUrl ? RoomLogoSource.upload : RoomLogoSource.preset;
    final logoSource = logoSourceValue != null
        ? RoomLogoSource.values.firstWhere(
            (source) => source.name == logoSourceValue,
            orElse: () => defaultLogoSource,
          )
        : defaultLogoSource;

    final createdAt = createdAtOverride ?? _parseDateTime(data['created_at']);
    final updatedAt = _parseDateTime(data['updated_at'], fallback: createdAt);

    final rawMetadata = data['metadata'];
    Map<String, dynamic> metadata = const {};
    if (rawMetadata is Map) {
      metadata = Map<String, dynamic>.from(rawMetadata);
    }

    DateTime? codeRotatedAt;
    final codeRotatedAtRaw = metadata['code_rotated_at'];
    if (codeRotatedAtRaw is String) {
      codeRotatedAt = DateTime.tryParse(codeRotatedAtRaw);
    } else if (codeRotatedAtRaw is DateTime) {
      codeRotatedAt = codeRotatedAtRaw;
    }

    return Room(
      id: data['id']?.toString() ??
          'room_${DateTime.now().millisecondsSinceEpoch}',
      name: data['name']?.toString() ?? 'غرفة بدون اسم',
      code: data['code']?.toString() ?? '',
      hostId: data['host_id']?.toString() ?? '',
      status: roomStatus,
      privacyType: privacyType,
      joinMode: joinMode,
      discoverable: data['discoverable'] as bool? ?? true,
      description: data['description'] as String?,
      logoSource: logoSource,
      logoAssetKey: data['logo_asset_key'] as String?,
      logoUrl: data['logo_url'] as String?,
      maxMembers: data['max_members'] is int
          ? data['max_members'] as int
          : int.tryParse('${data['max_members']}'),
      createdAt: createdAt,
      updatedAt: updatedAt,
      members: members ?? const [],
      messages: messages ?? const [],
      metadata: metadata,
      codeRotatedAt: codeRotatedAt,
    );
  }

  Future<Map<String, dynamic>> _ensureFreshRoomCode(
      Map<String, dynamic> roomData) async {
    try {
      final roomId = roomData['id']?.toString();
      if (roomId == null) {
        return roomData;
      }

      final metadata =
          Map<String, dynamic>.from(roomData['metadata'] as Map? ?? {});
      final rawTimestamp = metadata['code_rotated_at'];
      DateTime? lastRotated;
      if (rawTimestamp is String && rawTimestamp.isNotEmpty) {
        lastRotated = DateTime.tryParse(rawTimestamp);
      } else if (rawTimestamp is DateTime) {
        lastRotated = rawTimestamp;
      }

      final now = DateTime.now();
      if (lastRotated != null &&
          now.difference(lastRotated) < _roomCodeRotationInterval) {
        return roomData;
      }

      final newCode = _generateRoomCode();
      metadata['code_rotated_at'] = now.toIso8601String();

      final updatedRoomData = Map<String, dynamic>.from(roomData)
        ..['code'] = newCode
        ..['metadata'] = metadata
        ..['updated_at'] = now.toIso8601String();

      await _supabase.from('rooms').update({
        'code': newCode,
        'metadata': metadata,
        'updated_at': now.toIso8601String(),
      }).eq('id', roomId);

      return updatedRoomData;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to rotate room code',
        name: 'RoomsRepository',
        error: e,
        stackTrace: stackTrace,
      );
      return roomData;
    }
  }

  Room _roomFromJson(Map<String, dynamic> data) {
    final members = <RoomMember>[];
    final rawMembers = data['members'];
    if (rawMembers is List) {
      for (final rawMember in rawMembers) {
        try {
          final memberData = Map<String, dynamic>.from(rawMember as Map);
          Team? team;
          final teamValue = memberData['team']?.toString();
          if (teamValue != null && teamValue.isNotEmpty) {
            team = Team.values.firstWhere(
              (t) => t.toString() == 'Team.$teamValue',
              orElse: () => Team.a,
            );
          }

          members.add(RoomMember(
            userId: memberData['user_id']?.toString() ?? '',
            displayName: memberData['display_name']?.toString() ?? 'لاعب',
            avatarUrl: memberData['avatar_url']?.toString(),
            isHost: memberData['is_host'] as bool? ?? false,
            isReady: memberData['is_ready'] as bool? ?? false,
            isSpectator: memberData['is_spectator'] as bool? ?? false,
            team: team,
          ));
        } catch (e) {
          developer.log('Error parsing member data',
              name: 'RoomsRepository', error: e);
        }
      }
    }

    final messages = <RoomMessage>[];
    final rawMessages = data['messages'];
    if (rawMessages is List) {
      for (final rawMessage in rawMessages) {
        try {
          final msgData = Map<String, dynamic>.from(rawMessage as Map);
          messages.add(RoomMessage.fromJson(msgData));
        } catch (e) {
          developer.log('Error parsing message data',
              name: 'RoomsRepository', error: e);
        }
      }
    }

    return _roomFromDatabaseRow(
      Map<String, dynamic>.from(data),
      members: members,
      messages: messages,
    );
  }

  DateTime _parseDateTime(dynamic value, {DateTime? fallback}) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
    }
    return fallback ?? DateTime.now();
  }

  // Cleanup
  Future<void> dispose() async {
    try {
      await _roomController.close();
      await _messagesController.close();
      await _presenceController.close();
      await _roomsChannelSubscription?.unsubscribe();
      await _currentRoomChannel?.unsubscribe();

      _roomsChannelSubscription = null;
      _currentRoomChannel = null;
      _currentRoom = null;
      _currentRoomId = null;
      _isInitialized = false;
    } catch (e) {
      print('خطأ في إغلاق الموارد: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _encodeReactions(Map<String, List<String>> reactions) {
    if (reactions.isEmpty) {
      return {};
    }

    return reactions.map(
      (key, value) => MapEntry(key, List<String>.from(value)),
    );
  }

  Future<void> _broadcastToChannel({
    required RealtimeChannel channel,
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    // ignore: invalid_use_of_visible_for_testing_member
    await channel.send(
      type: RealtimeListenTypes.broadcast,
      event: event,
      payload: payload,
    );
  }
}

// Helper function to avoid unawaited future warnings
void _unawaited(Future<void> future) {}
