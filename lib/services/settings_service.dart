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
  static const _kReaderBrightness = 'reader_brightness';
  static const _kFontWeight = 'font_weight';
  static const _kTextAlign = 'text_align';
  static const _kParagraphSpacing = 'paragraph_spacing';
  static const _kParagraphIndent = 'paragraph_indent';
  static const _kPerceptionExpander = 'perception_expander';
  static const _kHorizontalLimiter = 'horizontal_limiter';

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
  String readingMode = 'Scrolling'; // 'Scrolling' | 'Paged'
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
  double readerBrightness = -1; // -1 = system default, 0.0–1.0 = custom
  double fontWeight = 400; // 100–700
  String textAlign = 'Justify'; // 'Left' | 'Justify' | 'Center' | 'Right'
  double paragraphSpacing = 16;
  double paragraphIndent = 0;
  bool perceptionExpander = false;
  bool horizontalLimiter = false;

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

    // Migrate old reading mode values.
    final storedMode = _prefs.getString(_kReadingMode);
    if (storedMode == 'Vertical') {
      readingMode = 'Scrolling';
      await _prefs.setString(_kReadingMode, 'Scrolling');
    } else if (storedMode == 'Horizontal') {
      readingMode = 'Paged';
      await _prefs.setString(_kReadingMode, 'Paged');
    } else {
      readingMode = storedMode ?? 'Scrolling';
    }

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
    readerBrightness = _prefs.getDouble(_kReaderBrightness) ?? -1;
    fontWeight = _prefs.getDouble(_kFontWeight) ?? 400;
    textAlign = _prefs.getString(_kTextAlign) ?? 'Justify';
    paragraphSpacing = _prefs.getDouble(_kParagraphSpacing) ?? 16;
    paragraphIndent = _prefs.getDouble(_kParagraphIndent) ?? 0;
    perceptionExpander = _prefs.getBool(_kPerceptionExpander) ?? false;
    horizontalLimiter = _prefs.getBool(_kHorizontalLimiter) ?? false;

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

  Future<void> setReaderBrightness(double v) async {
    readerBrightness = v;
    await _prefs.setDouble(_kReaderBrightness, v);
  }

  Future<void> setFontWeight(double v) async {
    fontWeight = v;
    await _prefs.setDouble(_kFontWeight, v);
  }

  Future<void> setTextAlign(String v) async {
    textAlign = v;
    await _prefs.setString(_kTextAlign, v);
  }

  Future<void> setParagraphSpacing(double v) async {
    paragraphSpacing = v;
    await _prefs.setDouble(_kParagraphSpacing, v);
  }

  Future<void> setParagraphIndent(double v) async {
    paragraphIndent = v;
    await _prefs.setDouble(_kParagraphIndent, v);
  }

  Future<void> setPerceptionExpander(bool v) async {
    perceptionExpander = v;
    await _prefs.setBool(_kPerceptionExpander, v);
  }

  Future<void> setHorizontalLimiter(bool v) async {
    horizontalLimiter = v;
    await _prefs.setBool(_kHorizontalLimiter, v);
  }

  /// Restore every Reading-section option to its default and persist.
  /// Custom themes/fonts are kept; only selections revert.
  Future<void> resetReadingOptions() async {
    await setFontFamily('Serif');
    await setFontSize(17);
    await setLineHeight(1.6);
    await setFontWeight(400);
    await setTextAlign('Justify');
    await setParagraphSpacing(16);
    await setParagraphIndent(0);
    await setReadingTheme('Sepia');
    await setPageTurnStyle('Tap & swipe');
    await setKeepScreenAwake(true);
    await setReadingMode('Scrolling');
    await setHorizontalDirection('Left to right');
    await setVolumeKeysTurnPages(true);
    await setPageMargin(12.0);
    await setReaderBrightness(-1);
    await setPerceptionExpander(false);
    await setHorizontalLimiter(false);
  }
}

/// Global singleton — import this from any screen.
final settings = SettingsService();
