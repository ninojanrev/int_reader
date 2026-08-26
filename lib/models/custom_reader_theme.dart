import 'package:flutter/material.dart';
import '../widgets/reader_options.dart';

/// A user-created reading theme. Built-in presets stay locked; users edit
/// copies. Colors are stored as 32-bit ARGB ints for easy JSON round-trips.
class CustomReaderTheme {
  final String id;
  String name;
  int background;
  int text;
  int chrome;

  CustomReaderTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.text,
    required this.chrome,
  });

  factory CustomReaderTheme.fromJson(Map<String, dynamic> json) {
    return CustomReaderTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      background: json['background'] as int,
      text: json['text'] as int,
      chrome: json['chrome'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'background': background,
        'text': text,
        'chrome': chrome,
      };

  /// The runtime theme used by the reader.
  ReaderTheme toReaderTheme() => ReaderTheme(
        label: name,
        background: Color(background),
        text: Color(text),
        chrome: Color(chrome),
      );
}
