import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epub_reader/models/custom_reader_theme.dart';
import 'package:epub_reader/services/settings_service.dart';
import 'package:epub_reader/services/theme_catalog.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService();
    await settings.init();
  });

  group('ThemeCatalog', () {
    test('lists built-in presets', () {
      final catalog = ThemeCatalog.fromSettings(settings);
      final builtins = catalog.choices().where((c) => c.isBuiltin).toList();
      expect(builtins.map((c) => c.key),
          containsAll(['Light', 'Sepia', 'Dark', 'OLED Black']));
    });

    test('add persists through settings and appears in choices', () async {
      final catalog = ThemeCatalog.fromSettings(settings);
      final created = catalog.add(
        name: 'Midnight',
        background: const Color(0xFF101018),
        text: const Color(0xFFE0E0FF),
        chrome: const Color(0xFF181822),
      );

      // A fresh catalog over the same prefs sees the persisted theme.
      final reloaded = ThemeCatalog.fromSettings(settings);
      expect(reloaded.customs, hasLength(1));
      expect(reloaded.customs.first.name, 'Midnight');
      expect(reloaded.byId(created.id), isNotNull);
      expect(
          reloaded.choices().any((c) => !c.isBuiltin && c.name == 'Midnight'),
          isTrue);
    });

    test('duplicate creates de-duplicated editable copy of a preset',
        () async {
      final catalog = ThemeCatalog.fromSettings(settings);
      final sepia = catalog.choiceByKey('Sepia')!;
      final copy = catalog.duplicate(sepia);

      expect(copy.name, 'Sepia copy');
      expect(copy.background, sepia.theme.background.toARGB32());

      // Duplicating twice yields distinct names.
      final copy2 = catalog.duplicate(sepia);
      expect(copy2.name, 'Sepia copy 2');

      // Re-loaded from prefs.
      final reloaded = ThemeCatalog.fromSettings(settings);
      expect(reloaded.customs.map((c) => c.name),
          containsAll(['Sepia copy', 'Sepia copy 2']));
    });

    test('resolve falls back to Sepia for unknown keys', () {
      final catalog = ThemeCatalog.fromSettings(settings);
      expect(catalog.resolve('nonexistent-key').label, 'Sepia');
      expect(catalog.resolve('Sepia').label, 'Sepia');
    });

    test('remove reports whether the deleted theme was the default',
        () async {
      final catalog = ThemeCatalog.fromSettings(settings);
      final created = catalog.add(
        name: 'Temp',
        background: const Color(0xFF000000),
        text: const Color(0xFFFFFFFF),
        chrome: const Color(0xFF111111),
      );

      // Not currently the default.
      settings.readingTheme = 'Sepia';
      expect(catalog.remove(created.id), isFalse);
      expect(catalog.customs, isEmpty);

      // Set as default, then delete -> caller must reset.
      final again = catalog.add(
        name: 'Default candidate',
        background: const Color(0xFF000000),
        text: const Color(0xFFFFFFFF),
        chrome: const Color(0xFF111111),
      );
      settings.readingTheme = again.id;
      expect(catalog.remove(again.id), isTrue);
    });
  });

  group('CustomReaderTheme JSON round-trip', () {
    test('fromJson/toJson preserve all fields', () {
      final t = CustomReaderTheme(
        id: 'id1',
        name: 'Nord-ish',
        background: const Color(0xFF2E3440).toARGB32(),
        text: const Color(0xFFD8DEE9).toARGB32(),
        chrome: const Color(0xFF3B4252).toARGB32(),
      );
      final restored = CustomReaderTheme.fromJson(t.toJson());
      expect(restored.id, t.id);
      expect(restored.name, t.name);
      expect(restored.background, t.background);
      expect(restored.text, t.text);
      expect(restored.chrome, t.chrome);
    });

    test('toReaderTheme maps colors correctly', () {
      final rt = CustomReaderTheme(
        id: 'x',
        name: 'Custom',
        background: 0xFF111111,
        text: 0xFFEEEEEE,
        chrome: 0xFF222222,
      ).toReaderTheme();
      expect(rt.background, const Color(0xFF111111));
      expect(rt.text, const Color(0xFFEEEEEE));
      expect(rt.chrome, const Color(0xFF222222));
      expect(rt.label, 'Custom');
    });
  });
}

