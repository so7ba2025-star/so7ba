import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> uploadImageFromMobile({
    required ImageSource source,
    Function(double)? onProgress,
  }) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image == null) return null;

      final File imageFile = File(image.path);
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload to Supabase storage
      final String? imageUrl = await _supabase.storage
          .from('post-images')
          .upload(fileName, imageFile);

      if (imageUrl != null) {
        // Get public URL
        final publicUrl = _supabase.storage
            .from('post-images')
            .getPublicUrl(fileName);
        return publicUrl;
      }
      
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<String?> uploadMediaFromMobile({
    required bool isVideo,
    Function(double)? onProgress,
  }) async {
    try {
      final picker = ImagePicker();
      XFile? media;
      
      if (isVideo) {
        media = await picker.pickVideo(source: ImageSource.gallery);
      } else {
        media = await picker.pickImage(source: ImageSource.gallery);
      }
      
      if (media == null) return null;

      final File mediaFile = File(media.path);
      final String extension = isVideo ? 'mp4' : 'jpg';
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final String bucket = isVideo ? 'post-videos' : 'post-images';
      
      // Upload to Supabase storage
      final String? uploadedUrl = await _supabase.storage
          .from(bucket)
          .upload(fileName, mediaFile);

      if (uploadedUrl != null) {
        // Get public URL
        final publicUrl = _supabase.storage
            .from(bucket)
            .getPublicUrl(fileName);
        return publicUrl;
      }
      
      return null;
    } catch (e) {
      print('Error uploading media: $e');
      return null;
    }
  }

  Future<String?> uploadVideoFromMobile({
    required ImageSource source,
    Function(double)? onProgress,
  }) async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: source);
      
      if (video == null) return null;

      final File videoFile = File(video.path);
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      // Upload to Supabase storage
      final String? videoUrl = await _supabase.storage
          .from('post-videos')
          .upload(fileName, videoFile);

      if (videoUrl != null) {
        // Get public URL
        final publicUrl = _supabase.storage
            .from('post-videos')
            .getPublicUrl(fileName);
        return publicUrl;
      }
      
      return null;
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }
}
