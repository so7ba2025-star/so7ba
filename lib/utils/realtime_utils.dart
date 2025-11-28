import 'package:supabase_flutter/supabase_flutter.dart';

extension RealtimeChannelExt on RealtimeChannel {
  /// Sends a broadcast message through the channel (wrapper around sendBroadcastMessage)
  Future<ChannelResponse> broadcastMessage({
    required String event,
    required Map<String, dynamic> payload,
  }) {
    return sendBroadcastMessage(event: event, payload: payload);
  }
}
