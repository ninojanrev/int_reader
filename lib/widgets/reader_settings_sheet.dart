import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/theme_catalog.dart';

/// The reader's quick-options sheet. Text styling (font family, size,
/// line spacing) lives behind a single launcher row that opens the shared
/// text-appearance editor with Apply/Cancel; reading theme and layout
/// (mode/direction) controls remain here.
class ReaderSettingsSheet extends StatelessWidget {
  final String readingTheme;
  final String readingMode;
  final String horizontalDirection;
  final String textSummary;
  final ValueChanged<String> onReadingThemeChanged;
  final VoidCallback onEditTextAppearance;
  final ValueChanged<String> onReadingModeChanged;
  final ValueChanged<String> onHorizontalDirectionChanged;

  const ReaderSettingsSheet({
    super.key,
    required this.readingTheme,
    required this.readingMode,
    required this.horizontalDirection,
    required this.textSummary,
    required this.onReadingThemeChanged,
    required this.onEditTextAppearance,
    required this.onReadingModeChanged,
    required this.onHorizontalDirectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Display', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildTextAppearanceRow(context),
            const SizedBox(height: 16),
            _buildThemeRow(context),
            const SizedBox(height: 20),
            const Text('Layout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            _buildModeRow(context),
            if (readingMode == 'Horizontal') ...[
              const SizedBox(height: 16),
              _buildDirectionRow(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sheetLabel(BuildContext context, String text) {
    return Text(text, style: TextStyle(
      fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant));
  }

  Widget _buildSegmented({
    required BuildContext context,
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sheetLabel(context, label),
      const SizedBox(height: 6),
      Row(children: options.map((option) {
        final isSelected = option == selected;
        return Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelected(option),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                  width: isSelected ? 1.2 : 0.5,
                ),
              ),
              child: Text(option, textAlign: TextAlign.center, style: TextStyle(
                fontSize: 12,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              )),
            ),
          ),
        ));
      }).toList()),
    ]);
  }

  Widget _buildModeRow(BuildContext context) {
    return _buildSegmented(
      context: context,
      label: 'Reading mode',
      options: ['Vertical', 'Horizontal'],
      selected: readingMode,
      onSelected: onReadingModeChanged,
    );
  }

  Widget _buildDirectionRow(BuildContext context) {
    return _buildSegmented(
      context: context,
      label: 'Flip direction',
      options: ['Left to right', 'Right to left'],
      selected: horizontalDirection,
      onSelected: onHorizontalDirectionChanged,
    );
  }

  Widget _buildTextAppearanceRow(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: ListTile(
        leading: Icon(Icons.text_format, size: 20,
            color: theme.colorScheme.primary),
        title: Text('Text appearance', style: theme.textTheme.bodyMedium),
        subtitle: Text(textSummary,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
        trailing: Icon(Icons.arrow_forward_ios, size: 14,
            color: theme.colorScheme.onSurfaceVariant),
        onTap: onEditTextAppearance,
      ),
    );
  }

  Widget _buildThemeRow(BuildContext context) {
    final theme = Theme.of(context);
    final choices = ThemeCatalog.fromSettings(settings).choices();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sheetLabel(context, 'Reading theme'),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: choices.map((choice) {
            final rt = choice.theme;
            final selected = choice.key == readingTheme;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onReadingThemeChanged(choice.key),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 40,
                      decoration: BoxDecoration(
                        color: rt.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                          width: selected ? 1.6 : 0.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text('Aa', style: TextStyle(color: rt.text, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(width: 64, child: Text(
                      choice.name,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                    )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}
