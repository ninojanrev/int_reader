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
  required double fontWeight,
  required String textAlign,
  required double paragraphSpacing,
  required double paragraphIndent,
  ReaderTheme? previewTheme,
  required void Function(String fontFamily, double fontSize, double lineHeight,
          double fontWeight, String textAlign, double paragraphSpacing, double paragraphIndent)
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
      initialWeight: fontWeight,
      initialAlign: textAlign,
      initialParagraphSpacing: paragraphSpacing,
      initialParagraphIndent: paragraphIndent,
      previewTheme: previewTheme ?? readerThemes['Sepia']!,
      onApply: onApply,
    ),
  ).then((applied) => applied ?? false);
}

class _TextAppearanceEditor extends StatefulWidget {
  final String initialFamily;
  final double initialSize;
  final double initialSpacing;
  final double initialWeight;
  final String initialAlign;
  final double initialParagraphSpacing;
  final double initialParagraphIndent;
  final ReaderTheme previewTheme;
  final void Function(String fontFamily, double fontSize, double lineHeight,
          double fontWeight, String textAlign, double paragraphSpacing, double paragraphIndent)
      onApply;

  const _TextAppearanceEditor({
    required this.initialFamily,
    required this.initialSize,
    required this.initialSpacing,
    required this.initialWeight,
    required this.initialAlign,
    required this.initialParagraphSpacing,
    required this.initialParagraphIndent,
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
  late double _weight = widget.initialWeight;
  late String _align = widget.initialAlign;
  late double _paraSpacing = widget.initialParagraphSpacing;
  late double _paraIndent = widget.initialParagraphIndent;

  TextAlign _textAlign() => switch (_align) {
        'Left' => TextAlign.left,
        'Center' => TextAlign.center,
        'Right' => TextAlign.right,
        _ => TextAlign.justify,
      };

  FontWeight _fontWeight() => FontWeight.values
      .where((w) => w.value == _weight.round())
      .firstOrNull ??
      FontWeight.w400;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rt = widget.previewTheme;
    final fonts = fontService.allFonts(readerFontFamilies);

    Widget previewParagraph(String text, {bool heading = false}) => Text(
          text,
          maxLines: heading ? 1 : 4,
          overflow: TextOverflow.ellipsis,
          textAlign: heading ? TextAlign.left : _textAlign(),
          style: TextStyle(
            fontSize: heading ? _size + 3 : _size,
            height: _spacing,
            fontWeight: heading ? FontWeight.w700 : _fontWeight(),
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
                    _buildSlider(theme, 'Font size', _size, 13, 24, 11,
                        '${_size.round()}pt', (v) => _size = v),
                    const SizedBox(height: 4),
                    _buildSlider(theme, 'Line spacing', _spacing, 1.0, 2.5, 15,
                        '${_spacing.toStringAsFixed(1)}x', (v) => _spacing = v),
                    const SizedBox(height: 4),
                    _buildSlider(theme, 'Font weight', _weight, 100, 700, 6,
                        _weightName(_weight), (v) => _weight = v),
                    const SizedBox(height: 12),
                    _sectionLabel(theme, 'Text alignment'),
                    const SizedBox(height: 6),
                    _buildAlignRow(theme),
                    const SizedBox(height: 12),
                    _buildSlider(theme, 'Paragraph spacing', _paraSpacing, 0, 40, 20,
                        '${_paraSpacing.round()}', (v) => _paraSpacing = v),
                    const SizedBox(height: 4),
                    _buildSlider(theme, 'First-line indent', _paraIndent, 0, 60, 12,
                        '${_paraIndent.round()}', (v) => _paraIndent = v),
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
                      widget.onApply(_family, _size, _spacing, _weight,
                          _align, _paraSpacing, _paraIndent);
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

  Widget _buildSlider(ThemeData theme, String label, double value, double min,
      double max, int divisions, String display, ValueChanged<double> onChanged) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _sectionLabel(theme, label),
        Text(display,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary)),
      ]),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        activeColor: theme.colorScheme.primary,
        onChanged: (v) => setState(() => onChanged(v)),
      ),
    ]);
  }

  Widget _buildAlignRow(ThemeData theme) {
    final options = [
      ('Left', Icons.format_align_left),
      ('Justify', Icons.format_align_justify),
      ('Center', Icons.format_align_center),
      ('Right', Icons.format_align_right),
    ];
    return Row(
      children: options.map((o) {
        final selected = o.$1 == _align;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _align = o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: selected ? 1.2 : 0.5,
                  ),
                ),
                child: Icon(o.$2, size: 18,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _weightName(double w) => switch (w.round()) {
        100 => 'Thin',
        200 => 'Extra Light',
        300 => 'Light',
        400 => 'Normal',
        500 => 'Medium',
        600 => 'SemiBold',
        700 => 'Bold',
        _ => '${w.round()}',
      };

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
