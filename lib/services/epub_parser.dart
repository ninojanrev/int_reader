import 'dart:convert';
import 'dart:io';
import 'package:epub_plus/epub_plus.dart';
import 'package:image/image.dart' as img;
import '../models/chapter.dart';

/// Parses EPUB files and extracts metadata, chapters, and images.
class EpubParserService {
  /// Parse an EPUB file from disk and extract all content.
  Future<ParsedEpub> parseFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return parseBytes(bytes);
  }

  /// Parse EPUB bytes and extract all content.
  Future<ParsedEpub> parseBytes(List<int> bytes) async {
    final epubBook = await EpubReader.readBook(bytes);

    // Extract metadata
    final title = epubBook.title ?? 'Untitled';
    final author = epubBook.author;

    // Extract chapters
    final chapters = <ParsedChapter>[];
    int index = 0;

    void extractChapters(List<EpubChapter> epubChapters) {
      for (final chapter in epubChapters) {
        final chapterTitle = chapter.title ?? 'Chapter ${index + 1}';
        final htmlContent = chapter.htmlContent ?? '';
        chapters.add(ParsedChapter(
          title: chapterTitle,
          htmlContent: htmlContent,
          index: index,
        ));
        index++;

        // Recursively extract sub-chapters
        if (chapter.subChapters.isNotEmpty) {
          extractChapters(chapter.subChapters);
        }
      }
    }

    extractChapters(epubBook.chapters);

    // Extract cover image
    List<int>? coverImageBytes = _extractCover(epubBook);

    // Extract embedded images
    final images = <String, List<int>>{};
    final contentImages = epubBook.content?.images ?? const {};
    for (final entry in contentImages.entries) {
      final content = entry.value.content;
      if (content != null && content.isNotEmpty) {
        images[entry.key] = content;
      }
    }

    return ParsedEpub(
      title: title,
      author: author,
      chapters: chapters,
      coverImageBytes: coverImageBytes,
      images: images,
    );
  }

  /// Extract the cover image as JPEG bytes.
  ///
  /// Strategy, in order:
  /// 1. The pre-parsed [EpubBook.coverImage] (populated by epub_plus via the
  ///    EPUB2 `<meta name="cover">` convention).
  /// 2. An EPUB3 manifest item with `properties` containing `cover-image`.
  /// 3. Any image whose file name contains "cover".
  List<int>? _extractCover(EpubBook epubBook) {
    // 1. Already decoded by the reader.
    final decoded = epubBook.coverImage;
    if (decoded != null) {
      try {
        return img.encodeJpg(img.copyResize(decoded, width: 600));
      } catch (_) {}
    }

    // 2. EPUB3 cover-image manifest property.
    final manifestItems =
        epubBook.schema?.package?.manifest?.items ?? const [];
    final images = epubBook.content?.images ?? const {};
    String? coverHref;

    for (final item in manifestItems) {
      final props = item.properties?.toLowerCase() ?? '';
      if (props.contains('cover-image')) {
        coverHref = item.href;
        break;
      }
    }
    if (coverHref != null && images.containsKey(coverHref)) {
      final bytes = images[coverHref]!.content;
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }

    // 3. Filename fallback.
    for (final entry in images.entries) {
      final name = entry.key.toLowerCase();
      final content = entry.value.content;
      if ((name.contains('cover')) &&
          content != null &&
          content.isNotEmpty) {
        return content;
      }
    }
    return null;
  }

  /// Rewrite `<img src="...">` references to inline base64 data URIs so
  /// chapter HTML renders its embedded images without filesystem access.
  static String inlineImages(String htmlContent, Map<String, List<int>> images) {
    if (htmlContent.isEmpty || images.isEmpty) return htmlContent;

    return htmlContent.replaceAllMapped(
      RegExp('(src\\s*=\\s*["\\\'])([^"\\\']+)(["\\\'])', caseSensitive: false),
      (match) {
        final src = match.group(2)!;
        final key = _resolveImageKey(src, images);
        if (key == null) return match.group(0)!;
        final mime = _mimeFor(key);
        if (mime == null) return match.group(0)!;
        final dataUri =
            'data:$mime;base64,${base64Encode(images[key]!)}';
        return '${match.group(1)}$dataUri${match.group(3)}';
      },
    );
  }

  /// Find the archive key matching an HTML `src`, tolerating relative paths
  /// and case differences between the OPF and the zip entries.
  static String? _resolveImageKey(String src, Map<String, List<int>> images) {
    var norm = src.replaceAll('\\', '/').toLowerCase();
    while (norm.startsWith('./')) {
      norm = norm.substring(2);
    }
    final srcBase = norm.split('/').last;

    for (final key in images.keys) {
      final k = key.replaceAll('\\', '/').toLowerCase();
      if (k == norm || k.endsWith('/$norm') || norm.endsWith(k)) {
        return key;
      }
      if (srcBase.isNotEmpty && k.split('/').last == srcBase) {
        return key;
      }
    }
    return null;
  }

  static String? _mimeFor(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return null; // SVG etc. is not supported by flutter_html's img handler
    }
  }

  static const _voidElements = {
    'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
    'link', 'meta', 'param', 'source', 'track', 'wbr',
  };

  static final _tagRe = RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9-]*)\b[^>]*?>');
  static final _xmlPrologRe = RegExp(r'^\s*<\?xml[^>]*\?>\s*');
  static final _doctypeRe = RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false);
  static final _commentRe = RegExp(r'<!--.*?-->', dotAll: true);
  static final _cdataRe = RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true);
  static final _bodyOpenRe = RegExp(r'<body\b[^>]*>', caseSensitive: false);

  /// Extract the inner HTML of <body>, falling back to the whole document.
  static String extractBodyContent(String html) {
    final open = _bodyOpenRe.firstMatch(html);
    if (open == null) return html;
    final close = html.toLowerCase().lastIndexOf('</body>');
    if (close <= open.end) return html;
    return html.substring(open.end, close);
  }

  /// Clean a chapter document into something the splitter can trust:
  /// drop XML prologs, DOCTYPEs, comments; replace CDATA with its text.
  static String cleanChapterHtml(String html) {
    var out = html.replaceFirst(_xmlPrologRe, '');
    out = out.replaceAll(_doctypeRe, '');
    out = out.replaceAllMapped(_cdataRe, (m) => m.group(1) ?? '');
    out = out.replaceAll(_commentRe, '');
    return extractBodyContent(out);
  }

  /// Split chapter HTML into top-level element fragments. Fragments are the
  /// atomic unit of horizontal pagination, so no line of text is ever cut
  /// across a page boundary.
  static List<String> splitTopLevelElements(String html) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) return const [];
    final blocks = <String>[];
    var depth = 0;
    int? start;
    for (final match in _tagRe.allMatches(trimmed)) {
      // NOTE: (/?) always participates, so an opening tag yields '' here.
      final isClosing = (match.group(1) ?? '').isNotEmpty;
      final name = match.group(2)!.toLowerCase();
      final isVoid = _voidElements.contains(name) ||
          match.group(0)!.endsWith('/>');
      if (!isClosing && !isVoid) {
        if (depth == 0 && start == null) start = match.start;
        depth++;
      } else if (isClosing && !isVoid) {
        depth--;
        if (depth <= 0) {
          depth = 0;
          if (start != null) {
            blocks.add(trimmed.substring(start, match.end));
            start = null;
          }
        }
      }
    }
    if (start != null) blocks.add(trimmed.substring(start));

    // Leading stray text before the first element.
    final firstTag = _tagRe.firstMatch(trimmed);
    if (firstTag != null && firstTag.start > 0 &&
        trimmed.substring(0, firstTag.start).trim().isNotEmpty) {
      blocks.insert(0, trimmed.substring(0, firstTag.start));
    }
    if (blocks.isEmpty) blocks.add(trimmed);
    return blocks;
  }

  /// Split any single block longer than [maxBlockChars] at sentence
  /// boundaries, re-wrapping each chunk in the original element's tags so
  /// styling is preserved. This keeps fragments comfortably under page
  /// height so pagination never has to cut through a line.
  static List<String> splitLongBlocks(List<String> blocks,
      {int maxBlockChars = 700}) {
    final result = <String>[];
    for (final block in blocks) {
      if (block.length <= maxBlockChars) {
        result.add(block);
        continue;
      }
      final pieces = _splitWrapped(block, maxBlockChars);
      result.addAll(pieces.isEmpty ? [block] : pieces);
    }
    return result;
  }

  /// True when [text] leaves a double quote unclosed — straight `"`
  /// toggles parity; curly `“`/`”` open/close respectively.
  /// Single quotes are ignored (apostrophes would false-trigger).
  static bool endsInsideOpenQuote(String text) {
    var straight = false;
    var curlyDepth = 0;
    for (final ch in text.runes) {
      if (ch == 0x22) {
        straight = !straight;
      } else if (ch == 0x201C) {
        curlyDepth++;
      } else if (ch == 0x201D) {
        if (curlyDepth > 0) curlyDepth--;
      }
    }
    return straight || curlyDepth > 0;
  }

  /// Split one element block into same-tag chunks of roughly
  /// [maxChunkChars] characters, cutting only between sentences AND only
  /// where no double quote is currently open. If quotes never rebalance
  /// (source typo), a forced split at twice the target size keeps
  /// fragments bounded.
  static List<String> _splitWrapped(String block, int maxChunkChars) {
    final match =
        RegExp(r'^\s*<([a-zA-Z][a-zA-Z0-9-]*)((?:[^>"]|"[^"]*")*)>(.*)</\1>\s*$',
            dotAll: true)
            .firstMatch(block);
    if (match == null) return const [];

    final tagName = match.group(1)!;
    final attrs = match.group(2) ?? '';
    final inner = match.group(3)!;

    // Sentence-ish units (trailing whitespace kept with each).
    final sentences =
        inner.split(RegExp(r'(?<=[.!?\u2026])\s+')).toList();

    const hardCapFactor = 2.0;

    final chunks = <String>[];
    final buf = StringBuffer();
    var len = 0;

    void flush() {
      if (len > 0) {
        chunks.add(buf.toString());
        buf.clear();
        len = 0;
      }
    }

    // Cumulative double-quote parity across everything consumed so far.
    var straightOpen = false;
    var curlyDepth = 0;
    void absorbQuotes(String piece) {
      for (final ch in piece.runes) {
        if (ch == 0x22) {
          straightOpen = !straightOpen; // "
        } else if (ch == 0x201C) {
          curlyDepth++; // left curly
        } else if (ch == 0x201D) {
          if (curlyDepth > 0) curlyDepth--; // right curly
        }
      }
    }

    for (final s in sentences) {
      final insideQuote = straightOpen || curlyDepth > 0;
      final wouldBe = len + s.length + (len > 0 ? 1 : 0);
      final overHardCap = len >= maxChunkChars * hardCapFactor;

      // Normal split: chunk reached target size and no quote is open.
      // Forced valve: stuck inside an unclosed quote far past the target
      // size — split anyway so a broken paragraph can't make a giant
      // fragment.
      if (len > 0 &&
          (wouldBe > maxChunkChars && !insideQuote || overHardCap)) {
        flush();
      }

      buf.write(s);
      buf.write(' ');
      len += s.length + 1;
      absorbQuotes(s);
    }
    flush();
    if (chunks.length <= 1) return const [];

    return [
      for (final chunk in chunks) '<$tagName$attrs>${chunk.trim()}</$tagName>'
    ];
  }

  /// Merge tiny fragments so pagination/measurement deals with fewer,
  /// reasonably-sized chunks. Merges always end at block boundaries, so
  /// text is still never split mid-line.
  static List<String> groupFragments(List<String> blocks,
      {int maxCharsPerGroup = 400}) {
    final grouped = <String>[];
    final buffer = StringBuffer();
    var length = 0;
    for (final block in blocks) {
      if (length > 0 && length + block.length > maxCharsPerGroup) {
        grouped.add(buffer.toString());
        buffer.clear();
        length = 0;
      }
      buffer.write(block);
      length += block.length;
    }
    if (length > 0) grouped.add(buffer.toString());
    return grouped;
  }

  /// Full pipeline: clean the document, split into top-level blocks, split
  /// over-long blocks at sentence boundaries, then group small blocks.
  /// Returns fragments sized for horizontal page slicing.
  static List<String> chapterFragments(String html) {
    final cleaned = cleanChapterHtml(html);
    var blocks =
        splitTopLevelElements(cleaned).where((b) => b.trim().isNotEmpty);
    if (blocks.isEmpty) {
      return cleaned.trim().isEmpty ? const [] : [cleaned];
    }
    blocks = splitLongBlocks(blocks.toList());
    return groupFragments(blocks.toList());
  }

  /// Vertical-scrolling pipeline: natural top-level blocks only — no
  /// sentence splitting, no size merging. Paragraphs render exactly as
  /// authored, so no mid-sentence seams appear between list items.
  /// (No page-height constraint exists in vertical mode, so oversized
  /// blocks are fine here.)
  static List<String> chapterBlocksForScrolling(String html) {
    final cleaned = cleanChapterHtml(html);
    final blocks =
        splitTopLevelElements(cleaned).where((b) => b.trim().isNotEmpty);
    if (blocks.isEmpty) {
      return cleaned.trim().isEmpty ? const [] : [cleaned];
    }
    return blocks.toList();
  }
}

/// Global singleton instance.
final epubParser = EpubParserService();

/// Top-level function for use with [compute]. Runs the full EPUB parse
/// (ZIP decompression, chapter extraction, image copying, cover encoding)
/// in a background isolate so the UI thread stays responsive.
Future<ParsedEpub> parseEpubInIsolate(String filePath) async {
  return epubParser.parseFile(filePath);
}

/// Top-level function for use with [compute]. Inlines images into chapter
/// HTML in a background isolate to avoid blocking the UI thread.
///
/// [args] is a list: [String htmlContent, Map<String, List<int>> images]
String inlineImagesInIsolate(List<dynamic> args) {
  final html = args[0] as String;
  final images = (args[1] as Map).cast<String, List<int>>();
  return EpubParserService.inlineImages(html, images);
}

/// Top-level function for use with [compute]. Fragments chapter HTML in a
/// background isolate to avoid blocking the UI thread.
List<String> fragmentChapterInIsolate(String html) {
  return EpubParserService.chapterFragments(html);
}

/// Top-level function for use with [compute]. Splits chapter HTML into
/// natural top-level blocks for vertical scrolling mode.
List<String> verticalFragmentChapterInIsolate(String html) {
  return EpubParserService.chapterBlocksForScrolling(html);
}

