import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../../core/services/ai_summary_service.dart';

// Global cache for video controllers to prevent reloading
class VideoControllerCache {
  static final Map<String, VideoPlayerController> _cache = {};
  static final Map<String, bool> _initialized = {};
  static const int _maxCacheSize =
      10; // Limit cache size to prevent memory issues

  static VideoPlayerController? getController(String url) {
    return _cache[url];
  }

  static bool isInitialized(String url) {
    return _initialized[url] ?? false;
  }

  static Future<VideoPlayerController> getOrCreateController(String url) async {
    if (_cache.containsKey(url)) {
      return _cache[url]!;
    }

    // Clean up old controllers if cache is full
    if (_cache.length >= _maxCacheSize) {
      _cleanupOldestController();
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _cache[url] = controller;

    try {
      await controller.initialize();
      _initialized[url] = true;
    } catch (error) {
      debugPrint('Error initializing video: $error');
      _cache.remove(url);
      _initialized.remove(url);
      rethrow;
    }

    return controller;
  }

  static void _cleanupOldestController() {
    if (_cache.isEmpty) return;

    // Simple FIFO cleanup - remove the first entry
    final firstKey = _cache.keys.first;
    disposeController(firstKey);
    debugPrint('Cleaned up oldest video controller from cache: $firstKey');
  }

  static void disposeController(String url) {
    final controller = _cache.remove(url);
    _initialized.remove(url);
    controller?.dispose();
  }

  static void clearCache() {
    for (final controller in _cache.values) {
      controller.dispose();
    }
    _cache.clear();
    _initialized.clear();
  }

  static int get cacheSize => _cache.length;

  static List<String> getCachedUrls() => _cache.keys.toList();
}

class FullscreenImageView extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const FullscreenImageView({
    super.key,
    required this.imageUrl,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: () {
              // TODO: Add download functionality
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: tag,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (context, url, error) => Center(
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FullscreenVideoPlayer extends StatefulWidget {
  final String? videoUrl;
  final bool isArabic;

  const FullscreenVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.isArabic,
  });

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() async {
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      try {
        // Check if controller already exists in cache
        if (VideoControllerCache.isInitialized(widget.videoUrl!)) {
          _controller = VideoControllerCache.getController(widget.videoUrl!);
          if (mounted) {
            setState(() {
              _isInitialized = true;
              _showControls = true;
            });
            _controller!.addListener(_videoListener);
            _resetHideControlsTimer();
          }
        } else {
          // Create new controller and cache it
          _controller = await VideoControllerCache.getOrCreateController(
              widget.videoUrl!);
          if (mounted) {
            setState(() {
              _isInitialized = true;
              _showControls = true;
            });
            _controller!.addListener(_videoListener);
            _resetHideControlsTimer();
          }
        }
      } catch (error) {
        debugPrint('Error initializing fullscreen video: $error');
        if (mounted) {
          // Show error message or handle gracefully
        }
      }
    }
  }

  void _videoListener() {
    if (_controller != null) {
      setState(() {
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller != null && _isInitialized) {
      setState(() {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      });
      _resetHideControlsTimer();
    }
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    // Always start timer to hide controls after 8 seconds
    _hideControlsTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _resetHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_videoListener);
    // Don't dispose the controller here - let the cache manage it
    // Only remove the reference
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _toggleControls();
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: _isInitialized && _controller != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video player fills the entire screen
                    Positioned.fill(
                      child: VideoPlayer(_controller!),
                    ),
                    // Controls overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                            stops: [0, 0.2, 0.8, 1],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Top bar with close button
                            SafeArea(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: Icon(Icons.close,
                                        color: Colors.white, size: 28),
                                  ),
                                ],
                              ),
                            ),
                            // Bottom controls
                            SafeArea(
                              child: Column(
                                children: [
                                  // Progress bar
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: VideoProgressIndicator(
                                      _controller!,
                                      allowScrubbing: true,
                                      colors: VideoProgressColors(
                                        playedColor: Colors.red,
                                        bufferedColor: Colors.grey,
                                        backgroundColor:
                                            Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  // Play button and duration
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        onPressed: _togglePlayPause,
                                        icon: Icon(
                                          _isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          color: Colors.white,
                                          size: 64,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        widget.isArabic
                            ? 'جاري تحميل الفيديو...'
                            : 'Loading video...',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class SmartPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isArabic;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;

  const SmartPostCard({
    super.key,
    required this.post,
    required this.isArabic,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
  });

  @override
  State<SmartPostCard> createState() => _SmartPostCardState();
}

class _SmartPostCardState extends State<SmartPostCard> {
  bool _isHovered = false;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _showSummary = false;
  bool _isLoadingSummary = false;
  String _aiSummary = '';
  bool _userHasReadContent =
      false; // New variable to track if user has read content
  int _likesCount = 0;
  int _commentsCount = 0;
  String _selectedReaction = '';
  bool _showReactionsPicker = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  double _volume = 1.0;
  bool _isMuted = false;
  String? _currentVideoUrl; // Track current video URL

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post['likes_count'] ?? 0;
    _commentsCount = widget.post['comments_count'] ?? 0;
    _isLiked = widget.post['is_liked'] ?? false;
    _isSaved = widget.post['is_saved'] ?? false;
    _selectedReaction = widget.post['reaction_type'] ?? '';

    _initializeVideo();

    // Initialize AI service
    print('Initializing AI Summary Service from SmartPostCard...');
    AISummaryService.initialize();

    print(
        '🔴 INIT DEBUG: Post ${widget.post['id']} - _isLiked: $_isLiked, _isSaved: $_isSaved, reaction: $_selectedReaction');
    print(
        '🔴 INIT DEBUG: Post data - is_liked: ${widget.post['is_liked']}, is_saved: ${widget.post['is_saved']}, reaction_type: ${widget.post['reaction_type']}');
  }

  void _initializeVideo() async {
    final videoUrl = widget.post['video_url'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _currentVideoUrl = videoUrl;
      try {
        // Check if controller already exists in cache
        if (VideoControllerCache.isInitialized(videoUrl)) {
          _videoController = VideoControllerCache.getController(videoUrl);
          setState(() {
            _isVideoInitialized = true;
            _volume = _videoController!.value.volume;
          });
        } else {
          // Create new controller and cache it
          _videoController =
              await VideoControllerCache.getOrCreateController(videoUrl);
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
              _volume = _videoController!.value.volume;
            });
          }
        }
      } catch (error) {
        debugPrint('Error initializing video: $error');
      }
    }
  }

  void _togglePlayPause() {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
      });
    }
  }

  void _toggleMute() {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        _isMuted = !_isMuted;
        if (_isMuted) {
          _videoController!.setVolume(0.0);
        } else {
          _videoController!.setVolume(_volume);
        }
      });
    }
  }

  void _setVolume(double value) {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        _volume = value;
        if (!_isMuted) {
          _videoController!.setVolume(value);
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _openImageFullscreen(String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullscreenImageView(
          imageUrl: imageUrl,
          tag: 'post_image_${widget.post['id']}',
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openFullscreenVideo() {
    if (_videoController != null && _isVideoInitialized) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              FullscreenVideoPlayer(
            videoUrl: widget.post['video_url'],
            isArabic: widget.isArabic,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    // Don't dispose the controller here - let the cache manage it
    // Only remove the reference
    _videoController = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(SmartPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if video URL changed
    final newVideoUrl = widget.post['video_url'] as String?;
    final oldVideoUrl = oldWidget.post['video_url'] as String?;

    if (newVideoUrl != oldVideoUrl) {
      // Clean up old video controller reference
      _videoController = null;
      _isVideoInitialized = false;
      _currentVideoUrl = null;
      // Initialize new video
      _initializeVideo();
    }

    // Update counts when post data changes
    if (oldWidget.post['comments_count'] != widget.post['comments_count']) {
      setState(() {
        _commentsCount = widget.post['comments_count'] ?? 0;
      });
    }
    if (oldWidget.post['likes_count'] != widget.post['likes_count']) {
      setState(() {
        _likesCount = widget.post['likes_count'] ?? 0;
      });
    }
    if (oldWidget.post['is_liked'] != widget.post['is_liked']) {
      setState(() {
        _isLiked = widget.post['is_liked'] ?? false;
      });
    }
    if (oldWidget.post['is_saved'] != widget.post['is_saved']) {
      setState(() {
        _isSaved = widget.post['is_saved'] ?? false;
        print('Post ${widget.post['id']}: _isSaved updated to $_isSaved');
      });
    }
    if (oldWidget.post['reaction_type'] != widget.post['reaction_type']) {
      setState(() {
        _selectedReaction = widget.post['reaction_type'] ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🔥🔥🔥 Building SmartPostCard - Image URL: ${widget.post['image_url']}');
    debugPrint(
        '🔴 SAVE DEBUG: Building widget - _isSaved: $_isSaved, color: ${_isSaved ? "Colors.red" : "Colors.grey.shade600"}');

    final content = widget.post['content'] ?? '';
    final isVeryLongContent = content.length > 500;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Card(
          margin: EdgeInsets.zero,
          elevation: _isHovered ? 4 : 1,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered
                    ? Color(0xFF880404)
                    : Color(0xFF880404).withOpacity(0.3),
                width: 3,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with user info and credibility badge
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _buildHeader(),
                ),

                // Media attachment - full width without any margins
                if (isVeryLongContent && _userHasReadContent)
                  Container(
                    margin:
                        const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                    child: GestureDetector(
                      onTap: _toggleSummary,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: Colors.purple.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isLoadingSummary
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.purple),
                                    ),
                                  )
                                : Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: Colors.purple,
                                  ),
                            const SizedBox(width: 4),
                            Text(
                              _isLoadingSummary
                                  ? (widget.isArabic
                                      ? 'جاري التلخيص...'
                                      : 'Summarizing...')
                                  : _showSummary
                                      ? (widget.isArabic
                                          ? 'عرض النص الأصلي'
                                          : 'Show Original')
                                      : (widget.isArabic
                                          ? 'تلخيص بالذكاء الاصطناعي'
                                          : 'AI Summary'),
                              style: TextStyle(
                                color: Colors.purple,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Content with AI Summary option
                _buildContent(),

                // Actions and stats
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Actions (always visible on mobile)
                      _buildActions(),
                      const SizedBox(height: 8),

                      // Contextual hiring/suggestions
                      if (widget.post['type'] == 'job' ||
                          widget.post['type'] == 'question') ...[
                        const SizedBox(height: 12),
                        _buildContextualInfo(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryIndicator() {
    final postMode = widget.post['post_mode'] as String? ?? 'general';
    final categoryInfo = _getCategoryInfo(postMode);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: categoryInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            categoryInfo['icon'],
            size: 12,
            color: categoryInfo['color'],
          ),
          const SizedBox(width: 4),
          Text(
            categoryInfo['label'],
            style: TextStyle(
              fontSize: 10,
              color: categoryInfo['color'],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getCategoryInfo(String postMode) {
    switch (postMode) {
      case 'learn':
        return {
          'label': widget.isArabic ? 'تعلم' : 'Learn',
          'icon': Icons.school_outlined,
          'color': Colors.blue,
        };
      case 'work':
        return {
          'label': widget.isArabic ? 'عمل' : 'Work',
          'icon': Icons.work_outline,
          'color': Colors.green,
        };
      case 'connect':
        return {
          'label': widget.isArabic ? 'تواصل' : 'Connect',
          'icon': Icons.people_outline,
          'color': Colors.purple,
        };
      case 'chill':
        return {
          'label': widget.isArabic ? 'استرخاء' : 'Chill',
          'icon': Icons.coffee_outlined,
          'color': Colors.orange,
        };
      default:
        return {
          'label': widget.isArabic ? 'عام' : 'General',
          'icon': Icons.public,
          'color': Colors.grey,
        };
    }
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        // Main header row
        Row(
          children: [
            // Avatar with category badge overlay
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                children: [
                  // Larger avatar
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey[300],
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: widget.post['author_avatar'] != null &&
                                widget.post['author_avatar']!.isNotEmpty
                            ? widget.post['author_avatar']!
                            : 'https://picsum.photos/seed/avatar/50/50.jpg',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[300],
                          child: Icon(Icons.person,
                              color: Colors.grey[600], size: 25),
                        ),
                        errorWidget: (context, url, error) {
                          debugPrint('Avatar error for $url: $error');
                          // Fallback to Supabase avatar if Google fails
                          if (url.contains('googleusercontent.com')) {
                            return ClipOval(
                              child: CachedNetworkImage(
                                imageUrl:
                                    'https://vjmicxgwkszhbsjoyuxd.supabase.co/storage/v1/object/public/avatars/fc5ace51-21a4-4f9f-9e88-59abee698f2a_1763988993936.jpg?t=1763989005744',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.person,
                                      color: Colors.grey[600], size: 25),
                                ),
                              ),
                            );
                          }
                          return Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[300],
                            child: Icon(Icons.person,
                                color: Colors.grey[600], size: 25),
                          );
                        },
                        memCacheWidth: 100,
                        memCacheHeight: 100,
                      ),
                    ),
                  ),

                  // Category badge overlay (only in "All" mode)
                  if (widget.post['show_category'] == true)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(
                              widget.post['post_mode'] as String? ?? 'general'),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          _getCategoryIcon(
                              widget.post['post_mode'] as String? ?? 'general'),
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name with credibility badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.post['author_name'] ?? 'Unknown User',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),

                      // Credibility Badge
                      if (widget.post['expertise_badge'] != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.post['expertise_badge'],
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Time directly under name
                  Text(
                    _formatTime(widget.post['created_at']),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),

                  const SizedBox(height: 2),

                  // Role and company
                  if (widget.post['author_role'] != null ||
                      widget.post['author_company'] != null)
                    Row(
                      children: [
                        if (widget.post['author_role'] != null)
                          Text(
                            widget.post['author_role'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        if (widget.post['author_role'] != null &&
                            widget.post['author_company'] != null)
                          Text(' • ',
                              style: TextStyle(color: Colors.grey[400])),
                        if (widget.post['author_company'] != null)
                          Text(
                            widget.post['author_company'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getCategoryColor(String postMode) {
    switch (postMode) {
      case 'learn':
        return Colors.blue;
      case 'work':
        return Colors.green;
      case 'connect':
        return Colors.purple;
      case 'chill':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String postMode) {
    switch (postMode) {
      case 'learn':
        return Icons.school_outlined;
      case 'work':
        return Icons.work_outline;
      case 'connect':
        return Icons.people_outline;
      case 'chill':
        return Icons.coffee_outlined;
      default:
        return Icons.public;
    }
  }

  Widget _buildContent() {
    final content = widget.post['content'] ?? '';
    final isLongContent = content.length > 200;
    final isVeryLongContent =
        content.length > 500; // Only show for very long content

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Content text with side margins and RTL support
        GestureDetector(
          onTap: () {
            // Mark as read when user taps on content
            if (isLongContent && !_userHasReadContent) {
              setState(() {
                _userHasReadContent = true;
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection:
                      widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(
                    // Show AI summary if toggled AND we have a summary, otherwise show content
                    (_showSummary && isVeryLongContent && _aiSummary.isNotEmpty)
                        ? _aiSummary
                        : content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                    // Only limit lines if user hasn't read content yet AND not showing summary
                    maxLines:
                        (!_userHasReadContent && isLongContent && !_showSummary)
                            ? 3
                            : null,
                    overflow: (_userHasReadContent || _showSummary)
                        ? null
                        : TextOverflow.ellipsis,
                    textAlign:
                        widget.isArabic ? TextAlign.right : TextAlign.left,
                  ),
                ),

                // Show "See More" button for long content when user hasn't read it yet
                if (isLongContent && !_userHasReadContent && !_showSummary)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _userHasReadContent = true;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.isArabic ? 'عرض المزيد' : 'See more',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Media attachment - full width without any margins
        if (widget.post['image_url'] != null &&
            widget.post['image_url']!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            color: Colors.red.withOpacity(0.1), // Debug: Add red background
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: GestureDetector(
                onTap: () {
                  if (widget.post['image_url'] != null &&
                      widget.post['image_url']!.isNotEmpty) {
                    _openImageFullscreen(widget.post['image_url']);
                  }
                },
                child: CachedNetworkImage(
                  imageUrl: widget.post['image_url'],
                  width: double.infinity,
                  fit: BoxFit.contain,
                  placeholder: (context, url) {
                    debugPrint('🔥 LOADING IMAGE WITH BoxFit.contain: $url');
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.grey[400]),
                            SizedBox(height: 8),
                            Text('Loading...',
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    );
                  },
                  errorWidget: (context, url, error) {
                    debugPrint('Image error for $url: $error');
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[400],
                        ),
                      ),
                    );
                  },
                  memCacheWidth: 400,
                  memCacheHeight: 300,
                ),
              ),
            ),
          ),
        ],

        // Video attachment
        if (widget.post['video_url'] != null &&
            widget.post['video_url']!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 200,
            child: _isVideoInitialized && _videoController != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(0),
                        child: AspectRatio(
                          aspectRatio:
                              16 / 9, // Force 16:9 aspect ratio like YouTube
                          child: Container(
                            width: double.infinity,
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                      ),
                      // Controls overlay
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                                stops: [0, 0.2, 0.8, 1],
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Center play/pause button
                                Center(
                                  child: AnimatedOpacity(
                                    opacity: _videoController!.value.isPlaying
                                        ? 0.0
                                        : 1.0,
                                    duration: Duration(milliseconds: 300),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _videoController!.value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        size: 48,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                // Bottom controls bar
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  right: 8,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        // Play/Pause button
                                        GestureDetector(
                                          onTap: _togglePlayPause,
                                          child: Icon(
                                            _videoController!.value.isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        // Mute/Unmute button
                                        GestureDetector(
                                          onTap: _toggleMute,
                                          child: Icon(
                                            _isMuted
                                                ? Icons.volume_off
                                                : Icons.volume_up,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        // Volume slider
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                              thumbShape: RoundSliderThumbShape(
                                                  enabledThumbRadius: 6),
                                              trackHeight: 2,
                                              thumbColor: Colors.white,
                                              activeTrackColor: Colors.white,
                                              inactiveTrackColor:
                                                  Colors.white.withOpacity(0.5),
                                              overlayColor: Colors.transparent,
                                            ),
                                            child: Slider(
                                              value: _volume,
                                              min: 0.0,
                                              max: 1.0,
                                              onChanged: _setVolume,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        // Fullscreen button
                                        GestureDetector(
                                          onTap: _openFullscreenVideo,
                                          child: Icon(
                                            Icons.fullscreen,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Duration indicator
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _formatDuration(
                                          _videoController!.value.position),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 8),
                          Text(
                            widget.isArabic
                                ? 'جاري تحميل الفيديو...'
                                : 'Loading video...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    print(
        'Building actions - _isLiked: $_isLiked, _likesCount: $_likesCount, _commentsCount: $_commentsCount, _isSaved: $_isSaved');

    return Column(
      children: [
        if (_showReactionsPicker)
          Container(
            margin: EdgeInsets.only(bottom: 8),
            child: _buildReactionsPicker(),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Row(
            children: [
              _buildActionButtonWithWidget(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                labelWidget: _isLiked
                    ? _buildReactionIcon()
                    : Text('$_likesCount',
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                color: _isLiked ? Colors.red : Colors.grey.shade600,
                buttonName: 'Like',
                onTap: _handleLike,
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                icon: Icons.comment_outlined,
                label: '$_commentsCount',
                color: Colors.grey.shade600,
                onTap: widget.onComment,
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                icon: Icons.share_outlined,
                label: widget.isArabic ? 'مشاركة' : 'Share',
                color: Colors.grey.shade600,
                onTap: widget.onShare,
              ),
              const Spacer(),
              _buildActionButton(
                icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                label: '', // Keep empty to save space
                color: _isSaved ? Colors.red : Colors.grey.shade600,
                onTap: () {
                  print(
                      '🔴 SAVE DEBUG: Tapped save button - _isSaved: $_isSaved');
                  print(
                      '🔴 SAVE DEBUG: Color should be: ${_isSaved ? "Colors.red" : "Colors.grey.shade600"}');
                  print('🔴 SAVE DEBUG: Calling widget.onSave');
                  widget.onSave?.call();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print('Tapped action button: $label');
          if (onTap != null) onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtonWithWidget({
    required IconData icon,
    required Widget labelWidget,
    required Color color,
    required String buttonName, // Add button name for debugging
    VoidCallback? onTap,
  }) {
    print('Building action button with widget: $buttonName');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print('Tapped action button: $buttonName');
          if (onTap != null) onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              labelWidget,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngagementStats() {
    return Row(
      children: [
        Text(
          '$_likesCount ${widget.isArabic ? 'إعجاب' : 'likes'}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        Text(
          ' • ',
          style: TextStyle(color: Colors.grey[400]),
        ),
        Text(
          '$_commentsCount ${widget.isArabic ? 'تعليق' : 'comments'}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildContextualInfo() {
    if (widget.post['type'] == 'job') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.work_outline, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isArabic ? 'فرصة عمل متاحة' : 'Job Opportunity',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    widget.post['company'] ?? 'Tech Company',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Handle job application
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              child: Text(
                widget.isArabic ? 'تقديم' : 'Apply',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.post['type'] == 'question') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isArabic
                        ? 'سؤال يحتاج إجابة'
                        : 'Question needs answer',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${widget.post['experts_available'] ?? 3} ${widget.isArabic ? 'خبراء متاحون' : 'experts available'}',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Handle answer
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              child: Text(
                widget.isArabic ? 'إجابة' : 'Answer',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _handleLike() {
    print('_handleLike called - _showReactionsPicker: $_showReactionsPicker');
    setState(() {
      _showReactionsPicker = !_showReactionsPicker;
    });

    // If hiding picker, call the onLike callback
    if (!_showReactionsPicker) {
      print('Calling widget.onLike from _handleLike');
      widget.onLike?.call();
    }
  }

  void _selectReaction(String reaction) {
    setState(() {
      if (_selectedReaction == reaction) {
        // Remove reaction if same reaction is selected
        _selectedReaction = '';
        _isLiked = false;
        _likesCount--;
      } else if (_selectedReaction.isEmpty) {
        // Add new reaction
        _selectedReaction = reaction;
        _isLiked = true;
        _likesCount++;
      } else {
        // Change reaction
        _selectedReaction = reaction;
      }
      _showReactionsPicker = false;
    });
    widget.onLike?.call();
  }

  Widget _buildReactionsPicker() {
    final reactions = [
      {'emoji': '❤️', 'name': 'love'},
      {'emoji': '👍', 'name': 'like'},
      {'emoji': '😂', 'name': 'haha'},
      {'emoji': '😮', 'name': 'wow'},
      {'emoji': '😢', 'name': 'sad'},
      {'emoji': '😡', 'name': 'angry'},
    ];

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.map((reaction) {
          return GestureDetector(
            onTap: () => _selectReaction(reaction['name']!),
            child: Container(
              padding: EdgeInsets.all(8),
              child: Text(
                reaction['emoji']!,
                style: TextStyle(fontSize: 20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReactionIcon() {
    switch (_selectedReaction) {
      case 'love':
        return Text('❤️', style: TextStyle(fontSize: 16));
      case 'like':
        return Text('👍', style: TextStyle(fontSize: 16));
      case 'haha':
        return Text('😂', style: TextStyle(fontSize: 16));
      case 'wow':
        return Text('😮', style: TextStyle(fontSize: 16));
      case 'sad':
        return Text('😢', style: TextStyle(fontSize: 16));
      case 'angry':
        return Text('😡', style: TextStyle(fontSize: 16));
      default:
        return Text('👍', style: TextStyle(fontSize: 16));
    }
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';

    final DateTime postTime = DateTime.parse(createdAt);
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(postTime);

    if (difference.inMinutes < 1) {
      return widget.isArabic ? 'الآن' : 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${widget.isArabic ? 'دقيقة' : 'm'}';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${widget.isArabic ? 'ساعة' : 'h'}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${widget.isArabic ? 'يوم' : 'd'}';
    } else {
      return '${postTime.day}/${postTime.month}/${postTime.year}';
    }
  }

  String _generateSummary(String content) {
    // Simple summary generation - in real app, this would call AI service
    final words = content.split(' ');
    if (words.length <= 20) return content;

    return words.take(20).join(' ') + '...';
  }

  Future<void> _toggleSummary() async {
    if (_isLoadingSummary) return;

    setState(() {
      _showSummary = !_showSummary;
    });

    final content = widget.post['content'] ?? '';
    final isVeryLongContent = content.length > 500;

    // If showing summary and we don't have one yet, generate it
    if (_showSummary &&
        _aiSummary.isEmpty &&
        (widget.post['ai_summary'] == null ||
            widget.post['ai_summary'].toString().isEmpty)) {
      await _generateAISummary();
    }
  }

  Future<void> _generateAISummary() async {
    print('_generateAISummary called...');
    setState(() {
      _isLoadingSummary = true;
    });

    try {
      final content = widget.post['content'] ?? '';
      final postMode = widget.post['post_mode'] as String? ?? 'general';

      print('Calling AI service with content length: ${content.length}');
      final summary = await AISummaryService.generateSmartSummary(
        content,
        postMode: postMode,
        isArabic: widget.isArabic,
      );

      print('AI summary received: $summary');

      setState(() {
        _aiSummary = summary;
        _isLoadingSummary = false;
      });
    } catch (e) {
      print('Error generating AI summary: $e');
      setState(() {
        _aiSummary = _generateSummary(widget.post['content'] ?? '');
        _isLoadingSummary = false;
      });
    }
  }
}
