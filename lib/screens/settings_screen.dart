import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/settings_service.dart';

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
  }

  void _update(AppSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
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
        content: Text('${_s.t('aboutBody')}\n\n${_s.t('versionLabel')}: 1.0.0'),
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
