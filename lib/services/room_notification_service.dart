import 'dart:convert';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomNotificationService {
  // إرسال تنبيه لأعضاء الغرفة
  static Future<Map<String, dynamic>> sendRoomNotification({
    required String roomId,
    required String senderId,
    String? title,
    String? body,
    String? senderName,
    String? imageUrl,
    String? link,
    String notificationType = 'room_notification',
    Map<String, String>? additionalData,
  }) async {
    // تنظيف المعرفات
    final cleanSenderId = senderId.replaceAll('"', '').trim();
    final cleanRoomId = roomId.replaceAll('"', '').trim();
    
    developer.log('بدء إرسال إشعار', name: 'RoomNotificationService');
    developer.log('معرف الغرفة (قبل التنظيف): $roomId', name: 'RoomNotificationService');
    developer.log('معرف الغرفة (بعد التنظيف): $cleanRoomId', name: 'RoomNotificationService');
    developer.log('معرف المرسل: $cleanSenderId', name: 'RoomNotificationService');
    
    try {
      final payload = <String, dynamic>{
        'room_id': cleanRoomId,
        'sender_id': cleanSenderId,
      };

      if (title != null && title.trim().isNotEmpty) {
        payload['title'] = title.trim();
      }

      if (body != null && body.trim().isNotEmpty) {
        payload['body'] = body.trim();
      }

      if (senderName != null && senderName.trim().isNotEmpty) {
        payload['sender_name'] = senderName.trim();
      }

      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        payload['image_url'] = imageUrl.trim();
      }

      if (link != null && link.trim().isNotEmpty) {
        payload['link'] = link.trim();
      }

      final cleanType = notificationType.trim().isEmpty
          ? 'room_notification'
          : notificationType.trim();
      payload['type'] = cleanType;

      if (additionalData != null && additionalData.isNotEmpty) {
        payload['additional_data'] = Map<String, String>.fromEntries(
          additionalData.entries.where(
            (entry) => entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty,
          ),
        );
      }

      developer.log('📨 استدعاء وظيفة Supabase مع البيانات: $payload',
          name: 'RoomNotificationService');

      final stopwatch = Stopwatch()..start();
      final response = await Supabase.instance.client.functions.invoke(
        'send-room-notification',
        body: payload,
      );
      stopwatch.stop();

      developer.log('⏱️ تم تنفيذ الوظيفة في ${stopwatch.elapsedMilliseconds} مللي ثانية',
          name: 'RoomNotificationService');

      if (response.status >= 400) {
        developer.log('❌ Supabase function error: status=${response.status} body=${response.data}',
            name: 'RoomNotificationService');
        throw Exception('Failed to send notification (status ${response.status})');
      }

      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          data = {'message': data};
        }
      } else if (data == null) {
        data = const <String, dynamic>{};
      }

      final result = Map<String, dynamic>.from(data as Map? ?? const {});
      developer.log('✅ Notification function result: $result',
          name: 'RoomNotificationService');
      await _cleanupUnregisteredTokens(result);

      return result;
    } on PostgrestException catch (error, stackTrace) {
      developer.log('❌ PostgrestException in sendRoomNotification',
          name: 'RoomNotificationService',
          error: {
            'message': error.message,
            'details': error.details,
            'hint': error.hint,
            'code': error.code,
          },
          stackTrace: stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Error in sendRoomNotification: $e',
          name: 'RoomNotificationService',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }
  
  static Future<void> _cleanupUnregisteredTokens(Map<String, dynamic> result) async {
    try {
      final failures = result['failures'];
      if (failures is! List || failures.isEmpty) {
        return;
      }

      final Set<String> tokensToDelete = {};
      for (final item in failures) {
        if (item is! Map) continue;
        final token = item['token']?.toString();
        if (token == null || token.isEmpty) continue;

        final status = item['status'];
        bool isUnregistered = status == 404;
        final body = item['body'];
        if (body is Map) {
          final error = body['error'];
          if (error is Map) {
            final details = error['details'];
            if (details is List) {
              for (final d in details) {
                if (d is Map) {
                  final code = d['errorCode']?.toString();
                  if (code != null && code.toUpperCase() == 'UNREGISTERED') {
                    isUnregistered = true;
                    break;
                  }
                }
              }
            }
            final message = error['message']?.toString();
            if (message != null && message.contains('Requested entity was not found')) {
              isUnregistered = true;
            }
          }
        }

        if (isUnregistered) {
          tokensToDelete.add(token);
        }
      }

      if (tokensToDelete.isEmpty) {
        return;
      }

      developer.log('Deleting ${tokensToDelete.length} UNREGISTERED tokens',
          name: 'RoomNotificationService');

      final response = await Supabase.instance.client
          .from('user_tokens')
          .delete()
          .inFilter('token', tokensToDelete.toList())
          .select();

      developer.log('Deleted UNREGISTERED tokens result: $response',
          name: 'RoomNotificationService');
    } catch (e, stackTrace) {
      developer.log('Error cleaning up UNREGISTERED tokens',
          name: 'RoomNotificationService', error: e, stackTrace: stackTrace);
    }
  }
}
