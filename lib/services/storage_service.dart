import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_link.dart';

/// Persists saved links to on-device storage so they survive app restarts.
class StorageService {
  static const _key = 'content_library.saved_links.v1';

  Future<List<SavedLink>> loadLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return SavedLink.decodeList(raw);
    } catch (_) {
      // Corrupt data should never crash the app on launch.
      return [];
    }
  }

  Future<void> saveLinks(List<SavedLink> links) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, SavedLink.encodeList(links));
  }
}
