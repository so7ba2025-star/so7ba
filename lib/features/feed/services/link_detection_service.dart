import 'dart:io';

// Link type enumeration
enum LinkType { none, image, video, regular }

// Link information class
class LinkInfo {
  final LinkType type;
  final String url;
  final String? embedUrl;

  LinkInfo({
    required this.type,
    required this.url,
    this.embedUrl,
  });

  @override
  String toString() {
    return 'LinkInfo(type: $type, url: $url, embedUrl: $embedUrl)';
  }
}

// Link detection service
class LinkDetectionService {
  static final LinkDetectionService _instance =
      LinkDetectionService._internal();
  factory LinkDetectionService() => _instance;
  LinkDetectionService._internal();

  // Image file extensions
  static const Set<String> _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'svg',
    'ico',
    'tiff',
    'tif'
  };

  // Video file extensions
  static const Set<String> _videoExtensions = {
    'mp4',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    'mkv',
    'm4v',
    '3gp',
    'ogv'
  };

  // Common video hosting domains
  static const Set<String> _videoHosts = {
    'youtube.com',
    'youtu.be',
    'vimeo.com',
    'dailymotion.com',
    'twitch.tv',
    'facebook.com',
    'instagram.com',
    'twitter.com',
    'tiktok.com',
    'bilibili.com',
    'vine.co',
    'vid.me'
  };

  // Common image hosting domains
  static const Set<String> _imageHosts = {
    'imgur.com',
    'flickr.com',
    'instagram.com',
    'facebook.com',
    'twitter.com',
    'pinterest.com',
    'unsplash.com',
    'pixabay.com',
    'stock.adobe.com',
    'gettyimages.com',
    'shutterstock.com'
  };

  LinkInfo detectLink(String text) {
    if (text.isEmpty) return LinkInfo(type: LinkType.none, url: '');

    // Find URLs in text using regex
    final urlPattern = RegExp(
      r'(https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*))',
      caseSensitive: false,
    );

    final matches = urlPattern.allMatches(text);
    if (matches.isEmpty) return LinkInfo(type: LinkType.none, url: '');

    // Get the first URL found
    final url = matches.first.group(1)!;
    final uri = Uri.tryParse(url);

    if (uri == null || !uri.hasAbsolutePath) {
      return LinkInfo(type: LinkType.regular, url: url);
    }

    // Check if it's a video
    if (_isVideoUrl(uri, url)) {
      return LinkInfo(type: LinkType.video, url: url);
    }

    // Check if it's an image
    if (_isImageUrl(uri, url)) {
      return LinkInfo(type: LinkType.image, url: url);
    }

    // Default to regular link
    return LinkInfo(type: LinkType.regular, url: url);
  }

  bool _isVideoUrl(Uri uri, String url) {
    // Check file extension
    final path = uri.path.toLowerCase();
    if (_videoExtensions.any((ext) => path.endsWith('.$ext'))) {
      return true;
    }

    // Check hosting domains
    final host = uri.host.toLowerCase();
    if (_videoHosts.any((videoHost) => host.contains(videoHost))) {
      return true;
    }

    // Check YouTube specific patterns
    if (host.contains('youtube.com') && uri.queryParameters.containsKey('v')) {
      return true;
    }
    if (host.contains('youtu.be')) {
      return true;
    }

    // Check Facebook specific patterns
    if (host.contains('facebook.com')) {
      // Facebook share links: https://www.facebook.com/share/v/VIDEO_ID/
      if (path.contains('/share/v/') || path.contains('/share/reel/')) {
        return true;
      }
      // Facebook video URLs: https://www.facebook.com/watch?v=VIDEO_ID
      if (path.contains('/watch') && uri.queryParameters.containsKey('v')) {
        return true;
      }
      // Facebook videos: https://www.facebook.com/USER/videos/VIDEO_ID/
      if (path.contains('/videos/')) {
        return true;
      }
    }

    return false;
  }

  bool _isImageUrl(Uri uri, String url) {
    // Check file extension
    final path = uri.path.toLowerCase();
    if (_imageExtensions.any((ext) => path.endsWith('.$ext'))) {
      return true;
    }

    // Check hosting domains
    final host = uri.host.toLowerCase();
    if (_imageHosts.any((imageHost) => host.contains(imageHost))) {
      return true;
    }

    // Check for direct image URLs (common patterns)
    if (path.contains('/image/') ||
        path.contains('/img/') ||
        path.contains('/photo/') ||
        url.contains('i.imgur.com') ||
        url.contains('pbs.twimg.com/media/')) {
      return true;
    }

    return false;
  }

  // Extract all links from text
  List<LinkInfo> extractAllLinks(String text) {
    if (text.isEmpty) return [];

    final urlPattern = RegExp(
      r'(https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*))',
      caseSensitive: false,
    );

    final matches = urlPattern.allMatches(text);
    return matches.map((match) {
      final url = match.group(1)!;
      final uri = Uri.tryParse(url);

      if (uri == null || !uri.hasAbsolutePath) {
        return LinkInfo(type: LinkType.regular, url: url);
      }

      if (_isVideoUrl(uri, url)) {
        return LinkInfo(type: LinkType.video, url: url);
      }

      if (_isImageUrl(uri, url)) {
        return LinkInfo(type: LinkType.image, url: url);
      }

      return LinkInfo(type: LinkType.regular, url: url);
    }).toList();
  }

  // Convert YouTube URL to embed format
  String? getYouTubeEmbedUrl(String youtubeUrl) {
    final uri = Uri.tryParse(youtubeUrl);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();

    if (host.contains('youtube.com') && uri.queryParameters.containsKey('v')) {
      final videoId = uri.queryParameters['v'];
      return 'https://www.youtube.com/embed/$videoId';
    }

    if (host.contains('youtu.be')) {
      final videoId =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      return videoId != null ? 'https://www.youtube.com/embed/$videoId' : null;
    }

    return null;
  }

  // Get display text for regular links
  String getDisplayText(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    String displayText = uri.host;
    if (displayText.startsWith('www.')) {
      displayText = displayText.substring(4);
    }

    // Add path if it's not too long
    final path = uri.path;
    if (path.length > 1 && path.length < 30) {
      displayText += path;
    } else if (path.length >= 30) {
      displayText += '/...';
    }

    return displayText;
  }
}
