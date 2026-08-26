import 'package:flutter/material.dart';
import '../models/custom_reader_theme.dart';
import 'settings_service.dart';
import '../widgets/reader_options.dart';

/// A selectable entry in the theme pickers: either a locked built-in
/// preset (keyed by label) or a user-created custom theme (keyed by id).
class ThemeChoice {
  final String key;
  final String name;
  final ReaderTheme theme;
  final bool isBuiltin;

  const ThemeChoice({
    required this.key,
    required this.name,
    required this.theme,
    required this.isBuiltin,
  });
}

/// Merges the four locked built-in presets with user-created themes.
/// Resolution falls back to Sepia when a stored key no longer exists
/// (e.g. its custom theme was deleted).
class ThemeCatalog {
  static const fallbackKey = 'Sepia';

  final SettingsService settings;
  final List<CustomReaderTheme> customs;

  ThemeCatalog({required this.settings, List<CustomReaderTheme>? customs})
      : customs = customs ?? [];

  /// Load user themes from persisted settings.
  factory ThemeCatalog.fromSettings(SettingsService settings) {
    return ThemeCatalog(settings: settings, customs: settings.customReaderThemes);
  }

  List<ThemeChoice> choices() {
    final builtins = [
      for (final entry in readerThemes.entries)
        ThemeChoice(
            key: entry.key, name: entry.key, theme: entry.value, isBuiltin: true),
    ];
    final custom = [
      for (final c in customs)
        ThemeChoice(key: c.id, name: c.name, theme: c.toReaderTheme(), isBuiltin: false),
    ];
    return [...builtins, ...custom];
  }

  ThemeChoice? choiceByKey(String key) {
    for (final c in choices()) {
      if (c.key == key) return c;
    }
    return null;
  }

  /// Resolve a stored key to a runtime theme; Sepia when missing.
  ReaderTheme resolve(String key) =>
      choiceByKey(key)?.theme ?? readerThemes[fallbackKey]!;

  CustomReaderTheme? byId(String id) {
    for (final c in customs) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Create a custom theme; returns the new instance.
  CustomReaderTheme add({
    required String name,
    required Color background,
    required Color text,
    required Color chrome,
  }) {
    final theme = CustomReaderTheme(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      background: background.toARGB32(),
      text: text.toARGB32(),
      chrome: chrome.toARGB32(),
    );
    customs.add(theme);
    _persist();
    return theme;
  }

  /// Duplicate any choice into a new editable custom theme named
  /// "<name> copy" (de-duplicated with a counter).
  CustomReaderTheme duplicate(ThemeChoice source) {
    final existingNames = customs.map((c) => c.name).toSet();
    var copyName = '${source.name} copy';
    var n = 2;
    while (existingNames.contains(copyName)) {
      copyName = '${source.name} copy $n';
      n++;
    }
    return add(
      name: copyName,
      background: source.theme.background,
      text: source.theme.text,
      chrome: source.theme.chrome,
    );
  }

  void update(CustomReaderTheme theme) {
    _persist();
  }

  /// Remove a custom theme. Returns true if it was the currently selected
  /// key so callers can reset their default.
  bool remove(String id) {
    final wasDefault = settings.readingTheme == id;
    customs.removeWhere((c) => c.id == id);
    _persist();
    return wasDefault;
  }

  void _persist() => settings.saveCustomReaderThemes(customs);
}



