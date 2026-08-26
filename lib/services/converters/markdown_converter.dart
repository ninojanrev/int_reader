import 'dart:io';

import 'package:markdown/markdown.dart' as md;

import '../../models/chapter.dart';

/// Markdown books: chapters split at ATX headings (`#`–`######`),
/// fence-aware (``` blocks never trigger a chapter break). Book title
/// comes from the first H1, falling back to the file name.
class MarkdownConverter {
  const MarkdownConverter();

  Future<ParsedEpub> parse(String path) async {
    final raw = await File(path).readAsString();
    final baseTitle = _titleFromPath(path);

    final chunks = _splitByH1(raw);

    // Document title: first H1 text, else file name.
    var title = baseTitle;
    for (final line in raw.split('\n')) {
      final m = RegExp(r'^#\s+(.*)$').firstMatch(line.trim());
      if (m != null) {
        title = m.group(1)!.trim();
        break;
      }
    }

    final chapters = <ParsedChapter>[];
    for (var i = 0; i < chunks.length; i++) {
      final chunkText = chunks[i].trim();
      if (chunkText.isEmpty) continue;

      // Chapter title from the chunk's first heading, if any.
      var chapterTitle = i == 0 ? title : 'Chapter ${i + 1}';
      final headingMatch =
          RegExp(r'^#{1,6}\s+(.+)$', multiLine: true).firstMatch(chunkText);
      if (headingMatch != null && i > 0) {
        chapterTitle = headingMatch.group(1)!.trim();
      }

      final html = md.markdownToHtml(chunkText);
      chapters.add(ParsedChapter(
        title: chapterTitle,
        htmlContent: html,
        index: chapters.length,
      ));
    }

    if (chapters.isEmpty) {
      chapters.add(ParsedChapter(
        title: title,
        htmlContent: '<p></p>',
        index: 0,
      ));
    }

    return ParsedEpub(title: title, author: 'Unknown Author', chapters: chapters);
  }

  /// Split on level-1 headings only (`# `, not deeper levels), ignoring
  /// lines inside fenced code blocks.
  static List<String> _splitByH1(String source) {
    final lines = source.split('\n');
    final chunks = <String>[];
    final buf = StringBuffer();
    var inFence = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        inFence = !inFence;
      }
      final isH1Boundary =
          !inFence && RegExp(r'^#\s+').hasMatch(line) && buf.length > 0;
      if (isH1Boundary) {
        chunks.add(buf.toString());
        buf.clear();
      }
      buf.writeln(line);
    }
    if (buf.length > 0) chunks.add(buf.toString());
    if (chunks.isEmpty) chunks.add(source);
    return chunks;
  }

  static String _titleFromPath(String path) => _baseName(path);

  static String _baseName(String path) {
    final base = path.replaceAll('\\', '/').split('/').last;
    final dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }
}
