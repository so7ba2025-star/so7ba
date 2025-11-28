import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getComments({
    required String postId,
    required int limit,
    required int offset,
  }) async {
    try {
      debugPrint('Fetching comments for post: $postId');

      final response = await _supabase
          .from('comments')
          .select('*')
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      debugPrint('Comments response: $response');

      // Fetch user profiles separately for each comment
      final commentsWithUsers = <Map<String, dynamic>>[];
      for (var comment in response) {
        final userData = await _supabase
            .from('user_profiles')
            .select('nickname, first_name, last_name, avatar_url')
            .eq('id', comment['author_id'])
            .maybeSingle();

        final commentWithUser = {
          ...comment,
          'author_name': _getAuthorName(userData),
          'author_avatar': userData?['avatar_url']?.toString(),
        };
        commentsWithUsers.add(commentWithUser);
      }

      return commentsWithUsers;
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createComment({
    required String postId,
    required String authorId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final payload = {
        'post_id': postId,
        'author_id': authorId,
        'content': content,
        'created_at': now,
        'updated_at': now,
      };

      final response =
          await _supabase.from('comments').insert(payload).select();

      if (response.isEmpty) {
        throw Exception('Failed to create comment');
      }

      // Update post comments count
      await _updatePostCommentsCount(postId);

      // Fetch the new comment with user data
      final userData = await _supabase
          .from('user_profiles')
          .select('nickname, first_name, last_name, avatar_url')
          .eq('id', authorId)
          .maybeSingle();

      final newCommentWithUser = {
        ...response.first,
        'author_name': _getAuthorName(userData),
        'author_avatar': userData?['avatar_url']?.toString(),
      };

      return newCommentWithUser;
    } catch (e) {
      debugPrint('Error creating comment: $e');
      rethrow;
    }
  }

  Future<void> toggleCommentLike({
    required String commentId,
    required String userId,
  }) async {
    try {
      // Check if user already liked the comment
      final existingLike = await _supabase
          .from('comment_likes')
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      debugPrint('🔴 COMMENT LIKE DEBUG: Existing like: $existingLike');

      if (existingLike != null) {
        // Unlike
        debugPrint('🔴 COMMENT LIKE DEBUG: Unliking comment $commentId');
        await _supabase
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);

        // Update likes count manually
        final comment = await _supabase
            .from('comments')
            .select('likes_count')
            .eq('id', commentId)
            .single();

        final currentCount = comment['likes_count'] as int? ?? 0;
        await _supabase
            .from('comments')
            .update({'likes_count': currentCount - 1}).eq('id', commentId);

        debugPrint('🔴 COMMENT LIKE DEBUG: Comment unliked successfully');
      } else {
        // Like
        debugPrint('🔴 COMMENT LIKE DEBUG: Liking comment $commentId');
        await _supabase.from('comment_likes').insert({
          'comment_id': commentId,
          'user_id': userId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        // Update likes count manually
        final comment = await _supabase
            .from('comments')
            .select('likes_count')
            .eq('id', commentId)
            .single();

        final currentCount = comment['likes_count'] as int? ?? 0;
        await _supabase
            .from('comments')
            .update({'likes_count': currentCount + 1}).eq('id', commentId);

        debugPrint('🔴 COMMENT LIKE DEBUG: Comment liked successfully');
      }
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
      rethrow;
    }
  }

  Future<bool> isCommentLiked({
    required String commentId,
    required String userId,
  }) async {
    try {
      final response = await _supabase
          .from('comment_likes')
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking comment like: $e');
      return false;
    }
  }

  Future<void> _updatePostCommentsCount(String postId) async {
    try {
      // Count actual comments for this post
      final countResponse =
          await _supabase.from('comments').select('id').eq('post_id', postId);

      final commentsCount = countResponse.length;

      // Update the post's comments count directly
      await _supabase
          .from('posts')
          .update({'comments_count': commentsCount}).eq('id', postId);

      debugPrint('Updated post $postId comments count to $commentsCount');
    } catch (e) {
      debugPrint('Error updating post comments count: $e');
    }
  }

  String _getAuthorName(Map<String, dynamic>? userData) {
    if (userData == null) return 'Unknown User';

    final nickname = userData['nickname']?.toString() ?? '';
    final firstName = userData['first_name']?.toString() ?? '';
    final lastName = userData['last_name']?.toString() ?? '';

    // Use nickname as primary source, fallback to first_name + last_name
    if (nickname.isNotEmpty) {
      return nickname;
    }

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    }

    return 'Unknown User';
  }
}
