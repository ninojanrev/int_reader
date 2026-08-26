import 'package:flutter/material.dart';

import '../services/font_service.dart';
import 'reader_options.dart';

/// Combined text-appearance editor with a live preview and Apply/Cancel.
/// Draft values stay local until [onApply] is invoked by the caller
/// (typically persisting via SettingsService). Returns true when applied.
Future<bool> showTextAppearanceEditor(
  BuildContext context, {
  required String fontFamily,
  required double fontSize,
  required double lineHeight,
  ReaderTheme? previewTheme,
  required void Function(String fontFamily, double fontSize, double lineHeight)
      onApply,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => _TextAppearanceEditor(
      initialFamily: fontFamily,
      initialSize: fontSize,
      initialSpacing: lineHeight,
      previewTheme: previewTheme ?? readerThemes['Sepia']!,
      onApply: onApply,
    ),
  ).then((applied) => applied ?? false);
}

class _TextAppearanceEditor extends StatefulWidget {
  final String initialFamily;
  final double initialSize;
  final double initialSpacing;
  final ReaderTheme previewTheme;
  final void Function(String fontFamily, double fontSize, double lineHeight)
      onApply;

  const _TextAppearanceEditor({
    required this.initialFamily,
    required this.initialSize,
    required this.initialSpacing,
    required this.previewTheme,
    required this.onApply,
  });

  @override
  State<_TextAppearanceEditor> createState() => _TextAppearanceEditorState();
}

class _TextAppearanceEditorState extends State<_TextAppearanceEditor> {
  late String _family = widget.initialFamily;
  late double _size = widget.initialSize;
  late double _spacing = widget.initialSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rt = widget.previewTheme;
    final fonts = fontService.allFonts(readerFontFamilies);

    Widget previewParagraph(String text, {bool heading = false}) => Text(
          text,
          maxLines: heading ? 1 : 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: heading ? _size + 3 : _size,
            height: _spacing,
            fontWeight: heading ? FontWeight.w700 : FontWeight.w400,
            fontFamily: _resolvedFamily(),
            color: heading ? rt.text : rt.text.withValues(alpha: 0.92),
          ),
        );

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  Text('Text appearance', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 12),
            // ---------- Live preview ----------
            // Fixed height so slider adjustments never push the controls
            // below up/down; overflow is clipped instead.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 250,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: rt.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: theme.colorScheme.outlineVariant, width: 0.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        color: rt.chrome,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Center(
                          child: Text('Chapter One',
                              style: TextStyle(fontSize: 11, color: rt.text)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            previewParagraph(
                                'The quick brown fox jumps over the lazy dog.',
                                heading: true),
                            const SizedBox(height: 10),
                            previewParagraph(
                                'Lorem ipsum dolor sit amet, consectetur adipiscing '
                                'elit. Sed do eiusmod tempor incididunt ut labore et '
                                'dolore magna aliqua, ut enim ad minim veniam quis.'),
                            const SizedBox(height: 8),
                            previewParagraph(
                                'Duis aute irure dolor in reprehenderit in voluptate '
                                'velit esse cillum dolore eu fugiat nulla pariatur.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ---------- Controls ----------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(theme, 'Font family'),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final name in fonts.keys)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(name,
                                    style: TextStyle(fontFamily: fonts[name])),
                                selected: name == _family,
                                onSelected: (_) =>
                                    setState(() => _family = name),
                                showCheckmark: false,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionLabel(theme, 'Font size'),
                          Text('${_size.round()}pt',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary)),
                        ]),
                    Slider(
                      value: _size.clamp(13, 24),
                      min: 13,
                      max: 24,
                      divisions: 11,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (v) => setState(() => _size = v),
                    ),
                    const SizedBox(height: 4),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionLabel(theme, 'Line spacing'),
                          Text('${_spacing.toStringAsFixed(1)}x',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary)),
                        ]),
                    Slider(
                      value: _spacing.clamp(1.0, 2.5),
                      min: 1.0,
                      max: 2.5,
                      divisions: 15,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (v) => setState(() => _spacing = v),
                    ),
                  ],
                ),
              ),
            ),
            // ---------- Footer ----------
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      widget.onApply(_family, _size, _spacing);
                      Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Apply'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _resolvedFamily() =>
      fontService.resolveFamily(_family, readerFontFamilies);

  Widget _sectionLabel(ThemeData theme, String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant));
  }
}
