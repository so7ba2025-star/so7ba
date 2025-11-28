import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home_screen.dart';

class FeedService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getFeedPosts({
    required FeedMode mode,
    required int limit,
    required int offset,
  }) async {
    final modeKey = _mapModeToString(mode);

    debugPrint('=== FEED FETCH DEBUG ===');
    debugPrint('Mode: $mode');
    debugPrint('ModeKey: $modeKey');
    debugPrint('Limit: $limit');
    debugPrint('Offset: $offset');

    try {
      final pinnedRecords = await _fetchPinnedRecords(modeKey);
      final pinnedCount = pinnedRecords.length;

      final adjustedOffset =
          offset > 0 ? (offset - pinnedCount).clamp(0, offset) : 0;

      int effectiveLimit = limit;
      if (offset == 0) {
        effectiveLimit = (limit - pinnedCount).clamp(0, limit);
      }

      debugPrint('PinnedCount: $pinnedCount');
      debugPrint('AdjustedOffset: $adjustedOffset');
      debugPrint('EffectiveLimit: $effectiveLimit');

      List<Map<String, dynamic>> standardPosts = [];
      if (effectiveLimit > 0) {
        final rangeEnd = adjustedOffset + effectiveLimit - 1;
        debugPrint('RangeEnd: $rangeEnd');

        // Fetch posts without user data first
        dynamic response;
        if (modeKey == 'all') {
          debugPrint('Fetching ALL posts (no mode filter)');
          response = await _supabase
              .from('posts')
              .select('*')
              .eq('status', 'active')
              .neq('is_pinned', true)
              .order('created_at', ascending: false)
              .range(adjustedOffset, rangeEnd);
        } else {
          debugPrint('Fetching posts for mode: $modeKey');
          response = await _supabase
              .from('posts')
              .select('*')
              .eq('status', 'active')
              .eq('post_mode', modeKey)
              .neq('is_pinned', true)
              .order('created_at', ascending: false)
              .range(adjustedOffset, rangeEnd);
        }

        if (response is List && response.isNotEmpty) {
          // Extract unique author IDs
          final authorIds = response
              .map((post) => post['author_id']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .toSet()
              .cast<String>();

          debugPrint('Found ${authorIds.length} unique authors');

          // Fetch user profiles for all authors
          Map<String, Map<String, dynamic>> userProfiles = {};
          if (authorIds.isNotEmpty) {
            try {
              final profilesResponse = await _supabase
                  .from('user_profiles')
                  .select(
                      'id, nickname, first_name, last_name, avatar_url, role')
                  .inFilter('id', authorIds.toList());

              for (var profile in profilesResponse) {
                userProfiles[profile['id'].toString()] = profile;
              }
              debugPrint('Fetched ${userProfiles.length} user profiles');
            } catch (e) {
              debugPrint('Error fetching user profiles: $e');
            }
          }

          // Map posts with user data
          standardPosts = response.map((post) {
            final authorId = post['author_id']?.toString();
            final userProfile =
                authorId != null ? userProfiles[authorId] : null;

            return _mapPostRecordWithUser(post, userProfile);
          }).toList();
        }

        debugPrint(
            'Fetched ${standardPosts.length} standard posts for mode: $modeKey');

        // Fetch user's likes and saves for these posts efficiently
        if (standardPosts.isNotEmpty) {
          final currentUser = _supabase.auth.currentUser;
          if (currentUser != null) {
            // Get all post IDs
            final postIds =
                standardPosts.map((post) => post['id'].toString()).toList();

            // Fetch all likes in one query
            try {
              final likesResponse = await _supabase
                  .from('post_likes')
                  .select('post_id')
                  .eq('user_id', currentUser.id)
                  .inFilter('post_id', postIds);

              // Create a set of liked post IDs
              final likedPostIds = likesResponse
                  .map((like) => like['post_id'].toString())
                  .toSet();

              // Update posts with like data
              for (var post in standardPosts) {
                final postId = post['id'].toString();
                if (likedPostIds.contains(postId)) {
                  post['is_liked'] = true;
                  post['reaction_type'] = 'like'; // Default to 'like'
                }
              }
            } catch (e) {
              debugPrint('Error fetching likes: $e');
            }

            // Fetch all saves in one query
            try {
              final savesResponse = await _supabase
                  .from('saved_posts')
                  .select('post_id')
                  .eq('user_id', currentUser.id)
                  .inFilter('post_id', postIds);

              // Create a set of saved post IDs
              final savedPostIds = savesResponse
                  .map((save) => save['post_id'].toString())
                  .toSet();

              // Update posts with save data
              for (var post in standardPosts) {
                final postId = post['id'].toString();
                if (savedPostIds.contains(postId)) {
                  post['is_saved'] = true;
                }
              }
            } catch (e) {
              debugPrint('Error fetching saves: $e');
            }
          }
        }
      }

      final pinnedPosts =
          offset == 0 ? pinnedRecords : <Map<String, dynamic>>[];

      debugPrint('Pinned posts count: ${pinnedPosts.length}');

      // Combine all posts
      final allPosts = [...pinnedPosts, ...standardPosts];

      // Sort all posts by created_at descending (newest first)
      allPosts.sort((a, b) {
        final aDate = DateTime.parse(a['created_at']);
        final bDate = DateTime.parse(b['created_at']);
        return bDate.compareTo(aDate); // b comes first if newer
      });

      // Debug: Check order of posts
      debugPrint('=== POST ORDER DEBUG ===');
      for (int i = 0; i < allPosts.length; i++) {
        debugPrint(
            'Final $i: ${allPosts[i]['id']} - ${allPosts[i]['created_at']} - Pinned: ${allPosts[i]['is_pinned']}');
      }
      debugPrint('=== END POST ORDER DEBUG ===');

      return allPosts;
    } catch (e) {
      debugPrint('Error fetching feed posts: $e');
      return []; // Return empty list on error instead of mock data
    }
  }

  Future<void> createPost({
    required FeedMode mode,
    required String authorId,
    required String content,
    required String contentType,
    String? title,
    String? aiSummary,
    String? imageUrl,
    String? videoUrl,
    bool isPinned = false,
    Map<String, dynamic>? metadata,
  }) async {
    final modeKey = _mapModeToStringForCreation(mode);

    try {
      if (isPinned) {
        final currentPinned = await _fetchPinnedRecords(modeKey);
        if (currentPinned.length >= 3) {
          throw Exception('pin_limit_reached');
        }
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final payload = {
        'author_id': authorId,
        'title': title,
        'content': content,
        'content_type': contentType,
        'post_mode': modeKey,
        'status': 'active',
        'ai_summary': aiSummary,
        'image_url': imageUrl,
        'video_url': videoUrl,
        'likes_count': 0,
        'comments_count': 0,
        'shares_count': 0,
        'views_count': 0,
        'is_pinned': isPinned,
        'is_featured': false,
        'created_at': now,
        'updated_at': now,
      };

      // Only remove null values except author_id
      payload.removeWhere((key, value) => value == null && key != 'author_id');

      payload['metadata'] = metadata ?? {};

      debugPrint('createPost payload: $payload');
      debugPrint('createPost author_id: ${payload['author_id']}');
      await _supabase.from('posts').insert(payload);
      debugPrint('createPost insert completed successfully');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPinnedRecords(String modeKey) async {
    try {
      // Fetch pinned posts without user data first
      final dynamic response;
      if (modeKey == 'all') {
        debugPrint('Fetching ALL pinned posts (no mode filter)');
        response = await _supabase
            .from('posts')
            .select('*')
            .eq('status', 'active')
            .eq('is_pinned', true)
            .order('created_at', ascending: false);
      } else {
        debugPrint('Fetching pinned posts for mode: $modeKey');
        response = await _supabase
            .from('posts')
            .select('*')
            .eq('post_mode', modeKey)
            .eq('status', 'active')
            .eq('is_pinned', true)
            .order('created_at', ascending: false);
      }

      if (response is List && response.isNotEmpty) {
        // Extract unique author IDs
        final authorIds = response
            .map((post) => post['author_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .toSet()
            .cast<String>();

        debugPrint('Found ${authorIds.length} unique authors in pinned posts');

        // Fetch user profiles for all authors
        Map<String, Map<String, dynamic>> userProfiles = {};
        if (authorIds.isNotEmpty) {
          try {
            final profilesResponse = await _supabase
                .from('user_profiles')
                .select('id, nickname, first_name, last_name, avatar_url, role')
                .inFilter('id', authorIds.toList());

            for (var profile in profilesResponse) {
              userProfiles[profile['id'].toString()] = profile;
            }
            debugPrint(
                'Fetched ${userProfiles.length} user profiles for pinned posts');
          } catch (e) {
            debugPrint('Error fetching user profiles for pinned posts: $e');
          }
        }

        // Map pinned posts with user data
        return response.map((post) {
          final authorId = post['author_id']?.toString();
          final userProfile = authorId != null ? userProfiles[authorId] : null;
          return _mapPostRecordWithUser(post, userProfile);
        }).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching pinned records: $e');
      return [];
    }
  }

  Map<String, dynamic> _mapPostRecordWithUser(
      Map<String, dynamic> record, Map<String, dynamic>? userProfile) {
    final metadata = _extractMetadata(record['metadata']);

    String? _metaString(String key) => metadata?[key]?.toString();

    // Use user profile data as primary source for author info
    String? authorAvatar;
    String? authorName = _metaString('author_name');
    String? authorRole = _metaString('author_role');

    // Override with user profile data if available
    if (userProfile != null) {
      final nickname = userProfile['nickname']?.toString();
      final firstName = userProfile['first_name']?.toString();
      final lastName = userProfile['last_name']?.toString();

      // Use nickname as primary source, fallback to first_name + last_name
      if (nickname != null && nickname.isNotEmpty) {
        authorName = nickname;
      } else if (firstName != null && firstName.isNotEmpty) {
        if (lastName != null && lastName.isNotEmpty) {
          authorName = '$firstName $lastName';
        } else {
          authorName = firstName;
        }
      }

      // Use user profile avatar as primary source
      authorAvatar = userProfile['avatar_url']?.toString();

      if (authorRole == null || authorRole.isEmpty) {
        authorRole = userProfile['role']?.toString();
      }
    }

    // Fallback to metadata if no user profile avatar
    if (authorAvatar == null || authorAvatar.isEmpty) {
      authorAvatar = _metaString('author_avatar');
    }

    return {
      'id': record['id'],
      'author_id': record['author_id'],
      'author_name': authorName ?? 'مستخدم Hesabi',
      'author_role': authorRole,
      'author_company': _metaString('author_company'),
      'author_avatar': authorAvatar,
      'content': record['content'] ?? '',
      'title': record['title'],
      'ai_summary': record['ai_summary'],
      'image_url': record['image_url'],
      'video_url': record['video_url'],
      'likes_count': record['likes_count'] ?? 0,
      'comments_count': record['comments_count'] ?? 0,
      'shares_count': record['shares_count'] ?? 0,
      'saved_count': record['saved_count'] ?? 0,
      'views_count': record['views_count'] ?? 0,
      'is_liked': false, // Will be updated later
      'is_saved': false, // Will be updated later
      'reaction_type': '', // Will be updated later
      'is_pinned': record['is_pinned'] ?? false,
      'is_featured': record['is_featured'] ?? false,
      'status': record['status'],
      'type': record['content_type'],
      'post_mode': record['post_mode'],
      'created_at': record['created_at'],
      'updated_at': record['updated_at'],
      'metadata': metadata,
    };
  }

  Map<String, dynamic>? _extractMetadata(dynamic metadata) {
    if (metadata == null) return null;
    if (metadata is Map<String, dynamic>) return metadata;
    if (metadata is Map) {
      return metadata.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  String _mapModeToString(FeedMode mode) {
    switch (mode) {
      case FeedMode.all:
        return 'all'; // Return 'all' for FeedMode.all
      case FeedMode.learn:
        return 'learn';
      case FeedMode.work:
        return 'work';
      case FeedMode.connect:
        return 'connect';
      case FeedMode.chill:
        return 'chill';
    }
  }

  String _mapModeToStringForCreation(FeedMode mode) {
    switch (mode) {
      case FeedMode.all:
        // 'all' is not a valid post_mode for creating posts
        // Default to 'connect' when creating posts in 'all' mode
        return 'connect';
      case FeedMode.learn:
        return 'learn';
      case FeedMode.work:
        return 'work';
      case FeedMode.connect:
        return 'connect';
      case FeedMode.chill:
        return 'chill';
    }
  }

  List<Map<String, dynamic>> _getMockPostsForMode(FeedMode mode) {
    switch (mode) {
      case FeedMode.all:
        return _getMockAllPosts();
      case FeedMode.learn:
        return _getMockLearningPosts();
      case FeedMode.work:
        return _getMockWorkPosts();
      case FeedMode.connect:
        return _getMockConnectPosts();
      case FeedMode.chill:
        return _mockChillPosts();
    }
  }

  List<Map<String, dynamic>> _getMockLearningPosts() {
    return [
      {
        'id': '1',
        'author_name': 'أحمد محمد',
        'author_role': 'Senior Flutter Developer',
        'author_company': 'Tech Solutions',
        'author_avatar': 'https://picsum.photos/seed/ahmed/40/40',
        'content':
            'نشرت اليوم درس جديد عن State Management في Flutter. بنستخدم Provider و BLoc في نفس المشروع، وإيه الفروقات بينهم وإيه الأفضل لكل حالة. الدرس فيه أمثلة عملية وبيوضح إيه اللي محتاج تفكر فيه لما تختار الـ State Management بتاعك.',
        'ai_summary':
            'درس جديد عن State Management في Flutter مع مقارنة بين Provider و BLoc وأمثلة عملية.',
        'image_url': 'https://picsum.photos/seed/flutter/400/200',
        'likes_count': 142,
        'comments_count': 28,
        'is_liked': false,
        'is_read': false,
        'created_at':
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'expertise_badge': 'Flutter Expert',
        'type': 'article',
      },
      {
        'id': '2',
        'author_name': 'Sarah Johnson',
        'author_role': 'UI/UX Designer',
        'author_company': 'Design Studio',
        'author_avatar': 'https://picsum.photos/seed/sarah/40/40',
        'content':
            'جربت Material 3 في مشروع جديد والنتيجة كانت مدهشة! الألوان والـ Typography والـ Motion كلها متطورة. عملت مقارنة بين Material 2 و 3 في الفيديو ده، وإيه التغييرات اللي هتحتاج تعملها في مشروعك الحالي.',
        'image_url': 'https://picsum.photos/seed/material3/400/200',
        'likes_count': 89,
        'comments_count': 15,
        'is_liked': true,
        'created_at':
            DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
        'expertise_badge': 'Design Expert',
        'type': 'video',
      },
      {
        'id': '3',
        'author_name': 'محمد علي',
        'author_role': 'Backend Engineer',
        'author_company': 'Cloud Systems',
        'author_avatar': 'https://picsum.photos/seed/mohamed/40/40',
        'content':
            'شرح كامل عن REST APIs vs GraphQL. إيه الفروقات في Performance، Security، و Scalability. مع مثال عملي بنبني نفس الـ API بالطريقتين ونشوف إيه الأفضل لكل Use Case.',
        'likes_count': 76,
        'comments_count': 12,
        'is_liked': false,
        'created_at':
            DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
        'expertise_badge': 'API Expert',
        'type': 'article',
      },
    ];
  }

  List<Map<String, dynamic>> _getMockWorkPosts() {
    return [
      {
        'id': '4',
        'author_name': 'Tech Innovations',
        'author_role': 'Hiring Manager',
        'author_company': 'Tech Innovations',
        'author_avatar': 'https://picsum.photos/seed/techco/40/40',
        'content':
            'مطلوب Flutter Developer بـ 3-5 سنوات خبرة. الشغل Remote من أي مكان في العالم. بنشتغل على مشاريع كبيرة للشركات الكبرى في المنطقة. السلالم ممتاز والتأمين الشامل.',
        'likes_count': 45,
        'comments_count': 8,
        'is_liked': false,
        'created_at':
            DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'expertise_badge': 'Verified Company',
        'type': 'job',
        'company': 'Tech Innovations',
      },
      {
        'id': '5',
        'author_name': 'Digital Agency',
        'author_role': 'Project Manager',
        'author_company': 'Digital Agency',
        'author_avatar': 'https://picsum.photos/seed/digital/40/40',
        'content':
            'مشاريع جديدة محتاجين Mobile App Developers. بنشتغل على تطبيقات للسعودية والإمارات. الخبرة في E-commerce و Payment Gateways مهمة جداً.',
        'likes_count': 32,
        'comments_count': 6,
        'is_liked': false,
        'created_at':
            DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
        'expertise_badge': 'Verified Company',
        'type': 'job',
        'company': 'Digital Agency',
      },
    ];
  }

  List<Map<String, dynamic>> _getMockConnectPosts() {
    return [
      {
        'id': '6',
        'author_name': 'نور الدين',
        'author_role': 'Software Engineer',
        'author_company': 'Startup Hub',
        'author_avatar': 'https://picsum.photos/seed/nour/40/40',
        'content':
            'عندي مشكلة في Performance في Flutter app لما بيحصل عدد كبير من الـ Widgets في الشاشة الواحدة. جربت ListView.builder و CachedNetworkImage بس لسه بطيء. فيه حد عنده حل أو اقتراح؟',
        'likes_count': 23,
        'comments_count': 31,
        'is_liked': false,
        'created_at': DateTime.now()
            .subtract(const Duration(minutes: 30))
            .toIso8601String(),
        'expertise_badge': 'Performance Expert',
        'type': 'question',
        'experts_available': 5,
      },
      {
        'id': '7',
        'author_name': 'فاطمة أحمد',
        'author_role': 'Product Manager',
        'author_company': 'FinTech Solutions',
        'author_avatar': 'https://picsum.photos/seed/fatima/40/40',
        'content':
            'ناقشوا معايا إيه رأيكم في الـ Feature اللي عاملها في تطبيقي الجديد؟ بتحتاج feedback من المستخدمين قبل ما أطلقها رسمياً. التطبيق بيساعد الناس تدير مصاريفها الشهرية.',
        'image_url': 'https://picsum.photos/seed/fintech/400/200',
        'likes_count': 67,
        'comments_count': 45,
        'is_liked': true,
        'created_at':
            DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
        'expertise_badge': 'Product Expert',
        'type': 'discussion',
      },
    ];
  }

  List<Map<String, dynamic>> _mockChillPosts() {
    return [
      {
        'id': '8',
        'author_name': 'Developer Memes',
        'author_role': 'Community Page',
        'author_company': '',
        'author_avatar': 'https://picsum.photos/seed/memes/40/40',
        'content': 'When the client says "make it pop" 😂',
        'image_url': 'https://picsum.photos/seed/meme1/400/300',
        'likes_count': 234,
        'comments_count': 56,
        'is_liked': true,
        'created_at': DateTime.now()
            .subtract(const Duration(minutes: 15))
            .toIso8601String(),
        'type': 'meme',
      },
      {
        'id': '9',
        'author_name': 'Coffee & Code',
        'author_role': 'Lifestyle Blog',
        'author_company': '',
        'author_avatar': 'https://picsum.photos/seed/coffee/40/40',
        'content':
            'الفرق بين Developer بيشرب قهوة و Developer بيشرب شاي؟\n\nالقهوة: "أنا مش فاهم حاجة، بس هظبطها"\nالشاي: "أنا فاهم كل حاجة، بس هفكر فيها شوية"\n\nإنت من أي فريق؟ 😄',
        'likes_count': 189,
        'comments_count': 78,
        'is_liked': false,
        'created_at':
            DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'type': 'fun',
      },
      {
        'id': '10',
        'author_name': 'Weekend Vibes',
        'author_role': 'Community',
        'author_company': '',
        'author_avatar': 'https://picsum.photos/seed/weekend/40/40',
        'content':
            'أول حاجة بتعملها لما تخلص من الشغل يوم الجمعه؟\n\n1. تنام 12 ساعة\n2. تشوف Netflix\n3. تلعب ألعاب\n4. تعمل side project\n5. تقعد مع العيلة والأصحاب\n\nأنا بختار 1 و 5 😊',
        'likes_count': 156,
        'comments_count': 92,
        'is_liked': true,
        'created_at':
            DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
        'type': 'poll',
      },
    ];
  }

  List<Map<String, dynamic>> _getMockAllPosts() {
    final allPosts = [
      ..._getMockLearningPosts(),
      ..._getMockWorkPosts(),
      ..._getMockConnectPosts(),
      ..._mockChillPosts(),
    ];

    // Add is_read field to all posts (default to false for unread)
    return allPosts.map((post) {
      final updatedPost = Map<String, dynamic>.from(post);
      updatedPost['is_read'] = false; // Mark all as unread initially
      return updatedPost;
    }).toList();
  }

  Future<void> likePost(String postId) async {
    try {
      // TODO: Implement actual like functionality
      print('Liking post: $postId');
    } catch (e) {
      print('Error liking post: $e');
    }
  }

  Future<void> unlikePost(String postId) async {
    try {
      // TODO: Implement actual unlike functionality
      print('Unliking post: $postId');
    } catch (e) {
      print('Error unliking post: $e');
    }
  }

  Future<void> savePost(String postId) async {
    try {
      // TODO: Implement actual save functionality
      print('Saving post: $postId');
    } catch (e) {
      print('Error saving post: $e');
    }
  }

  Future<void> sharePost(String postId) async {
    try {
      // TODO: Implement actual share functionality
      print('Sharing post: $postId');
    } catch (e) {
      print('Error sharing post: $e');
    }
  }
}
