import 'dart:io';
import 'dart:math' as math;

import '../../models/chapter.dart';

/// Plain-text books: blank-line-separated paragraphs, grouped ~20 per
/// chapter ("Part N").
class TxtConverter {
  const TxtConverter();

  static const _paragraphsPerChapter = 20;

  Future<ParsedEpub> parse(String path) async {
    final raw = await File(path).readAsString();
    final title = _titleFromPath(path);

    final clean = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final paragraphs = clean
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      return ParsedEpub(
        title: title,
        author: 'Unknown Author',
        chapters: [
          ParsedChapter(title: title, htmlContent: '<p></p>', index: 0),
        ],
      );
    }

    final chapters = <ParsedChapter>[];
    for (var i = 0; i < paragraphs.length; i += _paragraphsPerChapter) {
      final end = math.min(i + _paragraphsPerChapter, paragraphs.length);
      final chunk = paragraphs.sublist(i, end);
      final html = [
        for (final p in chunk) '<p>${_escape(p).replaceAll('\n', '<br/>')}</p>',
      ].join();
      chapters.add(ParsedChapter(
        title: chapters.isEmpty ? title : 'Part ${chapters.length + 1}',
        htmlContent: html,
        index: chapters.length,
      ));
    }

    return ParsedEpub(
      title: title,
      author: 'Unknown Author',
      chapters: chapters,
    );
  }

  static String _titleFromPath(String path) {
    final base = path.replaceAll('\\', '/').split('/').last;
    final dot = base.lastIndexOf('.');
    return (dot > 0 ? base.substring(0, dot) : base).trim().isEmpty
        ? 'Untitled'
        : base.substring(0, dot);
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

