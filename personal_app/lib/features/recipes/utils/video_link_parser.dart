// Utilities for parsing video URLs and extracting platform-specific metadata.

class VideoLinkInfo {
  final String url;
  final VideoPlatform platform;
  final String? videoId;

  const VideoLinkInfo({
    required this.url,
    required this.platform,
    this.videoId,
  });

  /// YouTube thumbnail URL.
  String? get thumbnailUrl {
    if (platform == VideoPlatform.youtube && videoId != null) {
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }
    return null;
  }
}

enum VideoPlatform { youtube, vimeo, tiktok, instagram, other }

class VideoLinkParser {
  static final _youtubePatterns = [
    // youtube.com/watch?v=VIDEO_ID
    RegExp(
      r'(?:https?://)?(?:www\.)?youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})',
    ),
    // youtu.be/VIDEO_ID
    RegExp(r'(?:https?://)?youtu\.be/([a-zA-Z0-9_-]{11})'),
    // youtube.com/embed/VIDEO_ID
    RegExp(r'(?:https?://)?(?:www\.)?youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
    // youtube.com/shorts/VIDEO_ID
    RegExp(r'(?:https?://)?(?:www\.)?youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
  ];

  static final _vimeoPattern = RegExp(
    r'(?:https?://)?(?:www\.)?vimeo\.com/(\d+)',
  );

  static final _tiktokPattern = RegExp(r'(?:https?://)?(?:www\.)?tiktok\.com/');

  static final _instagramPattern = RegExp(
    r'(?:https?://)?(?:www\.)?instagram\.com/(?:reel|p)/',
  );

  /// Parse a URL into a [VideoLinkInfo] with detected platform and video ID.
  static VideoLinkInfo parse(String url) {
    // YouTube
    for (final pattern in _youtubePatterns) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        return VideoLinkInfo(
          url: url,
          platform: VideoPlatform.youtube,
          videoId: match.group(1),
        );
      }
    }

    // Vimeo
    final vimeoMatch = _vimeoPattern.firstMatch(url);
    if (vimeoMatch != null) {
      return VideoLinkInfo(
        url: url,
        platform: VideoPlatform.vimeo,
        videoId: vimeoMatch.group(1),
      );
    }

    // TikTok
    if (_tiktokPattern.hasMatch(url)) {
      return VideoLinkInfo(url: url, platform: VideoPlatform.tiktok);
    }

    // Instagram
    if (_instagramPattern.hasMatch(url)) {
      return VideoLinkInfo(url: url, platform: VideoPlatform.instagram);
    }

    return VideoLinkInfo(url: url, platform: VideoPlatform.other);
  }

  /// Returns a human-readable label for the platform.
  static String platformLabel(VideoPlatform platform) {
    switch (platform) {
      case VideoPlatform.youtube:
        return 'YouTube';
      case VideoPlatform.vimeo:
        return 'Vimeo';
      case VideoPlatform.tiktok:
        return 'TikTok';
      case VideoPlatform.instagram:
        return 'Instagram';
      case VideoPlatform.other:
        return 'Video';
    }
  }
}
