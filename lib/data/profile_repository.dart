import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // جلب بيانات الملف الشخصي
  Future<Map<String, dynamic>> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') { // No rows returned
        // إنشاء ملف شخصي جديد إذا لم يتم العثور على ملف
        await _supabase.from('user_profiles').insert({
          'id': userId,
          'is_active': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        return {'id': userId};
      }
      print('Error fetching profile: $e');
      rethrow;
    } catch (e) {
      print('Unexpected error: $e');
      rethrow;
    }
  }

  // تحديث بيانات الملف الشخصي
  Future<void> updateProfile({
    required String userId,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final data = {
        'id': userId,
        ...profileData,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('user_profiles').upsert(data);
    } catch (e) {
      // Fallback: إذا كان هناك اختلاف في اسم عمود الهاتف بين phone و phone_number
      if (e is PostgrestException) {
        final message = e.message ?? e.code ?? e.toString();
        final hasPhoneNumber = profileData.containsKey('phone_number');
        final hasPhone = profileData.containsKey('phone');

        try {
          if (message.contains('phone_number') && hasPhoneNumber) {
            final fallback = Map<String, dynamic>.from(profileData);
            fallback.remove('phone_number');
            fallback['phone'] = profileData['phone_number'];
            await _supabase.from('user_profiles').upsert({
              'id': userId,
              ...fallback,
              'updated_at': DateTime.now().toIso8601String(),
            });
            return;
          }
          if (message.contains('phone"') && hasPhone) {
            final fallback = Map<String, dynamic>.from(profileData);
            fallback.remove('phone');
            fallback['phone_number'] = profileData['phone'];
            await _supabase.from('user_profiles').upsert({
              'id': userId,
              ...fallback,
              'updated_at': DateTime.now().toIso8601String(),
            });
            return;
          }
        } catch (inner) {
          print('Fallback update failed: $inner');
          rethrow;
        }
      }
      print('Error updating profile: $e');
      rethrow;
    }
  }

  // رفع صورة الملف الشخصي
  Future<String> uploadProfileImage(String userId, String filePath) async {
    try {
      final file = File(filePath);
      final fileExt = filePath.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final storagePath = 'profiles/$userId/$fileName';

      await _supabase.storage
          .from('avatars')
          .upload(storagePath, file);

      final response = _supabase.storage
          .from('avatars')
          .getPublicUrl(storagePath);
          
      _debugPrint('Image uploaded successfully. Public URL: $response');
      return response;
    } on StorageException catch (e) {
      _debugPrint('Storage error: ${e.message}');
      rethrow;
    } catch (e) {
      _debugPrint('Error uploading profile image: $e');
      rethrow;
    }
  }
  
  void _debugPrint(String message) {
    if (kDebugMode) {
      print('[ProfileRepository] $message');
    }
  }
}
