import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:so7ba/core/navigation_service.dart';
import 'package:so7ba/data/rooms_repository.dart';
import 'package:so7ba/screens/rooms/room_lobby_screen.dart';
import 'package:uuid/uuid.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  developer.log('Background message received: ${message.data}', name: 'NotificationService');
  await NotificationService().handleBackgroundMessage(message);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _roomAlertsChannelId = 'room_alerts_channel';
  static const _roomAlertsChannelName = 'Room Alerts';
  static const _roomAlertsChannelDescription =
      'إشعارات تنبيه الغرف بصوت خاص';

  static const _deviceIdPrefsKey = 'notification_device_id';
  final Uuid _uuid = const Uuid();

  FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final RoomsRepository _roomsRepository = RoomsRepository();

  String? _activeChatRoomId;
  String? _deviceId;
  bool _pendingTokenSave = false;
  StreamSubscription<AuthState>? _authSubscription;

  void setActiveChatRoom(String roomId) {
    _activeChatRoomId = roomId;
  }

  void clearActiveChatRoom(String roomId) {
    if (_activeChatRoomId == roomId) {
      _activeChatRoomId = null;
    }
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    developer.log('Handling background message: ${message.messageId}',
        name: 'NotificationService');
    await _showLocalNotification(message);
  }

  // تهيئة الإشعارات
  Future<void> initialize() async {
    debugPrint('[NotificationService] Initialization started');
    await _ensureDeviceId();
    debugPrint('[NotificationService] Using deviceId=$_deviceId');
    // طلب إذن الإشعارات
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    developer.log('Permission status: ${settings.authorizationStatus}',
        name: 'NotificationService');
    debugPrint('[NotificationService] Permission status: ${settings.authorizationStatus}');

    // تهيئة الإشعارات المحلية
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    debugPrint('[NotificationService] Local notifications initialized');

    const channelSound = RawResourceAndroidNotificationSound('n1');
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final androidNotificationChannel = AndroidNotificationChannel(
        _roomAlertsChannelId,
        _roomAlertsChannelName,
        description: _roomAlertsChannelDescription,
        importance: Importance.max,
        playSound: true,
        sound: channelSound,
      );

      await androidImplementation.createNotificationChannel(androidNotificationChannel);
      developer.log('Notification channel created', name: 'NotificationService');
      debugPrint('[NotificationService] Android channel ready');
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    // الاستماع للإشعارات في الخلفية
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      developer.log('🔁 FCM token refreshed',
          name: 'NotificationService', error: {'token_length': token.length});
      debugPrint('[NotificationService] Token refreshed (${token.length} chars)');
      await storeTokenInSupabase(token);
    });
    
    // التحقق من الإشعار عند فتح التطبيق
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Store token immediately if user is already logged in
    await _storeTokenForCurrentUser();
    
    // Clean up invalid tokens
    await cleanupInvalidTokens();
    
    debugPrint('[NotificationService] Initialization finished');

    // Listen for auth state changes to store token on login
    _authSubscription?.cancel();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      developer.log('Auth state changed: $event, session: ${session != null}',
          name: 'NotificationService');

      if (event == AuthChangeEvent.signedOut) {
        _pendingTokenSave = false;
        await removeTokenFromSupabase();
        return;
      }

      final bool shouldStoreToken = session != null &&
          (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed ||
              _pendingTokenSave);

      if (shouldStoreToken) {
        await _storeTokenForCurrentUser(force: true);
      }
    });

    developer.log('Notification service initialized successfully', name: 'NotificationService');
  }

  // الحصول على FCM Token وتخزينه
  Future<String?> getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      developer.log('FCM Token: $token');
      return token;
    } catch (e) {
      developer.log('Error getting FCM token: $e');
      return null;
    }
  }

  // دالة لتنظيف UUID ومنع المسافات أو علامات الاقتباس
  String _sanitizeUserId(String userId) => userId.replaceAll('"', '').trim();

  // التحقق من صحة صيغة UUID
  bool _isValidUuid(String value) =>
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
              caseSensitive: false)
          .hasMatch(value);

  bool _isSessionExpired(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) {
      return false;
    }
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true);
    return DateTime.now().toUtc().isAfter(expiry.subtract(const Duration(seconds: 30)));
  }

  // تخزين التوكن في Supabase
  Future<void> storeTokenInSupabase(String token) async {
    try {
      await _ensureDeviceId();
      final deviceId = _deviceId;
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id;

      if (userId == null) {
        developer.log('🚨 User not logged in, cannot store token');
        debugPrint('[NotificationService] storeToken skipped: no user');
        return;
      }

      if (deviceId == null) {
        debugPrint('[NotificationService] storeToken skipped: deviceId unavailable');
        return;
      }

      final cleanUserId = _sanitizeUserId(userId);

      if (!_isValidUuid(cleanUserId)) {
        developer.log('🚨 Invalid UUID format detected while storing token',
            name: 'NotificationService',
            error: {'original': userId, 'sanitized': cleanUserId});
        return;
      }

      developer.log(
        '🔄 [storeToken] Upserting token -> ${jsonEncode({
          'user_id_raw': userId,
          'user_id_clean': cleanUserId,
          'token_length': token.length,
          'device_id': deviceId,
        })}',
        name: 'NotificationService',
      );
      debugPrint('[NotificationService] Saving token for $cleanUserId on device $deviceId');

      final response = await Supabase.instance.client
          .from('user_tokens')
          .upsert({
        'user_id': cleanUserId,
        'token': token,
        'device_id': deviceId,
      },
              onConflict: 'user_id')
          .select()
          .maybeSingle();

      developer.log(
        '✅ Token stored/updated in Supabase -> ${response != null ? jsonEncode(response) : 'null'}',
        name: 'NotificationService',
      );
      debugPrint('[NotificationService] Token saved response: ${response != null}');
      _pendingTokenSave = false;
    } on AuthRetryableFetchException catch (e, stackTrace) {
      _pendingTokenSave = true;
      developer.log(
        '⏸️ Skipping token save because auth refresh failed',
        name: 'NotificationService',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('[NotificationService] Auth refresh failed while saving token, will retry later');
    } catch (e, stackTrace) {
      developer.log('🔥 Error storing token in Supabase',
          name: 'NotificationService', error: e, stackTrace: stackTrace);
      debugPrint('[NotificationService] Failed to save token: $e');
    }
  }

  // دالة لتنظيف التوكنز القديمة (بدون is_active)
  Future<void> cleanupInvalidTokens() async {
    try {
      developer.log('🧹 Starting cleanup of old tokens', name: 'NotificationService');
      
      // Delete tokens older than 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final response = await Supabase.instance.client
          .from('user_tokens')
          .delete()
          .lt('created_at', thirtyDaysAgo.toIso8601String())
          .select();
      
      if (response.isNotEmpty) {
        developer.log('🗑️ Deleted ${response.length} old tokens (older than 30 days)', name: 'NotificationService');
      } else {
        developer.log('✅ No old tokens found to cleanup', name: 'NotificationService');
      }
    } catch (e, stackTrace) {
      developer.log('🔥 Error during token cleanup',
          name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  // دالة للتحقق من صحة التوكن
  Future<bool> validateToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('https://iid.googleapis.com/iid/info/$token'),
        headers: {
          'Authorization': 'key=YOUR_FCM_SERVER_KEY',
          'Content-Type': 'application/json',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      developer.log('🔥 Error validating token: $e', name: 'NotificationService');
      return false;
    }
  }

  // Store token for currently logged in user (helper method)
  Future<void> _storeTokenForCurrentUser({bool force = false}) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final user = session?.user ?? Supabase.instance.client.auth.currentUser;
      if (user == null) {
        developer.log('No user logged in during init, skipping token storage',
            name: 'NotificationService');
        debugPrint('[NotificationService] No logged-in user during init');
        return;
      }

      if (!force && session != null && _isSessionExpired(session)) {
        _pendingTokenSave = true;
        developer.log('Session expired, deferring token save until refresh completes',
            name: 'NotificationService');
        debugPrint('[NotificationService] Session expired, waiting for token refresh');
        return;
      }

      developer.log('User already logged in during init, storing token',
          name: 'NotificationService');
      debugPrint('[NotificationService] User already logged in, fetching token');
      final token = await getFCMToken();
      if (token != null) {
        debugPrint('[NotificationService] Token fetched (${token.length} chars)');
        await storeTokenInSupabase(token);
      }
    } on AuthRetryableFetchException catch (e, stackTrace) {
      _pendingTokenSave = true;
      developer.log('Auth refresh failed while storing token for current user',
          name: 'NotificationService', error: e, stackTrace: stackTrace);
      debugPrint('[NotificationService] Will retry token save after auth refresh');
    } catch (e) {
      developer.log('Error in _storeTokenForCurrentUser: $e',
          name: 'NotificationService');
      debugPrint('[NotificationService] _storeTokenForCurrentUser error: $e');
    }
  }

  // حذف التوكن من Supabase والجهاز (عند تسجيل الخروج)
  Future<void> removeTokenFromSupabase() async {
    try {
      await _ensureDeviceId();
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id;
      final deviceId = _deviceId;
      _pendingTokenSave = false;

      if (userId == null) {
        developer.log('🚨 User not logged in, cannot remove stored tokens');
        await _deleteFirebaseToken();
        return;
      }

      if (deviceId == null) {
        developer.log('🚨 Device ID unavailable while removing token',
            name: 'NotificationService');
        await _deleteFirebaseToken();
        return;
      }

      final cleanUserId = _sanitizeUserId(userId);

      if (!_isValidUuid(cleanUserId)) {
        developer.log('🚨 Invalid UUID format detected while removing token',
            name: 'NotificationService',
            error: {'original': userId, 'sanitized': cleanUserId});
        return;
      }

      developer.log(
        '🗑️ [removeToken] Deleting tokens -> ${jsonEncode({
          'user_id_raw': userId,
          'user_id_clean': cleanUserId,
          'device_id': deviceId,
        })}',
        name: 'NotificationService',
      );

      final response = await Supabase.instance.client
          .from('user_tokens')
          .delete()
          .eq('user_id', cleanUserId)
          .eq('device_id', deviceId)
          .select();

      developer.log(
        '✅ Tokens removed from Supabase -> ${jsonEncode(response)}',
        name: 'NotificationService',
      );

      // Fallback: if no rows deleted, try removing all tokens for this user
      if (response.isEmpty) {
        developer.log('⚠️ No tokens deleted with device_id, trying fallback to delete all user tokens',
            name: 'NotificationService');
        final fallbackResponse = await Supabase.instance.client
            .from('user_tokens')
            .delete()
            .eq('user_id', cleanUserId)
            .select();
        developer.log('✅ Fallback deletion result -> ${jsonEncode(fallbackResponse)}',
            name: 'NotificationService');
      }

      await _deleteFirebaseToken();
    } catch (e) {
      developer.log('🔥 Error removing token from Supabase',
          name: 'NotificationService', error: e);
    }
  }

  Future<void> _deleteFirebaseToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      developer.log('🧹 Firebase token deleted locally', name: 'NotificationService');
    } catch (e) {
      developer.log('🔥 Error deleting Firebase token locally',
          name: 'NotificationService', error: e);
    }
  }

  Future<void> _ensureDeviceId() async {
    if (_deviceId != null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_deviceIdPrefsKey);
    if (stored != null && stored.isNotEmpty) {
      _deviceId = stored;
      return;
    }

    final generated = _uuid.v4();
    final saved = await prefs.setString(_deviceIdPrefsKey, generated);
    _deviceId = saved ? generated : null;
  }

  
  void _handleForegroundMessage(RemoteMessage message) {
    developer.log('Received a foreground message: ${message.messageId}',
        name: 'NotificationService');

    developer.log('Foreground message data: ${message.data}',
        name: 'NotificationService');

    final roomId =
        message.data['room_id']?.toString() ?? message.data['ROOM_ID']?.toString();
    if (roomId != null && roomId.isNotEmpty && roomId == _activeChatRoomId) {
      developer.log(
        'Skipping local notification because user is viewing room $roomId',
        name: 'NotificationService',
      );
      return;
    }

    _showLocalNotification(message);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    developer.log('Message clicked: ${message.messageId}');
    unawaited(_handleNotificationAction(message.data));
  }

  // عرض إشعار محلي
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const channelSound = RawResourceAndroidNotificationSound('n1');
    AndroidNotificationDetails androidPlatformChannelSpecifics;

    final imageUrl = message.notification?.android?.imageUrl ??
        message.notification?.apple?.imageUrl ??
        message.data['image_url'] as String? ??
        message.data['image'] as String?;

    final senderName = message.data['sender_name']?.toString();
    final roomName = message.data['room_name']?.toString();
    final contentSnippet = message.data['content']?.toString();

    final notificationTitle = message.notification?.title ??
        ((senderName != null && roomName != null)
            ? '$senderName • $roomName'
            : roomName ?? 'تنبيه جديد');

    final notificationBody = message.notification?.body ??
        contentSnippet ??
        'لديك رسالة جديدة';

    FilePathAndroidBitmap? largeIconBitmap;
    BigPictureStyleInformation? bigPictureStyle;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final imagePath = await _downloadAndSaveFile(
          imageUrl,
          'notif_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (imagePath != null) {
          largeIconBitmap = FilePathAndroidBitmap(imagePath);
          bigPictureStyle = BigPictureStyleInformation(
            FilePathAndroidBitmap(imagePath),
            largeIcon: largeIconBitmap,
            contentTitle: message.notification?.title ?? message.data['title'] as String?,
            summaryText: message.notification?.body ?? message.data['body'] as String?,
          );
        }
      } catch (e, stack) {
        developer.log('Failed to attach image to notification: $e',
            name: 'NotificationService', stackTrace: stack);
      }
    }

    androidPlatformChannelSpecifics = AndroidNotificationDetails(
      _roomAlertsChannelId,
      _roomAlertsChannelName,
      channelDescription: _roomAlertsChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      sound: channelSound,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      styleInformation: bigPictureStyle,
      icon: 'ic_notification',
      largeIcon: largeIconBitmap ?? const DrawableResourceAndroidBitmap('ic_notification'),
    );

    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
      sound: 'n1.mp3',
      presentSound: true,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    final payloadData = message.data;
    final payloadJson = payloadData.isNotEmpty ? jsonEncode(payloadData) : null;

    await _localNotifications.show(
      message.hashCode,
      notificationTitle,
      notificationBody,
      platformChannelSpecifics,
      payload: payloadJson,
    );
  }

  // التعامل مع الضغط على الإشعار
  void _onNotificationTap(NotificationResponse response) {
    developer.log('Notification tapped: ${response.payload}');
    // تحويل payload إلى Map والتعامل معه
    if (response.payload != null) {
      try {
        final decoded = jsonDecode(response.payload!);
        if (decoded is Map) {
          final payloadMap = decoded.map((key, value) => MapEntry(key.toString(), value));
          unawaited(_handleNotificationAction(Map<String, dynamic>.from(payloadMap)));
        }
      } catch (e) {
        developer.log('⚠️ Failed to parse notification payload: $e');
      }
    }
  }

  // التعامل مع إجراءات الإشعار
  Future<void> _handleNotificationAction(Map<String, dynamic> data) async {
    final sanitizedData = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is String) {
        sanitizedData[key] = value.replaceAll('"', '').trim();
      } else if (value != null) {
        sanitizedData[key] = value;
      }
    });

    developer.log('Handling notification action: $sanitizedData');

    final typeValue = sanitizedData['type'] ?? sanitizedData['TYPE'];
    final type = typeValue?.toString().toLowerCase();

    switch (type) {
      case 'room_chat_message':
        await _navigateToRoomChat(sanitizedData);
        break;
      default:
        developer.log('No navigation handler for notification type: $type');
    }
  }

  Future<void> _navigateToRoomChat(Map<String, dynamic> data) async {
    final roomId = data['room_id']?.toString();
    if (roomId == null || roomId.isEmpty) {
      developer.log('Missing room_id in chat notification payload');
      return;
    }

    final navigator = rootNavigator;
    if (navigator == null) {
      developer.log('Root navigator not available to open room');
      return;
    }

    try {
      if (!_roomsRepository.isInitialized) {
        await _roomsRepository.initialize();
      }

      var room = _roomsRepository.currentRoom;
      if (room == null || room.id != roomId) {
        room = await _roomsRepository.getRoomById(roomId, includeMessages: true);
      }

      if (room == null) {
        developer.log('Failed to fetch room for notification',
            name: 'NotificationService', error: {'roomId': roomId});
        return;
      }

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final isMember = currentUserId != null &&
          room.members.any((member) => member.userId == currentUserId);

      if (!isMember) {
        developer.log('User is not a member of room, blocking navigation',
            name: 'NotificationService', error: {
          'roomId': roomId,
          'userId': currentUserId,
        });

        final context = rootContext;
        if (context != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يمكنك الدخول إلى هذه الغرفة بدون دعوة أو انضمام مسبق'),
                duration: Duration(seconds: 4),
              ),
            );
          });
        }
        return;
      }

      final roomToOpen = room;
      Future.microtask(() {
        if (!navigator.mounted) {
          return;
        }

        navigator.push(MaterialPageRoute(
          builder: (_) => RoomLobbyScreen(room: roomToOpen, openChatTab: true),
        ));
      });
    } catch (e, stackTrace) {
      developer.log('Failed to navigate to room after notification',
          name: 'NotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<String?> _downloadAndSaveFile(String url, String fileName) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        developer.log('Failed to download image for notification',
            name: 'NotificationService',
            error: {'statusCode': response.statusCode, 'url': url});
        return null;
      }

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (e, stackTrace) {
      developer.log('Error downloading notification image: $e',
          name: 'NotificationService', stackTrace: stackTrace);
      return null;
    }
  }
}
