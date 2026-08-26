import 'dart:io';

import '../../models/chapter.dart';
import '../epub_parser.dart';

/// Raw HTML books: reuses the EPUB chapter-cleaning pipeline
/// (`cleanChapterHtml` + `splitTopLevelElements`), grouping blocks under
/// `<h1>/<h2>` headings into chapters. Document title from `<title>`.
class HtmlConverter {
  const HtmlConverter();

  Future<ParsedEpub> parse(String path) async {
    final raw = await File(path).readAsString();
    final baseTitle = _titleFromPath(path);

    final docTitle =
        RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true, caseSensitive: false)
            .firstMatch(raw)?.group(1)?.trim();
    final title = docTitle != null && docTitle.isNotEmpty ? docTitle : baseTitle;

    final bodyHtml = EpubParserService.cleanChapterHtml(raw);
    final blocks = EpubParserService.splitTopLevelElements(bodyHtml)
        .where((b) => b.trim().isNotEmpty)
        .toList();

    if (blocks.isEmpty) {
      return ParsedEpub(
        title: title,
        author: null,
        chapters: [
          ParsedChapter(title: title, htmlContent: '<p></p>', index: 0),
        ],
      );
    }

    // Group blocks into chapters starting at h1/h2 boundaries.
    final chapters = <ParsedChapter>[];
    var currentHtml = StringBuffer();
    var currentTitle = title;

    void flushChapter() {
      if (currentHtml.length > 0) {
        chapters.add(ParsedChapter(
          title: currentTitle,
          htmlContent: currentHtml.toString(),
          index: chapters.length,
        ));
        currentHtml = StringBuffer();
      }
    }

    for (final block in blocks) {
      final heading = RegExp(r'^<h[12][\s>]', caseSensitive: false)
          .hasMatch(block.trim());
      if (heading && currentHtml.length > 0) {
        flushChapter();
        currentTitle = _stripTags(block).trim().isEmpty
            ? 'Chapter ${chapters.length + 1}'
            : _stripTags(block).trim();
      }
      currentHtml.write(block);
    }
    flushChapter();

    return ParsedEpub(title: title, author: null, chapters: chapters);
  }

  static String _stripTags(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  static String _titleFromPath(String path) => _baseName(path);

  static String _baseName(String path) {
    final base = path.replaceAll('\\', '/').split('/').last;
    final dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }
}

