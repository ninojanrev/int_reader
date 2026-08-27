import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../providers/library_provider.dart';
import '../services/file_service.dart';
import '../services/font_service.dart';
import '../services/reminder_service.dart';
import '../services/theme_catalog.dart';
import '../widgets/text_appearance_editor.dart';
import '../widgets/reader_options.dart';
import '../services/settings_service.dart';
import 'category_manage_screen.dart';
import 'theme_editor_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// All values are read from the shared [settings] singleton at build time,
/// so changes made in the reader's quick-options sheet are reflected here
/// immediately (and vice versa) even though tabs stay alive in memory.
class _SettingsScreenState extends State<SettingsScreen> {
  String _storageUsed = 'Calculating\u2026';

  @override
  void initState() {
    super.initState();
    darkModeNotifier.addListener(_onDarkModeChanged);
    _computeStorageUsed();
  }

  @override
  void dispose() {
    darkModeNotifier.removeListener(_onDarkModeChanged);
    super.dispose();
  }

  void _onDarkModeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _computeStorageUsed() async {
    final bytes = await fileService.getLibraryStorageBytes();
    if (!mounted) return;
    setState(() {
      if (bytes < 1024 * 1024) {
        _storageUsed = '${(bytes / 1024).toStringAsFixed(0)} KB';
      } else {
        _storageUsed = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    });
  }

  TimeOfDay get _reminderTime => TimeOfDay(
      hour: settings.reminderMinutesOfDay ~/ 60,
      minute: settings.reminderMinutesOfDay % 60);

  void _showOptionsPicker({
    required String title,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ...options.map(
                (option) => ListTile(
                  title: Text(option, style: theme.textTheme.bodyMedium),
                  trailing: option == currentValue
                      ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
                      : null,
                  onTap: () {
                    onSelected(option);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showThemePicker() {
    final theme = Theme.of(context);
    final catalog = ThemeCatalog.fromSettings(settings);
    final choices = catalog.choices();
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Reading theme', style: theme.textTheme.titleMedium),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final choice in choices)
                    ListTile(
                      leading: Container(width: 34, height: 46,
                        decoration: BoxDecoration(
                          color: choice.theme.background,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                              width: 0.5)),
                        alignment: Alignment.center,
                        child: Text('Aa', style: TextStyle(
                            color: choice.theme.text,
                            fontWeight: FontWeight.w600))),
                      title: Row(children: [
                        Flexible(child: Text(choice.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium)),
                        if (!choice.isBuiltin) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.person_outline, size: 13,
                            color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ]),
                      trailing: choice.key == settings.readingTheme
                          ? Icon(Icons.check,
                              color: theme.colorScheme.primary, size: 20)
                          : null,
                      onTap: () {
                        settings.setReadingTheme(choice.key);
                        setState(() {});
                        Navigator.pop(context);
                      },
                    ),
                  const Divider(height: 1, color: Colors.transparent),
                  ListTile(
                    leading: Icon(Icons.tune, size: 20,
                        color: theme.colorScheme.primary),
                    title: Text('Manage themesâ€¦',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary)),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ThemeEditorScreen()));
                      setState(() {});
                    },
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importFont() async {
    final path = await fileService.pickAnyFile();
    if (!mounted || path == null) return;
    final name = await fontService.importFont(path);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(name != null
          ? 'Imported "$name"'
          : 'Could not import that file (.ttf/.otf only)'),
      duration: const Duration(seconds: 2)));
  }

  Future<void> _confirmResetReadingOptions() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Reset reading options?', style: theme.textTheme.titleMedium),
        content: Text(
          'Font, theme, spacing and reading-mode options will return to '
          'their defaults. Your books, categories, highlights and '
          'bookmarks are untouched.',
          style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;
    await settings.resetReadingOptions();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Reading options reset to defaults'),
      duration: Duration(seconds: 2)));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _showPrivacyPolicy() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Privacy Policy', style: theme.textTheme.titleMedium),
        content: SingleChildScrollView(
          child: Text(
            'Int Reader operates entirely offline. No data is collected, '
            'stored, or transmitted to any server. All books, reading progress, '
            'highlights, and settings are stored locally on your device and '
            'are never shared with third parties.\n\n'
            'This app requires storage permission solely to read book files '
            'you select. No files are copied to external servers.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _onRemindersChanged(bool enabled) async {
    setState(() {});
    await settings.setReminderEnabled(enabled);
    if (!enabled) {
      await reminderService.cancel();
      return;
    }
    final granted = await reminderService.requestPermission();
    if (!granted) {
      if (!mounted) return;
      setState(() {});
      await settings.setReminderEnabled(false);
      _showMessage('Notification permission was denied');
      return;
    }
    await reminderService.scheduleDaily(settings.reminderMinutesOfDay);
    if (mounted) {
      _showMessage('Daily reminder set for ${_reminderTime.format(context)}');
    }
  }

  Future<void> _showReminderTimePicker() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked == null) return;
    await settings.setReminderTime(picked.hour * 60 + picked.minute);
    setState(() {});
    await reminderService.scheduleDaily(settings.reminderMinutesOfDay);
    if (mounted) {
      _showMessage('Daily reminder set for ${picked.format(context)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          Text('Settings', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          _buildSection('Appearance', [
            _SettingsRow(
              icon: Icons.dark_mode_outlined,
              label: 'Dark mode',
              isSwitch: true,
              switchValue: darkModeNotifier.value,
              onSwitchChanged: (val) {
                darkModeNotifier.value = val;
                settings.setDarkMode(val);
                setState(() {});
              },
            ),
            _SettingsRow(
              icon: Icons.auto_awesome_motion_outlined,
              label: 'Animated library background',
              subtitle: 'Applies on next app start',
              isSwitch: true,
              switchValue: settings.animatedLibraryBackdrop,
              onSwitchChanged: (val) async {
                settings.setAnimatedLibraryBackdrop(val);
                setState(() {});
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    title: Text(
                        val ? 'Background enabled' : 'Background disabled',
                        style: Theme.of(context).textTheme.titleMedium),
                    content: Text(
                      'The animated library background will '
                      '${val ? 'appear' : 'be removed'} the next time you '
                      'start Int Reader.',
                      style: Theme.of(context).textTheme.bodyMedium),
                    actions: [
                      FilledButton(onPressed: () => Navigator.pop(ctx),
                        child: const Text('Got it')),
                    ],
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection('Reading', [
            _SettingsRow(icon: Icons.text_format, label: 'Text appearance',
              trailing:
                  '${settings.fontFamily} \u00b7 ${settings.fontSize.round()}pt '
                  '\u00b7 ${settings.lineHeight.toStringAsFixed(1)}x',
              onTap: () async {
                final applied = await showTextAppearanceEditor(
                  context,
                  fontFamily: settings.fontFamily,
                  fontSize: settings.fontSize,
                  lineHeight: settings.lineHeight,
                  previewTheme: ThemeCatalog.fromSettings(settings)
                      .resolve(settings.readingTheme),
                  onApply: (f, s, l) {
                    settings.setFontFamily(f);
                    settings.setFontSize(s);
                    settings.setLineHeight(l);
                  },
                );
                if (applied) setState(() {});
              }),
            _SettingsRow(icon: Icons.font_download_outlined, label: 'Import font',
              trailing: '${fontService.allFonts(readerFontFamilies).length - readerFontFamilies.length} imported',
              onTap: () => _importFont()),
            _SettingsRow(icon: Icons.palette_outlined, label: 'Reading theme',
              trailing: ThemeCatalog.fromSettings(settings)
                      .choiceByKey(settings.readingTheme)?.name ??
                  'Sepia',
              onTap: () => _showThemePicker()),
            _SettingsRow(icon: Icons.tune, label: 'Manage themes',
              onTap: () async {
                await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ThemeEditorScreen()));
                setState(() {});
              }),
            _SettingsRow(icon: Icons.swipe, label: 'Page turn style',
              trailing: settings.pageTurnStyle,
              enabled: false,
              onTap: () {}),
            const _SettingsHint(
                'Page turn styles are coming in a future update.'),
            _SettingsRow(icon: Icons.screen_lock_rotation_outlined, label: 'Keep screen awake',
              isSwitch: true, switchValue: settings.keepScreenAwake,
              onSwitchChanged: (val) { setState(() {}); settings.setKeepScreenAwake(val); }),
            _SettingsRow(icon: Icons.swap_vert, label: 'Reading mode',
              trailing: settings.readingMode,
              onTap: () => _showOptionsPicker(
                title: 'Reading mode', options: ['Vertical', 'Horizontal'],
                currentValue: settings.readingMode,
                onSelected: (val) { setState(() {}); settings.setReadingMode(val); })),
            if (settings.readingMode == 'Horizontal')
              _SettingsRow(icon: Icons.swap_horiz, label: 'Flip direction',
                trailing: settings.horizontalDirection,
                onTap: () => _showOptionsPicker(
                  title: 'Flip direction', options: ['Left to right', 'Right to left'],
                  currentValue: settings.horizontalDirection,
                  onSelected: (val) { setState(() {}); settings.setHorizontalDirection(val); })),
            _SettingsRow(icon: Icons.volume_up_outlined, label: 'Volume keys turn pages',
              isSwitch: true, switchValue: settings.volumeKeysTurnPages,
              onSwitchChanged: (val) { setState(() {}); settings.setVolumeKeysTurnPages(val); }),
            _SettingsRow(icon: Icons.restart_alt, label: 'Reset reading options',
              onTap: () => _confirmResetReadingOptions()),
            const _SettingsHint(
                'Resets font, theme, spacing and reading-mode options to their defaults. '
                'Your books, categories, highlights and bookmarks are untouched.'),
          ]),
          const SizedBox(height: 20),
          _buildSection('Library', [
            _SettingsRow(icon: Icons.sort, label: 'Default sort order',
              trailing: settings.sortOrder,
              onTap: () => _showOptionsPicker(
                title: 'Default sort order',
                options: ['Recently added', 'Title', 'Author', 'Reading progress'],
                currentValue: settings.sortOrder,
                onSelected: (val) { setState(() {}); settings.setSortOrder(val); })),
            _SettingsRow(icon: Icons.folder_outlined, label: 'Manage categories',
              trailing: '${context.watch<LibraryState>().allCategories.length}',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CategoryManageScreen()))),
            _SettingsRow(icon: Icons.storage_outlined, label: 'Storage used',
              trailing: _storageUsed,
              onTap: () => _showMessage('$_storageUsed used by your EPUB library')),
          ]),
          const SizedBox(height: 20),
          _buildSection('Import', [
            _SettingsRow(
              icon: Icons.swap_horizontal_circle_outlined,
              label: 'Replace imported books',
              subtitle: 'Update existing books when a new version is imported',
              isSwitch: true,
              switchValue: settings.replaceOnImport,
              onSwitchChanged: (val) {
                settings.setReplaceOnImport(val);
                setState(() {});
              },
            ),
            if (settings.replaceOnImport)
              _SettingsRow(
                icon: Icons.rule_outlined,
                label: 'When a book already exists',
                trailing: settings.importConflictMode,
                onTap: () => _showOptionsPicker(
                  title: 'When a book already exists',
                  options: ['Ask every time', 'Replace larger automatically'],
                  currentValue: settings.importConflictMode,
                  onSelected: (val) {
                    settings.setImportConflictMode(val);
                    setState(() {});
                  },
                ),
              ),
            if (settings.replaceOnImport)
              const _SettingsHint(
                  '"Ask every time" pauses the import for each matching book '
                  'and lets you choose. "Replace larger automatically" swaps '
                  'in the larger file without asking. Reading progress, '
                  'categories, highlights and bookmarks are always kept.'),
          ]),
          const SizedBox(height: 20),
          _buildSection('Backup & sync', [
            _SettingsRow(icon: Icons.cloud_outlined, label: 'Cloud backup',
              isSwitch: true, switchValue: false, enabled: false,
              onSwitchChanged: (_) {}),
            _SettingsRow(icon: Icons.sync, label: 'Sync across devices',
              isSwitch: true, switchValue: false, enabled: false,
              onSwitchChanged: (_) {}),
            const _SettingsHint('Backup and sync are coming in a future update.'),
          ]),
          const SizedBox(height: 20),
          _buildSection('Notifications', [
            _SettingsRow(icon: Icons.notifications_outlined, label: 'Reading reminders',
              isSwitch: true, switchValue: settings.reminderEnabled,
              onSwitchChanged: _onRemindersChanged),
            if (settings.reminderEnabled)
              _SettingsRow(icon: Icons.schedule_outlined, label: 'Reminder time',
                trailing: _reminderTime.format(context),
                onTap: () => _showReminderTimePicker()),
          ]),
          const SizedBox(height: 20),
          _buildSection('About', [
            _SettingsRow(icon: Icons.info_outline, label: 'App version', trailing: '1.0.0',
              onTap: () => _showMessage('App is up to date (v1.0.0)')),
            _SettingsRow(icon: Icons.privacy_tip_outlined, label: 'Privacy policy',
              onTap: () => _showPrivacyPolicy()),
            _SettingsRow(icon: Icons.bug_report_outlined, label: 'Report a bug',
              onTap: () => launchUrl(Uri.parse('https://github.com/ninojanrev/int_reader/issues'))),
            _SettingsRow(icon: Icons.delete_outline, label: 'Clear cache',
              onTap: () async {
                await fileService.clearOrphanedCovers();
                if (mounted) {
                  setState(() {});
                  _computeStorageUsed();
                  _showMessage('Cache cleared successfully');
                }
              }),
          ]),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> rows) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(title, style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant)),
        ),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i != rows.length - 1 && rows[i] is! _SettingsHint)
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? trailing;
  final bool isSwitch;
  final bool switchValue;
  final bool enabled;
  final ValueChanged<bool>? onSwitchChanged;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.isSwitch = false,
    this.switchValue = false,
    this.enabled = true,
    this.onSwitchChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, size: 20,
        color: theme.colorScheme.onSurfaceVariant
            .withValues(alpha: enabled ? 1.0 : 0.4)),
      title: Text(label, style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface
            .withValues(alpha: enabled ? 1.0 : 0.4))),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: enabled ? 1.0 : 0.4))),
      isThreeLine: subtitle != null,
      trailing: isSwitch
          ? Switch(value: switchValue, onChanged: enabled ? onSwitchChanged : null)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailing != null)
                  Text(trailing!, style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: enabled ? 1.0 : 0.4))),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: enabled ? 1.0 : 0.4)),
              ],
            ),
      onTap: !enabled
          ? null
          : isSwitch
              ? () => onSwitchChanged?.call(!switchValue)
              : onTap,
    );
  }
}

class _SettingsHint extends StatelessWidget {
  final String text;
  const _SettingsHint(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}


