import 'dart:convert';

import 'package:http/http.dart' as http;

/// Figures out the source app and, where possible, a channel/handle name
/// directly from the shared URL, without any network request. Also offers
/// a best-effort thumbnail lookup via the page's Open Graph metadata.
class LinkMetaService {
  static String sourceFor(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (_endsWithHost(host, 'instagram.com')) return 'Instagram';
    if (_endsWithHost(host, 'youtube.com') || _endsWithHost(host, 'youtu.be')) {
      return 'YouTube';
    }
    if (_endsWithHost(host, 'tiktok.com')) return 'TikTok';
    if (_endsWithHost(host, 't.me') || _endsWithHost(host, 'telegram.me')) {
      return 'Telegram';
    }
    return 'Web';
  }

  /// Best-effort guess at a channel/handle from the URL path itself.
  /// Returns '' when nothing reliable can be extracted -- the field stays
  /// optional and the user can fill it in by hand.
  static String guessChannel(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return '';

    final source = sourceFor(url);
    switch (source) {
      case 'Instagram':
        const reserved = {'reel', 'reels', 'p', 'stories', 'tv', 'explore'};
        if (!reserved.contains(segments.first.toLowerCase())) {
          return '@' + segments.first;
        }
        return '';
      case 'TikTok':
        if (segments.first.startsWith('@')) return segments.first;
        return '';
      case 'Telegram':
        return '@' + segments.first;
      default:
        return '';
    }
  }

  /// Best-effort: fetches the page and reads its Open Graph image tag.
  /// Many apps (Instagram, TikTok) block this without login, so a null
  /// result here is normal and expected, not an error.
  static Future<String?> fetchThumbnail(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final patterns = [
        RegExp(
          '<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)["\']',
          caseSensitive: false,
        ),
        RegExp(
          '<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:image["\']',
          caseSensitive: false,
        ),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(body);
        final imageUrl = match?.group(1);
        if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _endsWithHost(String host, String suffix) =>
      host == suffix || host.endsWith('.' + suffix);
}
