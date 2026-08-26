import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registry of reader fonts: the built-in system/bundled families declared
/// in [readerFontFamilies] plus fonts the user imported from device
/// storage. Imported files are copied into the app documents directory and
/// registered with Flutter's [FontLoader] at runtime.
class FontService {
  static const _kUserFonts = 'user_fonts'; // json: {displayName: fileName}
  static const _uuid = Uuid();

  /// Display name -> font family name for user-imported fonts that were
  /// successfully loaded this session.
  final Map<String, String> _userFonts = {};
  final Map<String, String> _userFontFiles = {};

  bool _loaded = false;

  /// All selectable fonts: built-ins first, then user imports.
  Map<String, String> allFonts(Map<String, String> builtinFonts) {
    return {...builtinFonts, ..._userFonts};
  }

  /// Resolve a display name to a real family; falls back to Georgia.
  String resolveFamily(String displayName, Map<String, String> builtinFonts) {
    final all = allFonts(builtinFonts);
    return all[displayName] ?? builtinFonts['Serif'] ?? 'Georgia';
  }

  bool isUserFont(String displayName) => _userFonts.containsKey(displayName);

  /// Load persisted user fonts at startup (non-fatal on failure).
  Future<void> loadSavedFonts() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kUserFonts);
      if (json == null) return;
      final decoded = Map<String, dynamic>.from(jsonDecode(json));
      final dir = await _fontsDirectory();
      for (final entry in decoded.entries) {
        final file = File(p.join(dir.path, entry.value as String));
        if (!await file.exists()) continue; // dropped silently
        final ok = await _registerFontFile(
            family: entry.key, filePath: file.path);
        if (ok) {
          _userFonts[entry.key] = entry.key;
          _userFontFiles[entry.key] = entry.value as String;
        }
      }
    } catch (_) {
      // Never block startup over fonts.
    }
  }

  /// Import a font from [sourcePath]: copy into app storage, register it,
  /// persist. Returns the display name, or null on failure.
  Future<String?> importFont(String sourcePath) async {
    try {
      final ext = p.extension(sourcePath).toLowerCase();
      if (ext != '.ttf' && ext != '.otf') return null;

      // Derive a friendly display name from the file name.
      final base = p.basenameWithoutExtension(sourcePath)
          .replaceAll(RegExp(r'[_-]+'), ' ')
          .trim();
      final displayName = base.isEmpty ? 'Imported font' : base;
      if (_userFonts.containsKey(displayName)) {
        return displayName; // already imported
      }

      final dir = await _fontsDirectory();
      var fileName = '${_uuid.v4()}$ext';
      final dest = File(p.join(dir.path, fileName));
      await File(sourcePath).copy(dest.path);

      final family = 'UserFont_${_uuid.v4().substring(0, 8)}';
      final ok = await _registerFontFile(family: family, filePath: dest.path);
      if (!ok) {
        try {
          await dest.delete();
        } catch (_) {}
        return null;
      }

      _userFonts[displayName] = family;
      _userFontFiles[displayName] = fileName;
      await _persist();
      return displayName;
    } catch (_) {
      return null;
    }
  }

  /// Remove an imported font (registry + persisted entry + file).
  Future<void> removeFont(String displayName) async {
    final fileName = _userFontFiles.remove(displayName);
    _userFonts.remove(displayName);
    await _persist();
    if (fileName == null) return;
    try {
      final dir = await _fontsDirectory();
      final f = File(p.join(dir.path, fileName));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<Directory> _fontsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'fonts'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<bool> _registerFontFile(
      {required String family, required String filePath}) async {
    try {
      final data = await File(filePath).readAsBytes();
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(data.buffer)));
      await loader.load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserFonts, jsonEncode(_userFontFiles));
    } catch (_) {}
  }
}

/// Global singleton instance.
final fontService = FontService();
