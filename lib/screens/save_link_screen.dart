import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/saved_link.dart';
import '../services/link_meta_service.dart';

/// Shown right after a link arrives via share (or via the manual "+" menu),
/// and reused (with [existing] set) to edit a link that was already saved.
class SaveLinkScreen extends StatefulWidget {
  const SaveLinkScreen({
    super.key,
    required this.languageCode,
    required this.sharedUrl,
    required this.existingFolders,
    this.existing,
  });

  final String languageCode;
  final String sharedUrl;
  final List<String> existingFolders;
  final SavedLink? existing;

  @override
  State<SaveLinkScreen> createState() => _SaveLinkScreenState();
}

class _SaveLinkScreenState extends State<SaveLinkScreen> {
  late final TextEditingController _title;
  late final TextEditingController _channel;
  late final TextEditingController _description;
  late final TextEditingController _newFolder;
  String? _selectedFolder;
  bool _creatingNewFolder = false;
  String? _thumbnailUrl;
  bool _fetchingThumbnail = false;

  AppStrings get _s => AppStrings(widget.languageCode);
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final source = LinkMetaService.sourceFor(widget.sharedUrl);
    _title = TextEditingController(text: existing?.title ?? source);
    _channel = TextEditingController(
      text: existing?.channel ?? LinkMetaService.guessChannel(widget.sharedUrl),
    );
    _description = TextEditingController(text: existing?.description ?? '');
    _newFolder = TextEditingController();
    _thumbnailUrl = existing?.thumbnailUrl;
    _selectedFolder = existing?.folder ??
        (widget.existingFolders.isNotEmpty ? widget.existingFolders.first : null);
    if (widget.existingFolders.isEmpty && !_isEditing) _creatingNewFolder = true;
    if (!_isEditing) _fetchThumbnail();
  }

  Future<void> _fetchThumbnail() async {
    setState(() => _fetchingThumbnail = true);
    final url = await LinkMetaService.fetchThumbnail(widget.sharedUrl);
    if (!mounted) return;
    setState(() {
      _thumbnailUrl = url;
      _fetchingThumbnail = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _channel.dispose();
    _description.dispose();
    _newFolder.dispose();
    super.dispose();
  }

  void _save() {
    final folder = _creatingNewFolder ? _newFolder.text.trim() : (_selectedFolder ?? '');
    if (folder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_s.t('folderRequiredError'))),
      );
      return;
    }
    final source = LinkMetaService.sourceFor(widget.sharedUrl);
    final existing = widget.existing;
    final link = SavedLink(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      url: widget.sharedUrl,
      title: _title.text.trim().isEmpty ? source : _title.text.trim(),
      folder: folder,
      source: existing?.source ?? source,
      channel: _channel.text.trim(),
      description: _description.text.trim(),
      thumbnailUrl: _thumbnailUrl,
      createdAt: existing?.createdAt ?? DateTime.now(),
      watched: existing?.watched ?? false,
    );
    Navigator.pop(context, link);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? _s.t('editTitle') : _s.t('saveTitle'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.sharedUrl,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            ),
            if (_fetchingThumbnail) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ] else if (_thumbnailUrl != null && _thumbnailUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    _thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(_s.t('folderRequiredLabel'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...widget.existingFolders.map(
                  (f) => ChoiceChip(
                    label: Text(f),
                    selected: !_creatingNewFolder && _selectedFolder == f,
                    onSelected: (_) => setState(() {
                      _creatingNewFolder = false;
                      _selectedFolder = f;
                    }),
                  ),
                ),
                ChoiceChip(
                  label: Text(_s.t('newFolderChip')),
                  selected: _creatingNewFolder,
                  onSelected: (_) => setState(() => _creatingNewFolder = true),
                ),
              ],
            ),
            if (_creatingNewFolder) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _newFolder,
                decoration: InputDecoration(
                  labelText: _s.t('folderNameLabel'),
                  hintText: _s.t('folderNameHint'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: _s.t('titleLabel'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _channel,
              decoration: InputDecoration(
                labelText: _s.t('channelLabel'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _s.t('descriptionLabel'),
                hintText: _s.t('descriptionHint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(_s.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}
