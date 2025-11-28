import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room_models.dart';
import '../models/match_models.dart';
import 'profile_repository.dart';
import '../utils/realtime_utils.dart';

// دالة مساعدة لتجنب تحذير unawaited
void _unawaited(Future<void> future) {
  future.then((_) {}).catchError((e) => print('خطأ في العملية غير المنتظرة: $e'));
}

class RoomsRepository {
  // نمط Singleton
  static final RoomsRepository _instance = RoomsRepository._internal();
  factory RoomsRepository() => _instance;
  RoomsRepository._internal() {
    _currentRoom = null;
  }

  // ثوابت
  static const String _roomsChannel = 'rooms';
  static const String _broadcastEvent = 'broadcast';
  static const String _memberJoinedEvent = 'member_joined';
  static const String _memberLeftEvent = 'member_left';
  static const String _memberUpdatedEvent = 'member_updated';
  static const String _messageSentEvent = 'message_sent';
  static const String _gameStartedEvent = 'game_started';
  static const String _roomClosedEvent = 'room_closed';

  // عميل Supabase والمستودعات
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProfileRepository _profileRepository = ProfileRepository();

  // حالة الغرفة الحالية
  Room? _currentRoom;
  String? _currentRoomId;
  RealtimeChannel? _currentRoomChannel;
  RealtimeChannel? _roomsChannelSubscription;

  // وحدات تحكم بالتدفقات
  final StreamController<Room?> _roomController = StreamController<Room?>.broadcast();
  final StreamController<List<RoomMessage>> _messagesController = StreamController<List<RoomMessage>>.broadcast();
  final StreamController<Map<String, dynamic>> _presenceController = StreamController<Map<String, dynamic>>.broadcast();

  // ذاكرة مؤقتة لسجل الرسائل لكل غرفة
  final Map<String, List<RoomMessage>> _roomMessagesCache = {};

  // حالة التهيئة
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get isDisposed => _roomController.isClosed;

  // خصائص للوصول
  Stream<Room?> get roomStream => _roomController.stream;
  Stream<List<RoomMessage>> get messagesStream => _messagesController.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;
  Room? get currentRoom => _currentRoom;
  String? get currentUserId => _supabase.auth.currentUser?.id;
  String get displayName => _supabase.auth.currentUser?.userMetadata?['full_name'] ?? 'مستخدم';

  // دوال مساعدة
  String _roomChannel(String roomId) => 'room_$roomId';

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (i) => chars[random.nextInt(chars.length)]).join();
  }

  // الدوال العامة
  Future<void> initialize() async {
    if (_isInitialized) return;
    final userId = currentUserId;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      final rooms = await getPublicRooms();
      for (var room in rooms) {
        _roomController.add(room);
      }
      _subscribeToRoomsChannel();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  Future<Room> createRoom({required String name}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      final profile = await _profileRepository.getProfile(userId);
      final code = _generateRoomCode();
      final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
      
      final hostMember = RoomMember(
        userId: userId,
        displayName: '${profile['first_name']} ${profile['last_name']}'.trim(),
        avatarUrl: profile['avatar_url'],
        isHost: true,
        isReady: true,
      );

      final room = Room(
        id: roomId,
        code: code,
        name: name,
        hostId: userId,
        status: RoomStatus.waiting,
        createdAt: DateTime.now(),
        members: [hostMember],
      );

      _currentRoom = room;
      _currentRoomId = roomId;
      await _saveRoomToDatabase(room);
      await _subscribeToRoomChannel(roomId);
      await _trackPresence(roomId);
      _roomController.add(room);
      await _broadcastRoomUpdate(room);
      await _sendSystemMessage(roomId, 'أنشأ ${hostMember.displayName} الغرفة', hostMember.avatarUrl);
      
      return room;
    } catch (e) {
      print('خطأ في إنشاء الغرفة: $e');
      rethrow;
    }
  }

  // إدارة الرسائل
  Future<void> sendMessage(String content, {String? userId}) async {
    if (_currentRoom == null || _currentRoomId == null) return;
    
    final message = RoomMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      roomId: _currentRoomId!,
      userId: userId ?? currentUserId ?? 'system',
      displayName: userId == null ? displayName : 'النظام',
      content: content,
      sentAt: DateTime.now(),
      isSystem: userId != null,
    );

    await _addMessage(message, persist: true, broadcast: true);
  }

  // إدارة الغرفة
  Future<void> toggleReady(bool isReady) async {
    final userId = currentUserId;
    if (userId == null || _currentRoom == null) return;

    final updatedMembers = _currentRoom!.members.map((member) {
      if (member.userId == userId) {
        return member.copyWith(isReady: isReady);
      }
      return member;
    }).toList();

    _currentRoom = _currentRoom!.copyWith(members: updatedMembers);
    _roomController.add(_currentRoom);
    await _saveRoomToDatabase(_currentRoom!);
    await _broadcastRoomUpdate(_currentRoom!);
  }

  Future<void> startGame(String mode) async {
    if (_currentRoom == null) return;
    
    _currentRoom = _currentRoom!.copyWith(
      status: RoomStatus.inGame,
      gameMode: mode,
    );
    
    _roomController.add(_currentRoom);
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
      await _currentRoomChannel?.broadcastMessage(
        event: _roomClosedEvent,
        payload: {'room_id': roomId},
      );
    }
  }

  // الدوال الخاصة
  Future<void> _subscribeToRoomChannel(String roomId) async {
    try {
      await _currentRoomChannel?.unsubscribe();
      _currentRoomChannel = _supabase.realtime.channel(_roomChannel(roomId));
      
      _currentRoomChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_messages',
        filter: PostgresChangeFilter(
          column: 'room_id',
          operator: 'eq',
          value: roomId,
        ),
        callback: (payload) {
          try {
            final message = RoomMessage.fromJson(payload.newRecord);
            _addMessage(message, persist: false, broadcast: false);
          } catch (e) {
            print('خطأ في معالجة الرسالة: $e');
          }
        },
      ).subscribe();
    } catch (e) {
      print('خطأ في الاشتراك بقناة الغرفة: $e');
      rethrow;
    }
  }

  Future<void> _trackPresence(String roomId) async {
    try {
      final presenceTrack = _currentRoomChannel?.onPresenceSync((status) {
        if (status == 'SYNCED') {
          final state = _currentRoomChannel!.presenceState();
          _presenceController.add(state);
        }
      });

      await _currentRoomChannel?.track({
        'user_id': currentUserId,
        'display_name': displayName,
        'online_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('خطأ في تتبع الحضور: $e');
      rethrow;
    }
  }

  Future<void> _addMessage(RoomMessage message, {bool persist = true, bool broadcast = true}) async {
    try {
      // إضافة للذاكرة المؤقتة
      if (!_roomMessagesCache.containsKey(message.roomId)) {
        _roomMessagesCache[message.roomId] = [];
      }
      _roomMessagesCache[message.roomId]!.add(message);
      
      // تحديث التدفق
      _messagesController.add(_roomMessagesCache[message.roomId]!);
      
      // حفظ في قاعدة البيانات إذا لزم الأمر
      if (persist) {
        await _supabase
            .from('room_messages')
            .insert(message.toJson());
      }
      
      // بث للعملاء الآخرين
      if (broadcast) {
        await _currentRoomChannel?.broadcastMessage(
          event: _messageSentEvent,
          payload: message.toJson(),
        );
      }
    } catch (e) {
      print('خطأ في إضافة الرسالة: $e');
      rethrow;
    }
  }

  Future<void> _saveRoomToDatabase(Room room) async {
    try {
      await _supabase
          .from('rooms')
          .upsert(room.toJson(), onConflict: 'id');
    } catch (e) {
      print('خطأ في حفظ الغرفة في قاعدة البيانات: $e');
      rethrow;
    }
  }

  Future<void> _broadcastRoomUpdate(Room room) async {
    try {
      await _currentRoomChannel?.broadcastMessage(
        event: _broadcastEvent,
        payload: room.toJson(),
      );
    } catch (e) {
      print('خطأ في بث تحديثات الغرفة: $e');
      rethrow;
    }
  }

  Future<void> _sendSystemMessage(String roomId, String message, [String? avatarUrl]) async {
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
      rethrow;
    }
  }

  Future<void> _cleanupRoomState() async {
    try {
      await _currentRoomChannel?.unsubscribe();
      _currentRoom = null;
      _currentRoomId = null;
      _currentRoomChannel = null;
      _roomController.add(null);
      _messagesController.add([]);
    } catch (e) {
      print('خطأ في تنظيف حالة الغرفة: $e');
      rethrow;
    }
  }

  // معالجات الأحداث
  void _handleMemberJoined(dynamic payload) {
    try {
      final member = RoomMember.fromJson(payload);
      if (_currentRoom != null) {
        final updatedMembers = List<RoomMember>.from(_currentRoom!.members)..add(member);
        _currentRoom = _currentRoom!.copyWith(members: updatedMembers);
        _roomController.add(_currentRoom);
        _saveRoomToDatabase(_currentRoom!);
        _sendSystemMessage(_currentRoom!.id, 'انضم ${member.displayName} إلى الغرفة', member.avatarUrl);
      }
    } catch (e) {
      print('خطأ في معالجة انضمام العضو: $e');
    }
  }

  void _handleMemberLeft(dynamic payload) {
    try {
      final userId = payload['user_id'] as String?;
      if (userId != null && _currentRoom != null) {
        final member = _currentRoom!.members.firstWhere(
          (m) => m.userId == userId,
          orElse: () => throw Exception('العضو غير موجود'),
        );
        
        final updatedMembers = _currentRoom!.members.where((m) => m.userId != userId).toList();
        _currentRoom = _currentRoom!.copyWith(members: updatedMembers);
        _roomController.add(_currentRoom);
        _saveRoomToDatabase(_currentRoom!);
        _sendSystemMessage(_currentRoom!.id, 'غادر ${member.displayName} الغرفة', member.avatarUrl);
      }
    } catch (e) {
      print('خطأ في معالجة مغادرة العضو: $e');
    }
  }

  void _handleMemberUpdated(dynamic payload) {
    try {
      final member = RoomMember.fromJson(payload);
      if (_currentRoom != null) {
        final updatedMembers = _currentRoom!.members.map((m) => m.userId == member.userId ? member : m).toList();
        _currentRoom = _currentRoom!.copyWith(members: updatedMembers);
        _roomController.add(_currentRoom);
        _saveRoomToDatabase(_currentRoom!);
      }
    } catch (e) {
      print('خطأ في تحديث العضو: $e');
    }
  }

  Future<void> _handleMessageSent(dynamic payload) async {
    try {
      final message = RoomMessage.fromJson(payload);
      if (message.userId != currentUserId) {
        await _addMessage(message, persist: false, broadcast: false);
      }
    } catch (e) {
      print('خطأ في معالجة الرسالة المرسلة: $e');
    }
  }

  void _handleGameStarted(dynamic payload) {
    try {
      if (_currentRoom != null) {
        _currentRoom = _currentRoom!.copyWith(
          status: RoomStatus.inGame,
          gameMode: payload['game_mode'] as String?,
        );
        _roomController.add(_currentRoom);
        _saveRoomToDatabase(_currentRoom!);
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

  // تنظيف الموارد
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
}