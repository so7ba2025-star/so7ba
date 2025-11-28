import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/comments_service.dart';

class CommentsSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isArabic;

  const CommentsSheet({
    super.key,
    required this.post,
    required this.isArabic,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasReachedEnd = false;
  final CommentsService _commentsService = CommentsService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final User _currentUser = Supabase.instance.client.auth.currentUser!;
  String? _currentUserAvatar;
  bool _isEmojiPickerVisible = false;

  // Common emojis
  final List<String> _commonEmojis = [
    '😀',
    '😂',
    '😍',
    '🤔',
    '😎',
    '😢',
    '😡',
    '👍',
    '👎',
    '❤️',
    '🎉',
    '🔥',
    '💯',
    '😊',
    '🙏',
    '👏',
    '😁',
    '🤗',
    '😮',
    '💪'
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('CommentsSheet initialized for post: ${widget.post['id']}');
    _loadCurrentUserAvatar();
    _loadComments();
  }

  Future<void> _loadCurrentUserAvatar() async {
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('avatar_url')
          .eq('id', _currentUser.id)
          .single();

      setState(() {
        _currentUserAvatar = response['avatar_url']?.toString();
      });
      debugPrint(
          '🔴 COMMENTS DEBUG: Current user avatar from user_profiles: $_currentUserAvatar');
    } catch (e) {
      debugPrint('Error loading current user avatar: $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final comments = await _commentsService.getComments(
        postId: widget.post['id'],
        limit: 20,
        offset: 0,
      );

      debugPrint('🔴 COMMENTS DEBUG: Fetched ${comments.length} comments');
      for (var comment in comments) {
        debugPrint(
            '🔴 COMMENTS DEBUG: Comment - ${comment['id']} - ${comment['author_name']} - ${comment['content']}');
      }

      setState(() {
        _comments = comments;
        _isLoading = false;
        _hasReachedEnd = comments.length < 20;
      });

      debugPrint('Loaded ${comments.length} comments');
    } catch (e) {
      debugPrint('Error loading comments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newComment = await _commentsService.createComment(
        postId: widget.post['id'],
        authorId: _currentUser.id,
        content: content,
      );

      _commentController.clear();

      // Add the new comment directly to the list instead of reloading
      setState(() {
        _comments.insert(0, newComment);
        _isLoading = false;
      });

      // Update post comments count in background
      _updatePostCommentsCount(widget.post['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isArabic ? 'تم إضافة التعليق' : 'Comment added',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting comment: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isArabic
                  ? 'فشل في إضافة التعليق'
                  : 'Failed to add comment',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleCommentLike(String commentId, int currentIndex) async {
    try {
      await _commentsService.toggleCommentLike(
        commentId: commentId,
        userId: _currentUser.id,
      );

      setState(() {
        final comment = _comments[currentIndex];
        final isLiked = comment['is_liked'] as bool;
        final likesCount = comment['likes_count'] as int;

        _comments[currentIndex] = {
          ...comment,
          'is_liked': !isLiked,
          'likes_count': isLiked ? likesCount - 1 : likesCount + 1,
        };
      });
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
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

  void _toggleEmojiPicker() {
    // Close keyboard when opening emoji picker
    FocusScope.of(context).unfocus();

    setState(() {
      _isEmojiPickerVisible = !_isEmojiPickerVisible;
    });
  }

  void _insertEmoji(String emoji) {
    final text = _commentController.text;
    final cursorPosition = _commentController.selection.baseOffset;

    // Handle invalid cursor position
    final safeCursorPosition =
        cursorPosition < 0 ? text.length : cursorPosition;
    final newText = text.substring(0, safeCursorPosition) +
        emoji +
        text.substring(safeCursorPosition);

    _commentController.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: safeCursorPosition + emoji.length),
    );

    setState(() {
      _isEmojiPickerVisible = false;
    });
  }

  Widget _buildEmojiPicker() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // Hide emoji picker when keyboard is open
    if (!_isEmojiPickerVisible || keyboardHeight > 0) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          childAspectRatio: 1,
        ),
        itemCount: _commonEmojis.length,
        itemBuilder: (context, index) {
          final emoji = _commonEmojis[index];
          return GestureDetector(
            onTap: () => _insertEmoji(emoji),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! > 50) {
          // Swiping down with threshold
          Navigator.of(context).pop();
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    widget.isArabic ? 'التعليقات' : 'Comments',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Comments list
            Expanded(
              child: Container(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _comments.length + (_hasReachedEnd ? 0 : 1),
                        itemBuilder: (context, index) {
                          if (index == _comments.length) {
                            // Load more indicator
                            return _isLoadingMore
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  )
                                : const SizedBox.shrink();
                          }

                          final comment = _comments[index];
                          return _CommentWidget(
                            comment: comment,
                            isArabic: widget.isArabic,
                            onLike: () => _toggleCommentLike(
                                comment['id'].toString(), index),
                          );
                        },
                      ),
              ),
            ),

            // Comment input - always visible at bottom
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + keyboardHeight,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: _currentUserAvatar ??
                            _currentUser.userMetadata?['avatar_url']
                                ?.toString() ??
                            'https://picsum.photos/seed/currentuser/40/40',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Icon(
                          Icons.person,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: widget.isArabic
                            ? 'اكتب تعليق...'
                            : 'Write a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _toggleEmojiPicker,
                    icon: const Icon(Icons.emoji_emotions_outlined,
                        color: Colors.grey),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : _submitComment,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.blue),
                          )
                        : const Icon(Icons.send, color: Colors.blue),
                  ),
                ],
              ),
            ),

            // Emoji picker
            _buildEmojiPicker(),
          ],
        ),
      ),
    );
  }
}

class _CommentWidget extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isArabic;
  final VoidCallback? onLike;

  const _CommentWidget({
    required this.comment,
    required this.isArabic,
    this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: comment['author_avatar'] ??
                    'https://picsum.photos/seed/avatar/40/40',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Icon(
                  Icons.person,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author name and time
                Row(
                  children: [
                    Text(
                      comment['author_name'] ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment['created_at']),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Comment text
                Text(
                  comment['content'] ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 8),

                // Actions
                Row(
                  children: [
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            comment['is_liked'] == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: comment['is_liked'] == true
                                ? Colors.red
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment['likes_count'] ?? 0}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        // TODO: Handle reply
                      },
                      child: Text(
                        isArabic ? 'رد' : 'Reply',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';

    final dateTime = DateTime.tryParse(createdAt);
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return isArabic ? 'الآن' : 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${isArabic ? 'دقيقة' : 'm'}';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${isArabic ? 'ساعة' : 'h'}';
    } else {
      return '${difference.inDays} ${isArabic ? 'يوم' : 'd'}';
    }
  }
}
