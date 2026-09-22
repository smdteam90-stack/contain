/// Figures out the source app and, where possible, a channel/handle name
/// directly from the shared URL, without any network request.
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
  /// Works for profile-style paths (e.g. instagram.com/someuser/...,
  /// t.me/somechannel/123, tiktok.com/@someuser/video/...).
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

  static bool _endsWithHost(String host, String suffix) =>
      host == suffix || host.endsWith('.' + suffix);
}
