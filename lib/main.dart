import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/saved_link.dart';
import 'screens/save_link_screen.dart';
import 'services/share_intent_service.dart';
import 'services/storage_service.dart';
import 'widgets/link_card.dart';

void main() => runApp(const ContentLibraryApp());

class ContentLibraryApp extends StatelessWidget {
  const ContentLibraryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'کتابخانه من',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fa'),
        localizationsDelegates: [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6750a4)),
          useMaterial3: true,
        ),
        home: const LibraryHome(),
      );
}

class LibraryHome extends StatefulWidget {
  const LibraryHome({super.key});

  @override
  State<LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends State<LibraryHome> {
  final _search = TextEditingController();
  final _storage = StorageService();
  final _shareService = ShareIntentService();

  List<SavedLink> _links = [];
  String _folder = 'همه';
  bool _loading = true;

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
    setState(() {
      _links = links;
      _loading = false;
    });
  }

  Future<void> _persist() => _storage.saveLinks(_links);

  Set<String> get _folders => {'همه', ..._links.map((e) => e.folder)};

  List<SavedLink> get _visible {
    final query = _search.text.trim().toLowerCase();
    return _links.where((item) {
      final inFolder = _folder == 'همه' || item.folder == _folder;
      final text = '${item.title} ${item.url} ${item.description} ${item.channel} ${item.source}'.toLowerCase();
      return inFolder && (query.isEmpty || text.contains(query));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Called whenever a link arrives via the Android share sheet, from
  // any app (Instagram, YouTube, Telegram, a browser, ...), whether the
  // app was already open or was launched fresh by the share action.
  Future<void> _onSharedUrl(String sharedText) async {
    final url = _extractUrl(sharedText);
    if (url == null) return;
    if (!mounted) return;
    final result = await Navigator.push<SavedLink>(
      context,
      MaterialPageRoute(
        builder: (_) => SaveLinkScreen(
          sharedUrl: url,
          existingFolders: _links.map((e) => e.folder).toSet().toList()..sort(),
        ),
      ),
    );
    if (result == null) return;
    _addOrRejectDuplicate(result);
  }

  Future<void> _addLinkManually() async {
    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('افزودن لینک'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(hintText: 'https://...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                final parsed = Uri.tryParse(value);
                if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) return;
                Navigator.pop(context, value);
              },
              child: const Text('ادامه'),
            ),
          ],
        );
      },
    );
    if (url == null) return;
    await _onSharedUrl(url);
  }

  void _addOrRejectDuplicate(SavedLink result) {
    final normalized = _normalizeUrl(result.url);
    final isDuplicate = _links.any((item) => _normalizeUrl(item.url) == normalized);
    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('این لینک قبلاً ذخیره شده است.')),
      );
      return;
    }
    setState(() => _links.add(result));
    _persist();
  }

  Future<void> _open(SavedLink item) async {
    await Clipboard.setData(ClipboardData(text: item.url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لینک کپی شد؛ آن را در برنامه یا مرورگر دلخواه باز کنید.')),
      );
    }
  }

  void _toggleWatched(SavedLink item) {
    setState(() => item.watched = !item.watched);
    _persist();
  }

  void _delete(SavedLink item) {
    setState(() {
      _links.removeWhere((x) => x.id == item.id);
      // If the folder this item lived in no longer has any links and it
      // was the active filter, fall back to "همه" so the user never lands
      // on a silently-empty filtered view.
      if (_folder != 'همه' && !_links.any((x) => x.folder == _folder)) {
        _folder = 'همه';
      }
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(title: const Text('کتابخانه من')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLinkManually,
        icon: const Icon(Icons.add_link),
        label: const Text('افزودن لینک'),
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
                hintText: 'جست‌وجو در لینک‌ها…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _folders
                  .map(
                    (name) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: _folder == name,
                        onSelected: (_) => setState(() => _folder = name),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    itemCount: visible.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LinkCard(
                        item: visible[i],
                        onOpen: () => _open(visible[i]),
                        onWatched: () => _toggleWatched(visible[i]),
                        onDelete: () => _delete(visible[i]),
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 64),
            SizedBox(height: 12),
            Text('هنوز لینکی ذخیره نشده است.'),
            SizedBox(height: 4),
            Text('یک لینک را از برنامهٔ دیگری با «اشتراک‌گذاری» ارسال کن.'),
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
