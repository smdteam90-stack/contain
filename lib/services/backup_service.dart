import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/saved_link.dart';

/// Builds, shares, and restores JSON backup files for the whole library or
/// a single folder. "Save a backup" and "share a backup" are the same
/// action here — handing the file to the system share sheet already lets
/// the user save it to Drive, Files, Telegram, etc.
class BackupService {
  static const _wholeType = 'reelbox-backup';
  static const _folderType = 'reelbox-folder-backup';

  String _buildWhole(List<SavedLink> links, List<String> folders) => jsonEncode({
        'app': _wholeType,
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'folders': folders,
        'links': links.map((e) => e.toJson()).toList(),
      });

  String _buildFolder(String folder, List<SavedLink> links) => jsonEncode({
        'app': _folderType,
        'version': 1,
        'folder': folder,
        'exportedAt': DateTime.now().toIso8601String(),
        'links': links
            .where((e) => e.folder == folder)
            .map((e) => e.toJson())
            .toList(),
      });

  Future<void> shareWholeBackup(List<SavedLink> links, List<String> folders) async {
    await _shareJson(_buildWhole(links, folders), 'reelbox-backup.json');
  }

  Future<void> shareFolderBackup(String folder, List<SavedLink> links) async {
    final safeName = folder.replaceAll(RegExp(r'[^\w\-]+'), '_');
    await _shareJson(_buildFolder(folder, links), 'reelbox-$safeName-backup.json');
  }

  Future<void> _shareJson(String json, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')]);
  }

  /// Lets the user pick a previously saved backup file (whole-library or
  /// single-folder) and returns what was in it, or null if the user
  /// cancelled or the file wasn't a recognizable Reelbox backup.
    Future<BackupData?> pickBackup() async {
    final pickedFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (pickedFile == null) return null;

    final path = pickedFile.path;
    if (path == null) return null;

    try {
      final raw = await File(path).readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final app = data['app'] as String?;

      if (app == _wholeType) {
        final links = (data['links'] as List<dynamic>)
            .map((e) => SavedLink.fromJson(e as Map<String, dynamic>))
            .toList();

        final folders =
            (data['folders'] as List<dynamic>?)?.cast<String>() ?? [];

        return BackupData(
          links: links,
          folders: folders,
        );
      }

      if (app == _folderType) {
        final links = (data['links'] as List<dynamic>)
            .map((e) => SavedLink.fromJson(e as Map<String, dynamic>))
            .toList();

        final folder = data['folder'] as String? ?? '';

        return BackupData(
          links: links,
          folders: folder.isEmpty ? [] : [folder],
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }
