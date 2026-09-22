import 'package:flutter/material.dart';

import '../models/saved_link.dart';
import '../services/link_meta_service.dart';

/// Shown right after a link arrives via share (or via the manual "+" button).
/// Folder is required (pick or create), channel and description are optional.
class SaveLinkScreen extends StatefulWidget {
  const SaveLinkScreen({
    super.key,
    required this.sharedUrl,
    required this.existingFolders,
  });

  final String sharedUrl;
  final List<String> existingFolders;

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

  @override
  void initState() {
    super.initState();
    final source = LinkMetaService.sourceFor(widget.sharedUrl);
    _title = TextEditingController(text: source);
    _channel = TextEditingController(text: LinkMetaService.guessChannel(widget.sharedUrl));
    _description = TextEditingController();
    _newFolder = TextEditingController();
    _selectedFolder = widget.existingFolders.isNotEmpty ? widget.existingFolders.first : null;
    if (widget.existingFolders.isEmpty) _creatingNewFolder = true;
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
        const SnackBar(content: Text('یک پوشه را انتخاب یا وارد کنید.')),
      );
      return;
    }
    final source = LinkMetaService.sourceFor(widget.sharedUrl);
    final link = SavedLink(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: widget.sharedUrl,
      title: _title.text.trim().isEmpty ? source : _title.text.trim(),
      folder: folder,
      source: source,
      channel: _channel.text.trim(),
      description: _description.text.trim(),
      createdAt: DateTime.now(),
    );
    Navigator.pop(context, link);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ذخیره در کتابخانه')),
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
            const SizedBox(height: 16),
            const Text('پوشه *', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  label: const Text('+ پوشهٔ جدید'),
                  selected: _creatingNewFolder,
                  onSelected: (_) => setState(() => _creatingNewFolder = true),
                ),
              ],
            ),
            if (_creatingNewFolder) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _newFolder,
                decoration: const InputDecoration(
                  labelText: 'نام پوشهٔ جدید',
                  hintText: 'مثلا مکانیک، ورزش، غذا',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'عنوان', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _channel,
              decoration: const InputDecoration(
                labelText: 'کانال یا صفحه (اختیاری)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'توضیح کوتاه (اختیاری)',
                hintText: 'این ویدیو دربارهٔ چیه؟',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }
}
