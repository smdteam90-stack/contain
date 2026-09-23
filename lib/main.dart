import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/app_strings.dart';
import 'models/saved_link.dart';
import 'screens/save_link_screen.dart';
import 'screens/settings_screen.dart';
import 'services/settings_service.dart';
import 'services/share_intent_service.dart';
import 'services/storage_service.dart';
import 'widgets/link_card.dart';

void main() => runApp(const ContentLibraryApp());

/// Root widget. Owns the app-wide settings (theme, language, text scale) so
/// changing them in the Settings screen updates the whole app immediately.
class ContentLibraryApp extends StatefulWidget {
  const ContentLibraryApp({super.key});

  @override
  State<ContentLibraryApp> createState() => _ContentLibraryAppState();
}

class _ContentLibraryAppState extends State<ContentLibraryApp> {
  final _settingsService = SettingsService();
  AppSettings _settings = AppSettings.defaults;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _settingsLoaded = true;
    });
  }

  void _updateSettings(AppSettings settings) {
    setState(() => _settings = settings);
    _settingsService.save(settings);
  }

  ThemeMode get _themeMode => switch (_settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(_settings.languageCode);
    return MaterialApp(
      title: s.t('appTitle'),
      debugShowCheckedModeBanner: false,
      locale: Locale(_settings.languageCode),
      supportedLocales: const [
        Locale('fa'),
        Locale('en'),
        Locale('ar'),
        Locale('es'),
        Locale('fr'),
        Locale('tr'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6750a4)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff6750a4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(_settings.textScale),
        ),
        child: child!,
      ),
      home: _settingsLoaded
          ? LibraryHome(settings: _settings, onSettingsChanged: _updateSettings)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class LibraryHome extends StatefulWidget {
  const LibraryHome({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  State<LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends State<LibraryHome> {
  final _search = TextEditingController();
  final _storage = StorageService();
  final _shareService = ShareIntentService();

  List<SavedLink> _links = [];
  List<String> _folders = [];
  String _activeFolder = ''; // '' means "all folders"
  bool _loading = true;

  AppStrings get _s => AppStrings(widget.settings.languageCode);

  @override
  void initState() {
    super.initState();
    _loadFromDisk();
    _shareService.start(_onSharedUrl);
  }

  @override
  void dispose() {
    _search.dispose();
    _shareService.dispose();
    super.dispose();
  }

  Future<void> _loadFromDisk() async {
    final links = await _storage.loadLinks();
    final storedFolders = await _storage.loadFolders();
    final folderNames = <String>{...storedFolders, ...links.map((e) => e.folder)}.toList()..sort();
    if (!mounted) return;
    setState(() {
      _links = links;
      _folders = folderNames;
      _loading = false;
    });
  }

  Future<void> _persistLinks() => _storage.saveLinks(_links);
  Future<void> _persistFolders() => _storage.saveFolders(_folders);

  List<SavedLink> get _visible {
    final query = _search.text.trim().toLowerCase();
    return _links.where((item) {
      final inFolder = _activeFolder.isEmpty || item.folder == _activeFolder;
      final text =
          '${item.title} ${item.url} ${item.description} ${item.channel} ${item.source}'
              .toLowerCase();
      return inFolder && (query.isEmpty || text.contains(query));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Called whenever a link arrives via the Android share sheet, from any
  // app (Instagram, YouTube, TikTok, Telegram, a browser, ...), whether the
  // app was already open or was launched fresh by the share action.
  Future<void> _onSharedUrl(String sharedText) async {
    final url = _extractUrl(sharedText);
    if (url == null) return;
    if (!mounted) return;
    final result = await Navigator.push<SavedLink>(
      context,
      MaterialPageRoute(
        builder: (_) => SaveLinkScreen(
          languageCode: widget.settings.languageCode,
          sharedUrl: url,
          existingFolders: _folders,
        ),
      ),
    );
    if (result == null) return;
    _addNewFolderIfNeeded(result.folder);
    _addOrRejectDuplicate(result);
  }

  Future<void> _addLinkManually() async {
    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(_s.t('addLink')),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(hintText: 'https://...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(_s.t('cancel'))),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                final parsed = Uri.tryParse(value);
                if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) return;
                Navigator.pop(context, value);
              },
              child: Text(_s.t('continueLabel')),
            ),
          ],
        );
      },
    );
    if (url == null) return;
    await _onSharedUrl(url);
  }

  Future<void> _addFolderManually() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.t('newFolderTitle')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: _s.t('folderNameLabel'),
            hintText: _s.t('folderNameHint'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_s.t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(_s.t('create')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    _addNewFolderIfNeeded(name);
  }

  void _addNewFolderIfNeeded(String name) {
    if (name.isEmpty || _folders.contains(name)) return;
    setState(() => _folders = [..._folders, name]..sort());
    _persistFolders();
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.add_link),
              title: Text(_s.t('addLink')),
              onTap: () {
                Navigator.pop(context);
                _addLinkManually();
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(_s.t('addFolder')),
              onTap: () {
                Navigator.pop(context);
                _addFolderManually();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addOrRejectDuplicate(SavedLink result) {
    final normalized = _normalizeUrl(result.url);
    final isDuplicate = _links.any((item) => _normalizeUrl(item.url) == normalized);
    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_s.t('duplicateLinkMsg'))),
      );
      return;
    }
    setState(() => _links = [..._links, result]);
    _persistLinks();
  }

  Future<void> _open(SavedLink item) async {
    final uri = Uri.tryParse(item.url);
    final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_s.t('openFailedMsg'))),
      );
    }
  }

  void _shareLink(SavedLink item) {
    Share.share(item.url);
  }

  void _toggleWatched(SavedLink item) {
    final updated = item.copyWith(watched: !item.watched);
    setState(() {
      final index = _links.indexWhere((x) => x.id == item.id);
      if (index != -1) _links[index] = updated;
    });
    _persistLinks();
  }

  Future<void> _editLink(SavedLink item) async {
    final result = await Navigator.push<SavedLink>(
      context,
      MaterialPageRoute(
        builder: (_) => SaveLinkScreen(
          languageCode: widget.settings.languageCode,
          sharedUrl: item.url,
          existingFolders: _folders,
          existing: item,
        ),
      ),
    );
    if (result == null) return;
    _addNewFolderIfNeeded(result.folder);
    setState(() {
      final index = _links.indexWhere((x) => x.id == item.id);
      if (index != -1) _links[index] = result;
    });
    _persistLinks();
  }

  Future<void> _moveLink(SavedLink item) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_s.t('moveToFolderTitle')),
        children: _folders
            .map((f) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, f),
                  child: Text(f),
                ))
            .toList(),
      ),
    );
    if (chosen == null || chosen == item.folder) return;
    final updated = item.copyWith(folder: chosen);
    setState(() {
      final index = _links.indexWhere((x) => x.id == item.id);
      if (index != -1) _links[index] = updated;
    });
    _persistLinks();
  }

  Future<void> _confirmDelete(SavedLink item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.t('deleteConfirmTitle')),
        content: Text(_s.t('deleteConfirmBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_s.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_s.t('deleteLabel')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _links.removeWhere((x) => x.id == item.id);
      final folderStillHasLinks = _links.any((x) => x.folder == _activeFolder);
      final folderStillExists = _folders.contains(_activeFolder);
      if (_activeFolder.isNotEmpty && !folderStillHasLinks && !folderStillExists) {
        _activeFolder = '';
      }
    });
    _persistLinks();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settings: widget.settings,
          onChanged: widget.onSettingsChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final visible = _visible;
    final allLabel = _s.t('allFolder');
    return Scaffold(
      appBar: AppBar(
        title: Text(_s.t('appTitle')),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _openSettings),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenu,
        icon: const Icon(Icons.add),
        label: Text(_s.t('addLink')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: _s.t('searchHint'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(allLabel),
                    selected: _activeFolder.isEmpty,
                    onSelected: (_) => setState(() => _activeFolder = ''),
                  ),
                ),
                ..._folders.map(
                  (name) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: _activeFolder == name,
                      onSelected: (_) => setState(() => _activeFolder = name),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? _EmptyState(s: _s)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    itemCount: visible.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LinkCard(
                        item: visible[i],
                        s: _s,
                        onOpen: () => _open(visible[i]),
                        onWatched: () => _toggleWatched(visible[i]),
                        onDelete: () => _confirmDelete(visible[i]),
                        onEdit: () => _editLink(visible[i]),
                        onMove: () => _moveLink(visible[i]),
                        onShare: () => _shareLink(visible[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.s});
  final AppStrings s;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border, size: 64),
            const SizedBox(height: 12),
            Text(s.t('emptyTitle')),
            const SizedBox(height: 4),
            Text(s.t('emptySubtitle')),
          ],
        ),
      );
}

/// Pulls a usable URL out of whatever the share sheet handed us -- some
/// apps send the raw URL, others send a sentence with the URL inside it.
String? _extractUrl(String sharedText) {
  final direct = Uri.tryParse(sharedText.trim());
  if (direct != null && direct.hasScheme && direct.hasAuthority) {
    return sharedText.trim();
  }
  final match = RegExp(r'https?://\S+').firstMatch(sharedText);
  return match?.group(0);
}

String _normalizeUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return url.trim().toLowerCase();
  final path = uri.path.endsWith('/') && uri.path.length > 1
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  return '${uri.host.toLowerCase()}$path'; // ignore scheme, query, fragment
}
