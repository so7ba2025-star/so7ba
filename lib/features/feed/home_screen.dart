import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'services/feed_service.dart';
import 'widgets/smart_post_card.dart';
import 'widgets/context_switcher.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/caught_up_widget.dart';
import '../../core/lang.dart';
import '../../core/services/image_upload_service.dart';
import '../settings/settings_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

enum FeedMode { all, learn, work, connect, chill }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FeedMode _currentMode = FeedMode.all;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _hasReachedEnd = false;
  final ScrollController _scrollController = ScrollController();
  final FeedService _feedService = FeedService();
  Map<String, dynamic>? _currentUserProfile;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _loadCurrentUserProfile();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final response = await Supabase.instance.client
            .from('user_profiles')
            .select('id, nickname, first_name, last_name, avatar_url, role')
            .eq('id', currentUser.id)
            .single();

        setState(() {
          _currentUserProfile = response;
        });
      }
    } catch (e) {
      debugPrint('Error loading current user profile: $e');
    }
  }

  Future<void> _onRefresh() async {
    await _refreshFeed();
  }

  void _handleNavTap(int index) {
    // Navigation is now handled by TabBarView, no need for manual navigation
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _hasReachedEnd = false;
    });

    debugPrint('=== HOME SCREEN LOAD FEED ===');
    debugPrint('Current Mode: $_currentMode');

    try {
      final posts = await _feedService.getFeedPosts(
        mode: _currentMode,
        limit: 10,
        offset: 0,
      );

      setState(() {
        _posts = posts;
        _isLoading = false;
      });

      // Debug print to check posts
      debugPrint('=== LOADED POSTS ===');
      debugPrint('Loaded ${posts.length} posts for mode: $_currentMode');
      for (var post in posts) {
        debugPrint(
            'Post: ${post['id']} - ${post['author_name']} - mode: ${post['post_mode']}');
      }
      debugPrint('=== END POSTS ===');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading feed: $e');
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || _hasReachedEnd) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final morePosts = await _feedService.getFeedPosts(
        mode: _currentMode,
        limit: 10,
        offset: _posts.length,
      );

      setState(() {
        _posts.addAll(morePosts);
        _isLoading = false;
        _hasReachedEnd = morePosts.isEmpty;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading more posts: $e');
    }
  }

  void _onModeChanged(FeedMode newMode) {
    if (_currentMode != newMode) {
      setState(() {
        _currentMode = newMode;
      });
      _loadFeed();
    }
  }

  Future<void> _handlePostLike(Map<String, dynamic> post) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        print('No current user');
        return;
      }

      final postId = post['id']; // Keep as UUID, don't convert to string
      final userId = currentUser.id;

      print('Handling like - postId: $postId, userId: $userId');

      // Check if user already reacted to the post
      final existingReaction = await Supabase.instance.client
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      print('Existing reaction: $existingReaction');

      if (existingReaction != null) {
        // Remove reaction
        print('Removing reaction...');
        await Supabase.instance.client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);

        // Update likes count
        final currentCount = post['likes_count'] ?? 0;
        final newCount = currentCount > 0 ? currentCount - 1 : 0;

        await Supabase.instance.client.from('posts').update(
            {'likes_count': newCount, 'reaction_type': null}).eq('id', postId);

        print('Reaction removed');
      } else {
        // Add reaction (default to 'like' for now)
        print('Adding reaction...');
        try {
          await Supabase.instance.client.from('post_likes').insert({
            'post_id': postId,
            'user_id': userId,
            'reaction_type': 'like',
          });
          print('Insert successful');
        } catch (e) {
          print('Insert error: $e');
          // Try without reaction_type as fallback
          await Supabase.instance.client.from('post_likes').insert({
            'post_id': postId,
            'user_id': userId,
          });
          print('Insert without reaction_type successful');
        }

        // Update likes count and reaction type
        await Supabase.instance.client.from('posts').update({
          'likes_count': (post['likes_count'] ?? 0) + 1,
          'reaction_type': 'like'
        }).eq('id', postId);

        print('Reaction added');
      }

      // Refresh feed to update UI
      await _refreshFeed();
    } catch (e) {
      debugPrint('Error handling post like: $e');
    }
  }

  Future<void> _handlePostSave(Map<String, dynamic> post) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final postId = post['id'].toString();
      final userId = currentUser.id;

      // Check if user already saved the post
      final existingSave = await Supabase.instance.client
          .from('saved_posts')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingSave == null) {
        // Add save record
        await Supabase.instance.client.from('saved_posts').insert({
          'post_id': postId,
          'user_id': userId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        // Update saved count
        await Supabase.instance.client.from('posts').update(
            {'saved_count': (post['saved_count'] ?? 0) + 1}).eq('id', postId);

        // No snackbar message
      } else {
        // Remove save record
        await Supabase.instance.client
            .from('saved_posts')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);

        // Update saved count
        await Supabase.instance.client.from('posts').update(
            {'saved_count': (post['saved_count'] ?? 0) - 1}).eq('id', postId);

        // No snackbar message
      }

      // Update UI immediately without full refresh
      setState(() {
        // Find and update the post in the current list
        final postIndex =
            _posts.indexWhere((p) => p['id'].toString() == postId);
        if (postIndex != -1) {
          final currentSaved = _posts[postIndex]['is_saved'] ?? false;
          debugPrint(
              '🔴 HOME DEBUG: Post $postId - _isSaved before: $currentSaved');

          _posts[postIndex]['is_saved'] = !currentSaved;
          debugPrint(
              '🔴 HOME DEBUG: Post $postId - _isSaved after: ${_posts[postIndex]['is_saved']}');

          // Update saved count
          if (currentSaved) {
            _posts[postIndex]['saved_count'] =
                (_posts[postIndex]['saved_count'] ?? 0) - 1;
          } else {
            _posts[postIndex]['saved_count'] =
                (_posts[postIndex]['saved_count'] ?? 0) + 1;
          }
        } else {
          debugPrint('🔴 HOME DEBUG: Post $postId not found in _posts array');
        }
      });
    } catch (e) {
      debugPrint('Error handling post save: $e');
    }
  }

  Future<void> _handlePostShare(Map<String, dynamic> post) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final postId = post['id'].toString();
      final userId = currentUser.id;

      // Check if user already shared the post
      final existingShare = await Supabase.instance.client
          .from('post_shares')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingShare == null) {
        // Add share record
        await Supabase.instance.client.from('post_shares').insert({
          'post_id': postId,
          'user_id': userId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        // Update shares count
        await Supabase.instance.client.from('posts').update(
            {'shares_count': (post['shares_count'] ?? 0) + 1}).eq('id', postId);

        // Show share options
        _showShareOptions(post);
      } else {
        // Already shared, just show share options
        _showShareOptions(post);
      }

      // Refresh feed to update UI
      await _refreshFeed();
    } catch (e) {
      debugPrint('Error handling post share: $e');
    }
  }

  void _showShareOptions(Map<String, dynamic> post) {
    final isArabic =
        Provider.of<LanguageController>(context, listen: false).isArabic.value;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isArabic ? 'مشاركة البوست' : 'Share Post',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.link, color: Colors.blue),
              title: Text(isArabic ? 'نسخ الرابط' : 'Copy Link'),
              onTap: () {
                Navigator.pop(context);
                _copyPostLink(post, isArabic);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: Colors.green),
              title: Text(isArabic ? 'مشاركة خارجية' : 'Share Externally'),
              onTap: () {
                Navigator.pop(context);
                _shareExternally(post, isArabic);
              },
            ),
            ListTile(
              leading: Icon(Icons.message, color: Colors.purple),
              title: Text(isArabic ? 'إرسال لصديق' : 'Send to Friend'),
              onTap: () {
                Navigator.pop(context);
                _sendToFriend(post, isArabic);
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _copyPostLink(Map<String, dynamic> post, bool isArabic) async {
    try {
      final postLink = 'https://hesabi.app/post/${post['id']}';
      // In a real app, you would use flutter/services to copy to clipboard
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تم نسخ الرابط' : 'Link copied!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error copying link: $e');
    }
  }

  Future<void> _shareExternally(
      Map<String, dynamic> post, bool isArabic) async {
    try {
      final content = post['content'] ?? '';
      final author = post['author_name'] ?? 'Someone';
      final shareText = '$author: $content';

      // In a real app, you would use share_plus package
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'جاري المشاركة...' : 'Sharing...'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      debugPrint('Error sharing externally: $e');
    }
  }

  Future<void> _sendToFriend(Map<String, dynamic> post, bool isArabic) async {
    try {
      // In a real app, you would navigate to friends selection or chat
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isArabic ? 'اختر صديق للمشاركة' : 'Select a friend to share'),
          backgroundColor: Colors.purple,
        ),
      );
    } catch (e) {
      debugPrint('Error sending to friend: $e');
    }
  }

  void _markPostAsRead(String postId) {
    setState(() {
      final postIndex = _posts.indexWhere((post) => post['id'] == postId);
      if (postIndex != -1) {
        _posts[postIndex]['is_read'] = true;
      }
    });
  }

  Future<void> _refreshFeed() async {
    debugPrint('[Feed] Refreshing feed...');
    await _loadFeed();
    debugPrint('[Feed] Feed refreshed. Posts count: ${_posts.length}');
  }

  Future<void> _showCreatePostSheet({
    required bool isArabic,
    required User user,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: _CreatePostSheet(
            isArabic: isArabic,
            initialMode: _currentMode,
            feedService: _feedService,
            authorId: user.id,
            authorEmail: user.email,
            userMetadata: (user.userMetadata as Map<String, dynamic>?) ?? {},
          ),
        );
      },
    );

    if (result == true) {
      debugPrint('[Feed] Post published successfully, refreshing feed...');
      await _refreshFeed();
      if (!mounted) return;
      final message =
          isArabic ? 'تم نشر البوست بنجاح' : 'Post published successfully';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else {
      debugPrint('[Feed] Post publish cancelled or failed');
    }
  }

  Future<void> _showCommentsBottomSheet(
      BuildContext context, Map<String, dynamic> post, bool isArabic) async {
    try {
      print('Opening comments for post: ${post['id']}');

      // Refresh the feed when comments sheet is opened to get latest comments count
      await _refreshFeed();

      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => CommentsSheet(post: post, isArabic: isArabic),
      );

      // Refresh feed again when comments sheet is closed to update comments count
      if (result != false) {
        await _refreshFeed();
      }
    } catch (e) {
      print('Error showing comments sheet: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isArabic ? 'حدث خطأ في فتح التعليقات' : 'Error opening comments'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageController>(
      builder: (context, languageController, child) {
        final isArabic = languageController.isArabic.value;
        final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;

        return Directionality(
          textDirection: textDirection,
          child: Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 56,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF880404),
                      Color(0xFFC20202),
                    ],
                  ),
                ),
              ),
              title: const Text(
                'صحبة',
                style: TextStyle(
                  color: Color(0xFFF5E9D7),
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFFF5E9D7)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _SearchScreen(isArabic: isArabic),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Color(0xFFF5E9D7)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            _NotificationsScreen(isArabic: isArabic),
                      ),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFFF5E9D7)),
                  onSelected: (value) {
                    switch (value) {
                      case 'settings':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsPage()),
                        );
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem<String>(
                        value: 'settings',
                        child: Row(
                          children: [
                            const Icon(Icons.settings, size: 20),
                            const SizedBox(width: 8),
                            Text(isArabic ? 'الإعدادات' : 'Settings'),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: _onRefresh,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Normal Header with Create Post Area and Category Tabs (not sticky)
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Create Post Area
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: NetworkImage(
                                  _currentUserProfile?['avatar_url'] ??
                                      Supabase.instance.client.auth.currentUser
                                          ?.userMetadata?['avatar_url'] ??
                                      'https://via.placeholder.com/48',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    final user = Supabase
                                        .instance.client.auth.currentUser;
                                    if (user == null) {
                                      final message = isArabic
                                          ? 'يجب تسجيل الدخول لإضافة بوست'
                                          : 'Please sign in to add a post';
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(message)),
                                      );
                                      return;
                                    }
                                    _showCreatePostSheet(
                                        isArabic: isArabic, user: user);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Text(
                                      isArabic
                                          ? 'اكتب شيئاً...'
                                          : 'Write something...',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  final user =
                                      Supabase.instance.client.auth.currentUser;
                                  if (user == null) {
                                    final message = isArabic
                                        ? 'يجب تسجيل الدخول لإضافة بوست'
                                        : 'Please sign in to add a post';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                    return;
                                  }
                                  // Open create post sheet with image pre-selected
                                  _showCreatePostSheet(
                                      isArabic: isArabic, user: user);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.photo_outlined,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Context Switcher
                        ContextSwitcher(
                          currentMode: _currentMode,
                          onModeChanged: _onModeChanged,
                          isArabic: isArabic,
                        ),
                      ],
                    ),
                  ),

                  // Feed Content
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= _posts.length) {
                          if (_hasReachedEnd && _posts.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: CaughtUpWidget(isArabic: isArabic),
                            );
                          }
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final post = _posts[index];
                        // Add category indicator for "All" mode
                        final updatedPost = Map<String, dynamic>.from(post);
                        if (_currentMode == FeedMode.all) {
                          updatedPost['show_category'] = true;
                        }

                        return SmartPostCard(
                          post: updatedPost,
                          isArabic: isArabic,
                          onTap: () => _markPostAsRead(post['id'].toString()),
                          onLike: () => _handlePostLike(post),
                          onComment: () =>
                              _showCommentsBottomSheet(context, post, isArabic),
                          onShare: () => _handlePostShare(post),
                          onSave: () => _handlePostSave(post),
                        );
                      },
                      childCount: _posts.length + (_hasReachedEnd ? 1 : 0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedContent(bool isArabic) {
    if (_isLoading && _posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_posts.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.feed_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'لا توجد منشورات حالياً' : 'No posts available',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'جرب تغيير الوضع أو قم بتحديث الصفحة'
                  : 'Try changing modes or refresh the page',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        debugPrint('Screen width: ${constraints.maxWidth}');

        // Use screen width from MediaQuery for more accurate detection
        final screenWidth = MediaQuery.of(context).size.width;
        debugPrint('MediaQuery width: $screenWidth');

        if (screenWidth >= 1200) {
          // Large Desktop Layout - 3 columns
          return _buildDesktopLayout(isArabic);
        } else if (screenWidth >= 1024) {
          // Desktop Layout - 2 columns
          return _buildTabletLayout(isArabic);
        } else if (screenWidth >= 600) {
          // Tablet Layout - 2 columns
          return _buildTabletLayout(isArabic);
        } else {
          // Mobile Layout - 1 column
          return _buildMobileLayout(isArabic);
        }
      },
    );
  }

  Widget _buildDesktopLayout(bool isArabic) {
    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar (20%)
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: _buildLeftSidebar(isArabic),
            ),
          ),

          // Main Feed (60%)
          Expanded(
            flex: 6,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 900, // Limit main feed width
              ),
              child: _buildMainFeed(isArabic),
            ),
          ),

          // Right Sidebar (20%)
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: _buildRightSidebar(isArabic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(bool isArabic) {
    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar (25%)
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: _buildLeftSidebar(isArabic),
            ),
          ),

          // Main Feed (75%)
          Expanded(
            flex: 3,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 800, // Limit main feed width
              ),
              child: _buildMainFeed(isArabic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(bool isArabic) {
    return _buildMainFeed(isArabic);
  }

  Widget _buildMainFeed(bool isArabic) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Normal Header with Create Post Area and Category Tabs (not sticky)
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Create Post Area
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(
                          Supabase.instance.client.auth.currentUser
                                  ?.userMetadata?['avatar_url'] ??
                              'https://via.placeholder.com/48',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final user =
                                Supabase.instance.client.auth.currentUser;
                            if (user == null) {
                              final message = isArabic
                                  ? 'يجب تسجيل الدخول لإضافة بوست'
                                  : 'Please sign in to add a post';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                              return;
                            }
                            _showCreatePostSheet(
                                isArabic: isArabic, user: user);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Text(
                              isArabic ? 'اكتب شيئاً...' : 'Write something...',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final user =
                              Supabase.instance.client.auth.currentUser;
                          if (user == null) {
                            final message = isArabic
                                ? 'يجب تسجيل الدخول لإضافة بوست'
                                : 'Please sign in to add a post';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                            return;
                          }
                          // Open create post sheet with image pre-selected
                          _showCreatePostSheet(isArabic: isArabic, user: user);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.photo_outlined,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Context Switcher
                ContextSwitcher(
                  currentMode: _currentMode,
                  onModeChanged: _onModeChanged,
                  isArabic: isArabic,
                ),
              ],
            ),
          ),

          // Feed Content
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= _posts.length) {
                  if (_hasReachedEnd && _posts.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: CaughtUpWidget(isArabic: isArabic),
                    );
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final post = _posts[index];
                // Add category indicator for "All" mode
                final updatedPost = Map<String, dynamic>.from(post);
                updatedPost['show_category'] = _currentMode == FeedMode.all;

                return SmartPostCard(
                  post: updatedPost,
                  isArabic: isArabic,
                  onTap: () {
                    // Mark post as read when tapped
                    _markPostAsRead(post['id']);
                  },
                  onLike: () async {
                    await _handlePostLike(post);
                  },
                  onComment: () {
                    _showCommentsBottomSheet(context, post, isArabic);
                  },
                  onSave: () async {
                    await _handlePostSave(post);
                  },
                  onShare: () async {
                    await _handlePostShare(post);
                  },
                );
              },
              childCount: _posts.length + (_hasReachedEnd ? 1 : 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar(bool isArabic) {
    return Column(
      children: [
        // User Profile Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: NetworkImage(
                    Supabase.instance.client.auth.currentUser
                            ?.userMetadata?['avatar_url'] ??
                        'https://via.placeholder.com/64',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  (Supabase.instance.client.auth.currentUser
                          ?.userMetadata?['full_name'] ??
                      (isArabic ? 'المستخدم' : 'User')) as String,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Supabase.instance.client.auth.currentUser?.email ?? '',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Quick Actions
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.bookmark_border),
                title: Text(isArabic ? 'المحفوظات' : 'Saved Items'),
                onTap: () {
                  // TODO: Navigate to saved items
                },
              ),
              ListTile(
                leading: Icon(Icons.analytics_outlined),
                title: Text(isArabic ? 'التحليلات' : 'Analytics'),
                onTap: () {
                  // TODO: Navigate to analytics
                },
              ),
              ListTile(
                leading: Icon(Icons.message_outlined),
                title: Text(isArabic ? 'الرسائل' : 'Messages'),
                onTap: () {
                  // TODO: Navigate to messages
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightSidebar(bool isArabic) {
    return Column(
      children: [
        // Trending Topics
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'الترندات' : 'Trending',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTrendingItem('Flutter Development', '142 posts'),
                _buildTrendingItem('UI/UX Design', '89 posts'),
                _buildTrendingItem('Mobile Apps', '67 posts'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Suggested Connections
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'اقتراحات' : 'Suggestions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSuggestionItem('Ahmed Mohamed', 'Flutter Developer'),
                _buildSuggestionItem('Sarah Ali', 'UI Designer'),
                _buildSuggestionItem('Mohamed Hassan', 'Product Manager'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingItem(String topic, String count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              topic,
              style: TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String name, String role) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage('https://via.placeholder.com/40'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline),
            onPressed: () {
              // TODO: Handle follow/connect
            },
          ),
        ],
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet({
    required this.isArabic,
    required this.initialMode,
    required this.feedService,
    required this.authorId,
    required this.authorEmail,
    required this.userMetadata,
  });

  final bool isArabic;
  final FeedMode initialMode;
  final FeedService feedService;
  final String authorId;
  final String? authorEmail;
  final Map<String, dynamic> userMetadata;

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  bool _isSubmitting = false;
  bool _isPinned = false;
  late FeedMode _selectedMode;
  String _contentType = 'text';
  final ImageUploadService _imageUploadService = ImageUploadService();
  String? _uploadedImageUrl;
  String? _uploadedVideoUrl;
  bool _isUploadingImage = false;
  bool _isUploadingVideo = false;
  double _imageUploadProgress = 0.0;
  double _videoUploadProgress = 0.0;
  Map<String, dynamic>? _userData;
  bool _showEmojiPicker = false;

  // List of common emojis
  static const List<String> _commonEmojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '🤣',
    '😂',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '🤩',
    '😘',
    '😗',
    '😚',
    '😙',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '🤐',
    '🤨',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '🤥',
    '😌',
    '😔',
    '😪',
    '🤤',
    '😴',
    '😷',
    '🤒',
    '🤕',
    '🤢',
    '🤮',
    '🥵',
    '🥶',
    '🥴',
    '😵',
    '🤯',
    '🤠',
    '🥳',
    '😎',
    '🤓',
    '🧐',
    '😕',
    '😟',
    '🙁',
    '☹️',
    '😮',
    '😯',
    '😲',
    '😳',
    '🥺',
    '😦',
    '😧',
    '😨',
    '😰',
    '😥',
    '😢',
    '😭',
    '😱',
    '😖',
    '😣',
    '😞',
    '😓',
    '😩',
    '😫',
    '🥱',
    '😤',
    '😡',
    '😠',
    '🤬',
    '😈',
    '👿',
    '💀',
    '☠️',
    '💩',
    '🤡',
    '👹',
    '👺',
    '👻',
    '👽',
    '👾',
    '🤖',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🤎',
    '💔',
    '❣️',
    '💕',
    '💞',
    '💓',
    '💗',
    '💖',
    '💘',
    '💝',
    '👍',
    '👎',
    '👌',
    '✌️',
    '🤞',
    '🤟',
    '🤘',
    '🤙',
    '👈',
    '👉',
    '👆',
    '👇',
    '☝️',
    '✋',
    '🤚',
    '🖐️',
    '🖖',
    '👋',
    '🤏',
    '✊',
    '👊',
    '🤛',
    '🔥',
    '💯',
    '🎉',
    '🎊',
    '🎈',
    '🎁',
    '🎀',
    '🎗️',
    '🎟️',
    '🎫',
    '🌟',
    '⭐',
    '✨',
    '💫',
    '☀️',
    '🌤️',
    '⛅',
    '🌥️',
    '☁️',
    '🌦️',
    '🌧️',
    '⛈️',
    '🌩️',
    '🌨️',
    '❄️',
    '☃️',
    '⛄',
    '🌬️',
    '💨',
    '🌪️',
  ];

  void _insertEmoji(String emoji) {
    final currentText = _contentController.text;
    final cursorPosition = _contentController.selection.baseOffset > 0
        ? _contentController.selection.baseOffset
        : currentText.length;
    final textBefore = currentText.substring(0, cursorPosition);
    final textAfter = currentText.substring(cursorPosition);

    _contentController.text = textBefore + emoji + textAfter;
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: cursorPosition + emoji.length),
    );

    setState(() {
      _showEmojiPicker = false;
    });

    // Keep focus on the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    _loadUserData();
    debugPrint('[CreatePost] Initial content type=$_contentType');
  }

  Future<void> _loadUserData() async {
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('id', widget.authorId)
          .single();

      setState(() {
        _userData = response;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _imageUrlController.dispose();
    _videoUrlController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromCamera() async {
    setState(() {
      _isUploadingImage = true;
      _imageUploadProgress = 0.0;
    });

    final imageUrl = await _imageUploadService.uploadImageFromMobile(
      source: ImageSource.camera,
      onProgress: (progress) {
        setState(() {
          _imageUploadProgress = progress;
        });
      },
    );

    setState(() {
      _isUploadingImage = false;
      _uploadedImageUrl = imageUrl;
      if (imageUrl != null) {
        _contentType = 'image';
        _imageUrlController.text = imageUrl;
        debugPrint('[CreatePost] Image uploaded successfully: $imageUrl');
      } else {
        debugPrint('[CreatePost] Image upload failed');
      }
    });

    if (imageUrl != null) {
      setState(() {
        _contentType = 'image';
        _imageUrlController.text = imageUrl;
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    setState(() {
      _isUploadingImage = true;
      _imageUploadProgress = 0.0;
    });

    final imageUrl = await _imageUploadService.uploadImageFromMobile(
      source: ImageSource.gallery,
      onProgress: (progress) {
        setState(() {
          _imageUploadProgress = progress;
        });
      },
    );

    setState(() {
      _isUploadingImage = false;
      _uploadedImageUrl = imageUrl;
      if (imageUrl != null) {
        _contentType = 'image';
        _imageUrlController.text = imageUrl;
        debugPrint('[CreatePost] Image uploaded successfully: $imageUrl');
      } else {
        debugPrint('[CreatePost] Image upload failed');
      }
    });
  }

  Future<void> _pickImageFromDesktop() async {
    setState(() {
      _isUploadingImage = true;
      _imageUploadProgress = 0.0;
    });

    final imageUrl = await _imageUploadService.uploadMediaFromMobile(
      isVideo: false,
      onProgress: (progress) {
        setState(() {
          _imageUploadProgress = progress;
        });
      },
    );

    setState(() {
      _isUploadingImage = false;
      _uploadedImageUrl = imageUrl;
      if (imageUrl != null) {
        _contentType = 'image';
        _imageUrlController.text = imageUrl;
        debugPrint('[CreatePost] Image uploaded successfully: $imageUrl');
      } else {
        debugPrint('[CreatePost] Image upload failed');
      }
    });
  }

  void _showMediaSourceOptions({required bool isVideo}) {
    final isArabic = widget.isArabic;
    final title = isVideo
        ? (isArabic ? 'اختر مصدر الفيديو' : 'Choose Video Source')
        : (isArabic ? 'اختر مصدر الصورة' : 'Choose Image Source');

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            if (!kIsWeb)
              ListTile(
                leading: Icon(isVideo ? Icons.videocam : Icons.camera_alt,
                    color: Colors.blue),
                title: Text(isArabic ? 'الكاميرا' : 'Camera'),
                onTap: () {
                  Navigator.pop(context);
                  if (isVideo) {
                    _pickVideoFromCamera();
                  } else {
                    _pickImageFromCamera();
                  }
                },
              ),
            ListTile(
              leading: Icon(isVideo ? Icons.video_library : Icons.photo_library,
                  color: Colors.green),
              title: Text(isArabic ? 'المعرض' : 'Gallery'),
              onTap: () {
                Navigator.pop(context);
                if (kIsWeb ||
                    Platform.isWindows ||
                    Platform.isMacOS ||
                    Platform.isLinux) {
                  if (isVideo) {
                    _pickVideoFromDesktop();
                  } else {
                    _pickImageFromDesktop();
                  }
                } else {
                  if (isVideo) {
                    _pickVideoFromGallery();
                  } else {
                    _pickImageFromGallery();
                  }
                }
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideoFromCamera() async {
    setState(() {
      _isUploadingVideo = true;
      _videoUploadProgress = 0.0;
    });

    final videoUrl = await _imageUploadService.uploadVideoFromMobile(
      source: ImageSource.camera,
      onProgress: (progress) {
        setState(() {
          _videoUploadProgress = progress;
        });
      },
    );

    setState(() {
      _isUploadingVideo = false;
      _uploadedVideoUrl = videoUrl;
      if (videoUrl != null) {
        _contentType = 'video';
        _videoUrlController.text = videoUrl;
      }
    });
  }

  Future<void> _pickVideoFromGallery() async {
    setState(() {
      _isUploadingVideo = true;
      _videoUploadProgress = 0.0;
    });

    try {
      final videoUrl = await _imageUploadService.uploadVideoFromMobile(
        source: ImageSource.gallery,
        onProgress: (progress) {
          setState(() {
            _videoUploadProgress = progress;
          });
        },
      );

      setState(() {
        _isUploadingVideo = false;
        if (videoUrl != null) {
          _uploadedVideoUrl = videoUrl;
          _contentType = 'video';
          _videoUrlController.text = videoUrl;
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isArabic
                    ? 'فشل رفع الفيديو. حاول مرة أخرى.'
                    : 'Failed to upload video. Please try again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _isUploadingVideo = false;
      });
      debugPrint('Error picking video from gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isArabic
                ? 'حدث خطأ أثناء اختيار الفيديو.'
                : 'Error occurred while selecting video.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickVideoFromDesktop() async {
    setState(() {
      _isUploadingVideo = true;
      _videoUploadProgress = 0.0;
    });

    final videoUrl = await _imageUploadService.uploadMediaFromMobile(
      isVideo: true,
      onProgress: (progress) {
        setState(() {
          _videoUploadProgress = progress;
        });
      },
    );

    setState(() {
      _isUploadingVideo = false;
      _uploadedVideoUrl = videoUrl;
      if (videoUrl != null) {
        _contentType = 'video';
        _videoUrlController.text = videoUrl;
      }
    });
  }

  void _removeUploadedImage() {
    setState(() {
      _uploadedImageUrl = null;
      _imageUrlController.clear();
      if (_contentType == 'image') {
        _contentType = 'text';
      }
    });
  }

  void _removeUploadedVideo() {
    setState(() {
      _uploadedVideoUrl = null;
      _videoUrlController.clear();
      if (_contentType == 'video') {
        _contentType = 'text';
      }
    });
  }

  Future<void> _submit() async {
    debugPrint('[CreatePost] Submit invoked. isSubmitting=$_isSubmitting');
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      debugPrint(
          '[CreatePost] Form validation failed. Title="${_titleController.text}" contentLength=${_contentController.text.trim().length}');
      return;
    }
    setState(() => _isSubmitting = true);
    debugPrint(
        '[CreatePost] Preparing payload for mode=$_selectedMode contentType=$_contentType isPinned=$_isPinned');
    debugPrint('[CreatePost] Author ID: ${widget.authorId}');
    debugPrint('[CreatePost] Author Email: ${widget.authorEmail}');

    final metadata = {
      'author_name': _userData != null
          ? (_userData!['nickname']?.isNotEmpty == true
              ? _userData!['nickname']
              : '${_userData!['first_name'] ?? ''} ${_userData!['last_name'] ?? ''}'
                  .trim())
          : (widget.userMetadata['full_name'] ??
              widget.userMetadata['name'] ??
              widget.userMetadata['display_name'] ??
              widget.authorEmail ??
              'Hesabi User'),
      'author_role': _userData?['role'] ?? widget.userMetadata['job_title'],
      'author_company': _userData?['company_name'] ??
          widget.userMetadata['company'] ??
          widget.userMetadata['company_name'],
      'author_avatar':
          _userData?['avatar_url'] ?? widget.userMetadata['avatar_url'],
      'is_liked': false,
    }..removeWhere((key, value) => value == null || value == '');
    debugPrint('[CreatePost] Metadata keys: ${metadata.keys.toList()}');
    debugPrint('[CreatePost] Metadata avatar: ${metadata['author_avatar']}');

    try {
      await widget.feedService.createPost(
        mode: _selectedMode,
        authorId: widget.authorId,
        content: _contentController.text.trim(),
        contentType: _contentType,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        aiSummary: _summaryController.text.trim().isEmpty
            ? null
            : _summaryController.text.trim(),
        imageUrl: _uploadedImageUrl ??
            (_imageUrlController.text.trim().isEmpty
                ? null
                : _imageUrlController.text.trim()),
        videoUrl: _uploadedVideoUrl ??
            (_videoUrlController.text.trim().isEmpty
                ? null
                : _videoUrlController.text.trim()),
        isPinned: _isPinned,
        metadata: metadata,
      );

      if (!mounted) return;
      debugPrint('[CreatePost] Post published successfully. Closing sheet.');
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[CreatePost] Error while publishing: $e');
      String message;
      if (e.toString().contains('pin_limit_reached')) {
        message = widget.isArabic
            ? 'لا يمكن تثبيت أكثر من ثلاثة بوستات لهذا الوضع'
            : 'You can pin up to three posts for this mode';
      } else {
        message = widget.isArabic
            ? 'حدث خطأ أثناء نشر البوست'
            : 'Failed to publish the post';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        debugPrint('[CreatePost] Resetting submit state.');
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.isArabic;
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
    final theme = Theme.of(context);

    return Directionality(
      textDirection: textDirection,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Section - Avatar and Name
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: _userData?['avatar_url'] != null
                          ? CachedNetworkImageProvider(_userData!['avatar_url'])
                          : null,
                      child: _userData?['avatar_url'] == null
                          ? Text(
                              (_userData?['nickname']?.isNotEmpty == true
                                      ? _userData!['nickname'][0]
                                      : (_userData?['first_name'] != null &&
                                              _userData?['last_name'] != null
                                          ? '${_userData!['first_name'][0]}${_userData!['last_name'][0]}'
                                          : (_userData?['first_name'] ??
                                                  widget.userMetadata[
                                                      'full_name'] ??
                                                  widget.userMetadata['name'] ??
                                                  'U')
                                              .toUpperCase()))
                                  .toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userData != null
                                ? (_userData!['nickname']?.isNotEmpty == true
                                    ? _userData!['nickname']
                                    : '${_userData!['first_name'] ?? ''} ${_userData!['last_name'] ?? ''}'
                                        .trim())
                                : (widget.userMetadata['full_name'] ??
                                    widget.userMetadata['name'] ??
                                    widget.userMetadata['display_name'] ??
                                    widget.authorEmail ??
                                    'Hesabi User'),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (_userData?['role'] != null)
                            Text(
                              _userData!['role'],
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                    // Publish Button
                    Container(
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _isSubmitting ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Category Selection Section
                Text(
                  isArabic ? 'القسم' : 'Category',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: FeedMode.values
                      .where((mode) => mode != FeedMode.all)
                      .map((mode) {
                    final isSelected = _selectedMode == mode;
                    return ChoiceChip(
                      label: Text(
                        _modeLabel(mode, isArabic),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (value) {
                        if (value) {
                          setState(() => _selectedMode = mode);
                        }
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Content Text Area
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Content input with emoji button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _contentController,
                              decoration: InputDecoration(
                                labelText: isArabic
                                    ? 'ماذا تفكر؟'
                                    : 'What are you thinking?',
                                hintText: isArabic
                                    ? 'شارك أفكارك مع المجتمع...'
                                    : 'Share your thoughts with the community...',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 16),
                                floatingLabelStyle: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                ),
                                labelStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showEmojiPicker
                                        ? Icons.keyboard
                                        : Icons.emoji_emotions_outlined,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    // Hide keyboard when opening emoji picker
                                    if (!_showEmojiPicker) {
                                      FocusScope.of(context).unfocus();
                                    }
                                    setState(() {
                                      _showEmojiPicker = !_showEmojiPicker;
                                    });
                                  },
                                ),
                              ),
                              maxLines: 6,
                              minLines: 4,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return isArabic
                                      ? 'المحتوى مطلوب'
                                      : 'Content is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      // Emoji picker
                      if (_showEmojiPicker)
                        Container(
                          height: 250,
                          padding: const EdgeInsets.all(8),
                          margin: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom:
                                        BorderSide(color: Colors.grey[200]!),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isArabic ? 'اختر إيموجي' : 'Choose Emoji',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _showEmojiPicker = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              // Emoji grid
                              Expanded(
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 8,
                                    childAspectRatio: 1,
                                  ),
                                  itemCount: _commonEmojis.length,
                                  itemBuilder: (context, index) {
                                    final emoji = _commonEmojis[index];
                                    return GestureDetector(
                                      onTap: () => _insertEmoji(emoji),
                                      child: Container(
                                        margin: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          color: Colors.grey[50],
                                        ),
                                        child: Center(
                                          child: Text(
                                            emoji,
                                            style:
                                                const TextStyle(fontSize: 20),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Media Options Section
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingImage
                            ? null
                            : () => _showMediaSourceOptions(isVideo: false),
                        icon: _isUploadingImage
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 1.5),
                              )
                            : Icon(Icons.photo_library, size: 18),
                        label: Text(
                          _isUploadingImage
                              ? (isArabic ? 'جاري الرفع...' : 'Uploading...')
                              : (_uploadedImageUrl != null
                                  ? (isArabic ? 'تغيير الصورة' : 'Change Image')
                                  : (isArabic ? 'إضافة صورة' : 'Add Image')),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: Size(0, 36),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingVideo
                            ? null
                            : () => _showMediaSourceOptions(isVideo: true),
                        icon: _isUploadingVideo
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 1.5),
                              )
                            : Icon(Icons.videocam, size: 18),
                        label: Text(
                          _isUploadingVideo
                              ? (isArabic ? 'جاري الرفع...' : 'Uploading...')
                              : (_uploadedVideoUrl != null
                                  ? (isArabic
                                      ? 'تغيير الفيديو'
                                      : 'Change Video')
                                  : (isArabic ? 'إضافة فيديو' : 'Add Video')),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: Size(0, 36),
                        ),
                      ),
                    ),
                  ],
                ),

                // Media Preview Section
                if (_uploadedImageUrl != null || _uploadedVideoUrl != null) ...[
                  const SizedBox(height: 16),

                  // Debug info
                  if (_uploadedImageUrl != null)
                    Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Image URL: $_uploadedImageUrl',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),

                  // Image Preview
                  if (_uploadedImageUrl != null)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: _uploadedImageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Icon(Icons.error, color: Colors.red),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _removeUploadedImage,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Video Preview
                  if (_uploadedVideoUrl != null)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.black,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              Icons.play_circle_filled,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _removeUploadedVideo,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                // Pin Option (moved outside Additional Options)
                SwitchListTile(
                  value: _isPinned,
                  onChanged: (value) => setState(() => _isPinned = value),
                  title: Text(isArabic ? 'تثبيت البوست' : 'Pin this post'),
                  subtitle: Text(
                    isArabic
                        ? 'يمكن تثبيت حتى ثلاثة بوستات في كل وضع'
                        : 'You can pin up to three posts per mode',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),

                // Action buttons removed - moved to header
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _modeLabel(FeedMode mode, bool isArabic) {
    switch (mode) {
      case FeedMode.all:
        return isArabic ? 'الكل' : 'All';
      case FeedMode.learn:
        return isArabic ? 'تعلم' : 'Learn';
      case FeedMode.work:
        return isArabic ? 'عمل' : 'Work';
      case FeedMode.connect:
        return isArabic ? 'تواصل' : 'Connect';
      case FeedMode.chill:
        return isArabic ? 'استرخاء' : 'Chill';
    }
  }

  List<Map<String, String>> _contentTypeOptions(bool isArabic) {
    final options = [
      {
        'value': 'text',
        'label': isArabic ? 'نصي' : 'Text',
      },
      {
        'value': 'image',
        'label': isArabic ? 'صورة' : 'Image',
      },
      {
        'value': 'video',
        'label': isArabic ? 'فيديو' : 'Video',
      },
    ];

    debugPrint('[CreatePost] Content type options: $options');
    return options;
  }
}

class _SearchScreen extends StatefulWidget {
  const _SearchScreen({required this.isArabic});

  final bool isArabic;

  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _recentSearches = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _recentSearches.remove(trimmed);
      _recentSearches.insert(0, trimmed);
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.isArabic;
    final hint = isArabic ? 'ابحث في حسابي' : 'Search Hesabi';
    final backIcon = isArabic ? Icons.arrow_forward : Icons.arrow_back;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(backIcon),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _handleSearch,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _handleSearch(_searchController.text),
          ),
        ],
      ),
      body: _recentSearches.isEmpty
          ? Center(
              child: Text(
                widget.isArabic
                    ? 'ابدأ البحث عن الأشخاص أو المنشورات'
                    : 'Start searching for people or posts',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final term = _recentSearches[index];
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(term),
                  onTap: () => _handleSearch(term),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _recentSearches.removeAt(index);
                      });
                    },
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: _recentSearches.length,
            ),
    );
  }

  void _showCommentsBottomSheet(
      BuildContext context, Map<String, dynamic> post, bool isArabic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CommentsSheet(post: post, isArabic: isArabic),
    );
  }
}

class _StickyFeedHeader extends SliverPersistentHeaderDelegate {
  final bool isArabic;
  final FeedMode currentMode;
  final Function(FeedMode) onModeChanged;
  final VoidCallback onCreatePost;
  final VoidCallback onCreatePostWithMedia;

  _StickyFeedHeader({
    required this.isArabic,
    required this.currentMode,
    required this.onModeChanged,
    required this.onCreatePost,
    required this.onCreatePostWithMedia,
  });

  @override
  double get minExtent => 140.0; // Minimum height when collapsed

  @override
  double get maxExtent => 140.0; // Fixed height

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // Create Post Area
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(
                    Supabase.instance.client.auth.currentUser
                            ?.userMetadata?['avatar_url'] ??
                        'https://via.placeholder.com/40',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: onCreatePost,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isArabic ? 'اكتب شيئاً...' : 'Write something...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onCreatePostWithMedia,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.photo_outlined,
                      color: Colors.green,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Context Switcher
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildModeButton(
                  FeedMode.all,
                  isArabic ? 'الكل' : 'All',
                  Icons.grid_view,
                  Colors.grey,
                ),
                _buildModeButton(
                  FeedMode.learn,
                  isArabic ? 'تعلم' : 'Learn',
                  Icons.school_outlined,
                  Colors.blue,
                ),
                _buildModeButton(
                  FeedMode.work,
                  isArabic ? 'عمل' : 'Work',
                  Icons.work_outline,
                  Colors.green,
                ),
                _buildModeButton(
                  FeedMode.connect,
                  isArabic ? 'تواصل' : 'Connect',
                  Icons.people_outline,
                  Colors.purple,
                ),
                _buildModeButton(
                  FeedMode.chill,
                  isArabic ? 'استرخاء' : 'Chill',
                  Icons.coffee_outlined,
                  Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    FeedMode mode,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = currentMode == mode;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => onModeChanged(mode),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey[600],
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

class _NotificationsScreen extends StatelessWidget {
  const _NotificationsScreen({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final title = isArabic ? 'الإشعارات' : 'Notifications';
    final emptyText = isArabic
        ? 'لا توجد إشعارات جديدة الآن'
        : 'No new notifications right now';
    final backIcon = isArabic ? Icons.arrow_forward : Icons.arrow_back;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: Icon(backIcon),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Text(
          emptyText,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
