import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/recipes/utils/video_link_parser.dart';

void main() {
  group('VideoLinkParser.parse', () {
    test('parses standard YouTube URL', () {
      final info = VideoLinkParser.parse(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(info.platform, VideoPlatform.youtube);
      expect(info.videoId, 'dQw4w9WgXcQ');
    });

    test('parses YouTube short URL', () {
      final info = VideoLinkParser.parse('https://youtu.be/dQw4w9WgXcQ');
      expect(info.platform, VideoPlatform.youtube);
      expect(info.videoId, 'dQw4w9WgXcQ');
    });

    test('parses YouTube embed URL', () {
      final info = VideoLinkParser.parse(
        'https://www.youtube.com/embed/dQw4w9WgXcQ',
      );
      expect(info.platform, VideoPlatform.youtube);
      expect(info.videoId, 'dQw4w9WgXcQ');
    });

    test('parses YouTube Shorts URL', () {
      final info = VideoLinkParser.parse(
        'https://www.youtube.com/shorts/dQw4w9WgXcQ',
      );
      expect(info.platform, VideoPlatform.youtube);
      expect(info.videoId, 'dQw4w9WgXcQ');
    });

    test('parses YouTube URL without www', () {
      final info = VideoLinkParser.parse(
        'https://youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(info.platform, VideoPlatform.youtube);
      expect(info.videoId, 'dQw4w9WgXcQ');
    });

    test('parses Vimeo URL', () {
      final info = VideoLinkParser.parse('https://vimeo.com/123456789');
      expect(info.platform, VideoPlatform.vimeo);
      expect(info.videoId, '123456789');
    });

    test('parses TikTok URL', () {
      final info = VideoLinkParser.parse(
        'https://www.tiktok.com/@user/video/123',
      );
      expect(info.platform, VideoPlatform.tiktok);
      expect(info.videoId, isNull);
    });

    test('parses Instagram reel URL', () {
      final info = VideoLinkParser.parse(
        'https://www.instagram.com/reel/ABC123/',
      );
      expect(info.platform, VideoPlatform.instagram);
    });

    test('parses Instagram post URL', () {
      final info = VideoLinkParser.parse('https://www.instagram.com/p/ABC123/');
      expect(info.platform, VideoPlatform.instagram);
    });

    test('returns other for unknown URL', () {
      final info = VideoLinkParser.parse('https://example.com/video');
      expect(info.platform, VideoPlatform.other);
      expect(info.videoId, isNull);
    });

    test('preserves original URL', () {
      const url = 'https://youtu.be/dQw4w9WgXcQ';
      final info = VideoLinkParser.parse(url);
      expect(info.url, url);
    });
  });

  group('VideoLinkInfo.thumbnailUrl', () {
    test('returns YouTube thumbnail for YouTube videos', () {
      final info = VideoLinkParser.parse('https://youtu.be/dQw4w9WgXcQ');
      expect(
        info.thumbnailUrl,
        'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );
    });

    test('returns null for non-YouTube videos', () {
      final info = VideoLinkParser.parse('https://vimeo.com/123456789');
      expect(info.thumbnailUrl, isNull);
    });
  });

  group('VideoLinkParser.platformLabel', () {
    test('returns correct labels', () {
      expect(VideoLinkParser.platformLabel(VideoPlatform.youtube), 'YouTube');
      expect(VideoLinkParser.platformLabel(VideoPlatform.vimeo), 'Vimeo');
      expect(VideoLinkParser.platformLabel(VideoPlatform.tiktok), 'TikTok');
      expect(
        VideoLinkParser.platformLabel(VideoPlatform.instagram),
        'Instagram',
      );
      expect(VideoLinkParser.platformLabel(VideoPlatform.other), 'Video');
    });
  });
}
