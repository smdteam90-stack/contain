import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../services/settings_service.dart';

/// Raw URL of the small JSON file (hosted right in this repo) that this
/// screen reads to find out the latest published version and changelog.
/// No backend needed — bumping this file on a release is enough.
const _updateConfigUrl =
    'https://raw.githubusercontent.com/smdteam90-stack/contain/main/update_config.json';
const _bazaarUrl = 'https://cafebazaar.ir/app/?id=com.sam.reelbox';
const _myketUrl = 'https://myket.ir/app/com.sam.reelbox';

/// Settings screen. Every change is applied and persisted immediately via
/// [onChanged], so there is nothing to "save" on the way out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;

  String _version = '';
  bool _checkingUpdate = false;
  bool _checkFailed = false;
  bool? _updateAvailable; // null = not checked yet this visit
  List<String> _changelog = [];

  static const _languages = [
    ('fa', 'فارسی'),
    ('en', 'English'),
    ('ar', 'العربية'),
    ('es', 'Español'),
    ('fr', 'Français'),
    ('tr', 'Türkçe'),
  ];

  AppStrings get _s => AppStrings(_settings.languageCode);

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  void _update(AppSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
  }

  /// Very small dotted-version comparator ("1.2.0" vs "1.10.0" etc.) — good
  /// enough for the simple major.minor.patch versions this app uses.
  bool _isNewer(String latest, String current) {
    final a = latest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final b = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av > bv;
    }
    return false;
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _checkFailed = false;
    });
    try {
      final res = await http
          .get(Uri.parse(_updateConfigUrl))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = data['latestVersion'] as String? ?? _version;
      final changelogMap = (data['changelog'] as Map<String, dynamic>?) ?? {};
      final list = (changelogMap[_settings.languageCode] ??
              changelogMap['en'] ??
              []) as List<dynamic>;
      setState(() {
        _updateAvailable = _isNewer(latest, _version);
        _changelog = list.map((e) => e.toString()).toList();
      });
    } catch (_) {
      setState(() => _checkFailed = true);
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showStoreChooser() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_s.t('chooseStoreTitle')),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _openUrl(_bazaarUrl);
            },
            child: const Text('Cafe Bazaar'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _openUrl(_myketUrl);
            },
            child: const Text('Myket'),
          ),
        ],
      ),
    );
  }

  void _showUsageGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.t('usageGuideTitle')),
        content: SingleChildScrollView(child: Text(_s.t('usageGuideBody'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_s.t('cancel'))),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.t('aboutTitle')),
        content: Text('${_s.t('aboutBody')}\n\n${_s.t('versionLabel')}: $_version'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_s.t('cancel'))),
        ],
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_s.t('comingSoonMsg'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_s.t('settingsTitle'))),
      body: ListView(
        children: [
          _SectionHeader(title: _s.t('appearanceSection')),
          ListTile(
            title: Text(_s.t('themeLabel')),
            trailing: DropdownButton<AppThemeMode>(
              value: _settings.themeMode,
              items: [
                DropdownMenuItem<AppThemeMode>(value: AppThemeMode.system, child: Text(_s.t('systemMode'))),
                DropdownMenuItem<AppThemeMode>(value: AppThemeMode.light, child: Text(_s.t('lightMode'))),
                DropdownMenuItem<AppThemeMode>(value: AppThemeMode.dark, child: Text(_s.t('darkMode'))),
              ],
              onChanged: (mode) {
                if (mode != null) _update(_settings.copyWith(themeMode: mode));
              },
            ),
          ),
          ListTile(
            title: Text(_s.t('textSizeLabel')),
            subtitle: Slider(
              value: _settings.textScale,
              min: 0.8,
              max: 1.6,
              divisions: 8,
              label: _settings.textScale.toStringAsFixed(1),
              onChanged: (value) => _update(_settings.copyWith(textScale: value)),
            ),
          ),
          ListTile(
            title: Text(_s.t('languageLabel')),
            trailing: DropdownButton<String>(
              value: _settings.languageCode,
              items: _languages
                  .map((lang) => DropdownMenuItem<String>(value: lang.$1, child: Text(lang.$2)))
                  .toList(),
              onChanged: (code) {
                if (code != null) _update(_settings.copyWith(languageCode: code));
              },
            ),
          ),
          const Divider(),
          _SectionHeader(title: _s.t('accountSection')),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(_s.t('signIn')),
            onTap: _showComingSoon,
          ),
          const Divider(),
          _SectionHeader(title: _s.t('generalSection')),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(_s.t('usageGuideTitle')),
            onTap: _showUsageGuide,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(_s.t('aboutTitle')),
            onTap: _showAbout,
          ),
          const Divider(),
          _SectionHeader(title: _s.t('versionUpdatesSection')),
          ListTile(
            leading: const Icon(Icons.numbers_outlined),
            title: Text(_s.t('versionLabel')),
            trailing: Text(_version),
          ),
          ListTile(
            leading: _checkingUpdate
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_outlined),
            title: Text(_s.t('checkForUpdate')),
            subtitle: _checkingUpdate
                ? Text(_s.t('checkingUpdate'))
                : _checkFailed
                    ? Text(_s.t('updateCheckFailedMsg'))
                    : _updateAvailable == null
                        ? null
                        : Text(_updateAvailable!
                            ? _s.t('updateAvailableMsg')
                            : _s.t('upToDateMsg')),
            onTap: _checkingUpdate
                ? null
                : () async {
                    await _checkForUpdate();
                    if (_updateAvailable == true) _showStoreChooser();
                  },
          ),
          if (_updateAvailable == true && _changelog.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                _s.t('changelogTitle'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ..._changelog.map(
              (line) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                child: Text('•  $line'),
              ),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: Text(_s.t('rateUsLabel')),
            onTap: _showStoreChooser,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
}
