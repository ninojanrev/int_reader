import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_reader_theme.dart';

/// Centralised persistence for app settings. Every value is loaded once
/// at startup and written back on every change so the mockup survives
/// app restarts.
class SettingsService {
  static const _kDarkMode = 'dark_mode';
  static const _kFontFamily = 'font_family';
  static const _kFontSize = 'font_size';
  static const _kReadingTheme = 'reading_theme';
  static const _kSortOrder = 'sort_order';
  static const _kPageTurnStyle = 'page_turn_style';
  static const _kKeepScreenAwake = 'keep_screen_awake';
  static const _kReminderEnabled = 'reminder_enabled';
  static const _kReminderMinutesOfDay = 'reminder_minutes_of_day';
  static const _kReadingMode = 'reading_mode';
  static const _kHorizontalDirection = 'horizontal_direction';
  static const _kLineHeight = 'line_height';
  static const _kCustomThemes = 'custom_reader_themes';
  static const _kVolumeKeysTurnPages = 'volume_keys_turn_pages';
  static const _kReplaceOnImport = 'replace_on_import';
  static const _kImportConflictMode = 'import_conflict_mode';
  static const _kAnimatedBackdrop = 'animated_library_backdrop';
  static const _kContinueReadingSort = 'continue_reading_sort';
  static const _kPageMargin = 'page_margin';
  static const _kOpenLastBookOnStart = 'open_last_book_on_start';

  late SharedPreferences _prefs;

  // Cached values with sensible defaults
  bool darkMode = false;
  String fontFamily = 'Serif';
  double fontSize = 17;
  String readingTheme = 'Sepia';
  String sortOrder = 'Recently added';
  String pageTurnStyle = 'Tap & swipe';
  bool keepScreenAwake = true;
  bool reminderEnabled = false;
  int reminderMinutesOfDay = 20 * 60; // 20:00
  String readingMode = 'Vertical'; // 'Vertical' | 'Horizontal'
  String horizontalDirection = 'Left to right'; // 'Left to right' | 'Right to left'
  double lineHeight = 1.6;
  List<CustomReaderTheme> customReaderThemes = [];
  bool volumeKeysTurnPages = true;
  bool replaceOnImport = true;
  String importConflictMode = 'Ask every time'; // 'Ask every time' | 'Replace larger automatically'
  bool animatedLibraryBackdrop = true;
  String continueReadingSort = 'Last opened'; // 'Last opened' | 'Progress' | 'Date added'
  double pageMargin = 12.0;
  bool openLastBookOnStart = false;

  /// Call once before runApp.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    darkMode = _prefs.getBool(_kDarkMode) ?? false;
    fontFamily = _prefs.getString(_kFontFamily) ?? 'Serif';
    fontSize = _prefs.getDouble(_kFontSize) ?? 17;
    readingTheme = _prefs.getString(_kReadingTheme) ?? 'Sepia';
    sortOrder = _prefs.getString(_kSortOrder) ?? 'Recently added';
    pageTurnStyle = _prefs.getString(_kPageTurnStyle) ?? 'Tap & swipe';
    keepScreenAwake = _prefs.getBool(_kKeepScreenAwake) ?? true;
    reminderEnabled = _prefs.getBool(_kReminderEnabled) ?? false;
    reminderMinutesOfDay = _prefs.getInt(_kReminderMinutesOfDay) ?? 20 * 60;
    readingMode = _prefs.getString(_kReadingMode) ?? 'Vertical';
    horizontalDirection =
        _prefs.getString(_kHorizontalDirection) ?? 'Left to right';
    lineHeight = _prefs.getDouble(_kLineHeight) ?? 1.6;
    volumeKeysTurnPages = _prefs.getBool(_kVolumeKeysTurnPages) ?? true;
    replaceOnImport = _prefs.getBool(_kReplaceOnImport) ?? true;
    importConflictMode =
        _prefs.getString(_kImportConflictMode) ?? 'Ask every time';
    animatedLibraryBackdrop = _prefs.getBool(_kAnimatedBackdrop) ?? true;
    continueReadingSort =
        _prefs.getString(_kContinueReadingSort) ?? 'Last opened';
    pageMargin = _prefs.getDouble(_kPageMargin) ?? 12.0;
    openLastBookOnStart = _prefs.getBool(_kOpenLastBookOnStart) ?? false;
    final themesJson = _prefs.getString(_kCustomThemes);
    if (themesJson != null) {
      try {
        customReaderThemes = (jsonDecode(themesJson) as List)
            .map((e) => CustomReaderTheme.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        customReaderThemes = [];
      }
    }
  }

  Future<void> setDarkMode(bool v) async {
    darkMode = v;
    await _prefs.setBool(_kDarkMode, v);
  }

  Future<void> setFontFamily(String v) async {
    fontFamily = v;
    await _prefs.setString(_kFontFamily, v);
  }

  Future<void> setFontSize(double v) async {
    fontSize = v;
    await _prefs.setDouble(_kFontSize, v);
  }

  Future<void> setReadingTheme(String v) async {
    readingTheme = v;
    await _prefs.setString(_kReadingTheme, v);
  }

  Future<void> setSortOrder(String v) async {
    sortOrder = v;
    await _prefs.setString(_kSortOrder, v);
  }

  Future<void> setPageTurnStyle(String v) async {
    pageTurnStyle = v;
    await _prefs.setString(_kPageTurnStyle, v);
  }

  Future<void> setKeepScreenAwake(bool v) async {
    keepScreenAwake = v;
    await _prefs.setBool(_kKeepScreenAwake, v);
  }

  Future<void> setReminderEnabled(bool v) async {
    reminderEnabled = v;
    await _prefs.setBool(_kReminderEnabled, v);
  }

  Future<void> setReminderTime(int minutesOfDay) async {
    reminderMinutesOfDay = minutesOfDay;
    await _prefs.setInt(_kReminderMinutesOfDay, minutesOfDay);
  }

  Future<void> setReadingMode(String v) async {
    readingMode = v;
    await _prefs.setString(_kReadingMode, v);
  }

  Future<void> setHorizontalDirection(String v) async {
    horizontalDirection = v;
    await _prefs.setString(_kHorizontalDirection, v);
  }

  Future<void> setLineHeight(double v) async {
    lineHeight = v;
    await _prefs.setDouble(_kLineHeight, v);
  }

  /// Persist the custom theme list (called by ThemeCatalog after CRUD).
  Future<void> saveCustomReaderThemes(
      List<CustomReaderTheme> themes) async {
    customReaderThemes = themes;
    await _prefs.setString(
        _kCustomThemes, jsonEncode([for (final t in themes) t.toJson()]));
  }

  Future<void> setVolumeKeysTurnPages(bool v) async {
    volumeKeysTurnPages = v;
    await _prefs.setBool(_kVolumeKeysTurnPages, v);
  }

  Future<void> setReplaceOnImport(bool v) async {
    replaceOnImport = v;
    await _prefs.setBool(_kReplaceOnImport, v);
  }

  Future<void> setImportConflictMode(String v) async {
    importConflictMode = v;
    await _prefs.setString(_kImportConflictMode, v);
  }

  Future<void> setAnimatedLibraryBackdrop(bool v) async {
    animatedLibraryBackdrop = v;
    await _prefs.setBool(_kAnimatedBackdrop, v);
  }

  Future<void> setPageMargin(double v) async {
    pageMargin = v;
    await _prefs.setDouble(_kPageMargin, v);
  }

  Future<void> setContinueReadingSort(String v) async {
    continueReadingSort = v;
    await _prefs.setString(_kContinueReadingSort, v);
  }

  Future<void> setOpenLastBookOnStart(bool v) async {
    openLastBookOnStart = v;
    await _prefs.setBool(_kOpenLastBookOnStart, v);
  }

  /// Restore every Reading-section option to its default and persist.
  /// Custom themes/fonts are kept; only selections revert.
  Future<void> resetReadingOptions() async {
    await setFontFamily('Serif');
    await setFontSize(17);
    await setLineHeight(1.6);
    await setReadingTheme('Sepia');
    await setPageTurnStyle('Tap & swipe');
    await setKeepScreenAwake(true);
    await setReadingMode('Vertical');
    await setHorizontalDirection('Left to right');
    await setVolumeKeysTurnPages(true);
    await setPageMargin(12.0);
  }
}

/// Global singleton — import this from any screen.
final settings = SettingsService();
