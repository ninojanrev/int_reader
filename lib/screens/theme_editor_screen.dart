import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/custom_reader_theme.dart';
import '../services/settings_service.dart';
import '../services/theme_catalog.dart';
import '../widgets/reader_options.dart';

/// Settings â†’ Reading themes: list built-in presets (locked, duplicable)
/// and user themes (editable, deletable), plus a full editor with a live
/// reader-style preview.
class ThemeEditorScreen extends StatefulWidget {
  const ThemeEditorScreen({super.key});

  @override
  State<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends State<ThemeEditorScreen> {
  late ThemeCatalog _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = ThemeCatalog.fromSettings(settings);
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final choices = _catalog.choices();

    return Scaffold(
      appBar: AppBar(title: const Text('Reading themes')),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        const SizedBox(height: 8),
        Text('Built-in presets', style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final choice in choices.where((c) => c.isBuiltin))
          _buildThemeTile(theme, choice),
        const SizedBox(height: 20),
        Text('Your themes', style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        if (_catalog.customs.isEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Text(
            'Duplicate a preset or create a new theme to get started.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant))),
        for (final choice in choices.where((c) => !c.isBuiltin))
          _buildThemeTile(theme, choice),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New theme'),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildThemeTile(ThemeData theme, ThemeChoice choice) {
    final isDefault = settings.readingTheme == choice.key;
    return Card(elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(width: 40, height: 56,
          decoration: BoxDecoration(
            color: choice.theme.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5)),
          alignment: Alignment.center,
          child: Text('Aa', style: TextStyle(color: choice.theme.text,
            fontWeight: FontWeight.w600, fontSize: 15))),
        title: Row(children: [
          Flexible(child: Text(choice.name, overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          if (isDefault) ...[
            const SizedBox(width: 6),
            Icon(Icons.check_circle, size: 15, color: theme.colorScheme.primary),
          ],
          if (choice.isBuiltin) ...[
            const SizedBox(width: 6),
            Icon(Icons.lock_outline, size: 13,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          ],
        ]),
        subtitle: _buildSwatchRow(theme, choice.theme),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'default') _setDefault(choice);
            if (value == 'duplicate') _duplicate(choice);
            if (value == 'edit') _openEditor(existingId: choice.key);
            if (value == 'delete') _confirmDelete(choice);
          },
          itemBuilder: (_) => [
            if (!isDefault)
              const PopupMenuItem(value: 'default',
                child: Text('Set as default')),
            const PopupMenuItem(value: 'duplicate',
                child: Text('Duplicate')),
            if (!choice.isBuiltin)
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (!choice.isBuiltin)
              PopupMenuItem(value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: theme.colorScheme.error))),
          ],
        ),
      ),
    );
  }

  Widget _buildSwatchRow(ThemeData theme, ReaderTheme rt) {
    Widget swatch(Color c) => Container(width: 22, height: 14,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5)));
    return Padding(padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        swatch(rt.background),
        const SizedBox(width: 4),
        swatch(rt.text),
        const SizedBox(width: 4),
        swatch(rt.chrome),
      ]));
  }

  void _setDefault(ThemeChoice choice) {
    settings.setReadingTheme(choice.key);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Default reading theme: ${choice.name}'),
        duration: const Duration(seconds: 2)));
    }
  }

  void _duplicate(ThemeChoice source) {
    final copy = _catalog.duplicate(source);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Created "${copy.name}"'),
        duration: const Duration(seconds: 2)));
    }
  }

  Future<void> _confirmDelete(ThemeChoice choice) async {
    final theme = Theme.of(context);
    final wasDefault = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Delete "${choice.name}"?', style: theme.textTheme.titleMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: theme.colorScheme.error))),
        ],
      ),
    );
    if (wasDefault != true) return;
    final resetToFallback = _catalog.remove(choice.key);
    if (resetToFallback) {
      await settings.setReadingTheme(ThemeCatalog.fallbackKey);
    }
    _refresh();
    if (mounted && resetToFallback) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('It was your default â€” reset to Sepia'),
        duration: Duration(seconds: 2)));
    }
  }

  Future<void> _openEditor({String? existingId}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ThemeEditScreen(
          catalog: _catalog,
          existing: existingId == null ? null : _catalog.byId(existingId),
          seed:
              existingId == null ? null : _catalog.choiceByKey(existingId)?.theme,
        ),
      ),
    );
    if (result == true) _refresh();
  }
}

// ================= Editor =================

class _ThemeEditScreen extends StatefulWidget {
  final ThemeCatalog catalog;
  final CustomReaderTheme? existing;
  final ReaderTheme? seed; // used when creating from a duplicate

  const _ThemeEditScreen({
    required this.catalog,
    this.existing,
    this.seed,
  });

  @override
  State<_ThemeEditScreen> createState() => _ThemeEditScreenState();
}

class _ThemeEditScreenState extends State<_ThemeEditScreen> {
  late TextEditingController _name;
  late Color _background;
  late Color _text;
  late Color _chrome;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _background = Color(widget.existing?.background ??
        widget.seed?.background.toARGB32() ??
        0xFFF4ECD8);
    _text = Color(widget.existing?.text ??
        widget.seed?.text.toARGB32() ??
        0xFF5B4636);
    _chrome = Color(widget.existing?.chrome ??
        widget.seed?.chrome.toARGB32() ??
        0xFFEDE3CC);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = ReaderTheme(
        label: '', background: _background, text: _text, chrome: _chrome);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit theme' : 'New theme'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Theme name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        Text('Preview', style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        _buildPreview(theme, preview),
        const SizedBox(height: 24),
        _buildColorField(theme, label: 'Background', color: _background,
          onChanged: (c) => setState(() => _background = c)),
        _buildColorField(theme, label: 'Text', color: _text,
          onChanged: (c) => setState(() => _text = c)),
        _buildColorField(theme, label: 'Bars (chrome)', color: _chrome,
          onChanged: (c) => setState(() => _chrome = c)),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildPreview(ThemeData theme, ReaderTheme rt) {
    return Container(
      decoration: BoxDecoration(
        color: rt.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, color: rt.chrome,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(child: Text('Chapter One Â· bars',
            style: TextStyle(fontSize: 11, color: rt.text)))),
        Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('The quick brown fox', style: TextStyle(
            fontSize: 19, fontWeight: FontWeight.w700, color: rt.text)),
          const SizedBox(height: 10),
          Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
            'This paragraph previews how body text will look with your '
            'chosen colors while reading.',
            style: TextStyle(fontSize: 15, height: 1.5, color: rt.text)),
        ])),
      ]),
    );
  }

  Widget _buildColorField(ThemeData theme,
      {required String label, required Color color, required ValueChanged<Color> onChanged}) {
    return Card(elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
      child: ListTile(
        leading: Container(width: 34, height: 34,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5))),
        title: Text(label, style: theme.textTheme.bodyMedium),
        trailing: const Icon(Icons.edit_outlined, size: 18),
        onTap: () => _pickColor(label, color, onChanged),
      ));
  }

  Future<void> _pickColor(String label, Color initial,
      ValueChanged<Color> onChanged) async {
    var picked = initial;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Pick $label'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            paletteType: PaletteType.hsvWithHue,
            enableAlpha: false,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { onChanged(picked); Navigator.pop(ctx); },
            child: const Text('Select')),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Give the theme a name'),
          duration: Duration(seconds: 2)));
      return;
    }
    if (_isEditing) {
      final t = widget.existing!;
      t
        ..name = name
        ..background = _background.toARGB32()
        ..text = _text.toARGB32()
        ..chrome = _chrome.toARGB32();
      widget.catalog.update(t);
    } else {
      widget.catalog.add(
        name: name,
        background: _background,
        text: _text,
        chrome: _chrome,
      );
    }
    Navigator.pop(context, true);
  }
}

