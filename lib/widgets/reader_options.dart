import 'package:flutter/material.dart';

/// Background/text pairing for each reading theme. Deliberately
/// separate from [AppColors] — reading themes need to override the
/// app chrome, including going fully black for OLED.
class ReaderTheme {
  final String label;
  final Color background;
  final Color text;
  final Color chrome; // top/bottom bar background when overlay is open

  const ReaderTheme({
    required this.label,
    required this.background,
    required this.text,
    required this.chrome,
  });
}

const Map<String, ReaderTheme> readerThemes = {
  'Light': ReaderTheme(
    label: 'Light',
    background: Color(0xFFFFFFFF),
    text: Color(0xFF201F1D),
    chrome: Color(0xFFFAFAF8),
  ),
  'Sepia': ReaderTheme(
    label: 'Sepia',
    background: Color(0xFFF4ECD8),
    text: Color(0xFF5B4636),
    chrome: Color(0xFFEDE3CC),
  ),
  'Dark': ReaderTheme(
    label: 'Dark',
    background: Color(0xFF1E1E1E),
    text: Color(0xFFD8D8D8),
    chrome: Color(0xFF262626),
  ),
  'OLED Black': ReaderTheme(
    label: 'OLED Black',
    background: Color(0xFF000000),
    text: Color(0xFFC7C7C7),
    chrome: Color(0xFF0A0A0A),
  ),
};

const Map<String, String> readerFontFamilies = {
  'Serif': 'Georgia',
  'Sans-Serif': 'Roboto',
  'Monospace': 'RobotoMono',
  'Literata': 'Literata',
  'Merriweather': 'Merriweather',
  'Atkinson Hyperlegible': 'Atkinson Hyperlegible',
};
