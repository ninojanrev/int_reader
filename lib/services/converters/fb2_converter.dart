import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart' as xml;

import '../../models/chapter.dart';

/// FictionBook2 (.fb2) books: XML with `<description>` metadata and a
/// `<body>` of `<section>` elements. Each top-level section becomes a
/// chapter; inline markup maps to HTML (`emphasis`→em, `strong`→strong,
/// `subtitle`→h3). Cover images embedded as `<binary>` are extracted.
class Fb2Converter {
  const Fb2Converter();

  Future<ParsedEpub> parse(String path) async {
    final raw = await File(path).readAsString();
    final doc = xml.XmlDocument.parse(raw);

    // ---- Metadata ----
    String title = _baseName(path);
    String author = 'Unknown Author';
    final desc = _firstLocal(doc, 'description');
    if (desc != null) {
      final bt = _firstLocal(desc, 'book-title');
      if (bt != null && bt.innerText.trim().isNotEmpty) title = bt.innerText.trim();

      final authorEl = _firstLocal(desc, 'author');
      if (authorEl != null) {
        final parts = [
          for (final n in ['first-name', 'middle-name', 'last-name', 'nick'])
            ...[for (final e in authorEl.findElements(n)) e.innerText.trim()]
        ].where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) author = parts.join(' ');
      }
    }

    // ---- Cover ----
    List<int>? coverBytes;
    final coverImageRef = _coverHref(doc);
    if (coverImageRef != null) {
      for (final binary in doc.findAllElements('binary')) {
        final id = _attr(binary, 'id');
        if (id == coverImageRef) {
          try {
            coverBytes = base64.decode(binary.innerText.replaceAll('\n', '').trim());
          } catch (_) {}
          break;
        }
      }
    }

    // ---- Body sections ----
    final chapters = <ParsedChapter>[];
    for (final body in doc.findAllElements('body')) {
      final sections =
          body.childElements.where((e) => e.name.local == 'section').toList();
      for (var i = 0; i < sections.length; i++) {
        final section = sections[i];
        final titleEl = _firstLocal(section, 'title');
        var chapterTitle = titleEl != null && titleEl.innerText.trim().isNotEmpty
            ? titleEl.innerText.trim()
                .split('\n')
                .map((l) => l.trim())
                .where((l) => l.isNotEmpty)
                .join(' ')
            : 'Section ${i + 1}';

        final htmlParts = <String>[];
        for (final child in section.childElements) {
          if (child.name.local == 'title') continue;
          htmlParts.add(_convertElement(child));
        }
        chapters.add(ParsedChapter(
          title: chapterTitle,
          htmlContent: htmlParts.join(),
          index: chapters.length,
        ));
      }
    }

    if (chapters.isEmpty) {
      chapters.add(ParsedChapter(
        title: title,
        htmlContent: '<p></p>',
        index: 0,
      ));
    }

    return ParsedEpub(
      title: title,
      author: author,
      chapters: chapters,
      coverImageBytes: coverBytes,
    );
  }

  // ---- helpers ----

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static xml.XmlElement? _firstLocal(xml.XmlNode parent, String local) {
    for (final e in parent.descendantElements) {
      if (e.name.local == local) return e;
    }
    return null;
  }

  static String? _coverHref(xml.XmlDocument doc) {
    for (final image in doc.descendantElements.where((e) => e.name.local == 'image')) {
      for (final attr in image.attributes) {
        if (attr.name.local.toLowerCase() == 'href') {
          final v = attr.value;
          return v.startsWith('#') ? v.substring(1) : v;
        }
      }
    }
    return null;
  }

  static String? _attr(xml.XmlElement e, String local) {
    for (final a in e.attributes) {
      if (a.name.local == local) return a.value;
    }
    return null;
  }

  /// Convert an fb2 element subtree into HTML.
  static String _convertElement(xml.XmlElement element) {
    final local = element.name.local;
    final children = element.childElements.map(_convertElement).join();
    final text = element.children
        .whereType<xml.XmlText>()
        .map((t) => t.value)
        .join(' ');

    switch (local) {
      case 'p':
        final inner = children.isNotEmpty ? children : _escape(text);
        return '<p>$inner</p>';
      case 'emphasis':
        return '<em>${children.isNotEmpty ? children : _escape(text)}</em>';
      case 'strong':
      case 'b':
        return '<strong>${children.isNotEmpty ? children : _escape(text)}</strong>';
      case 'subtitle':
        return '<h3>${children.isNotEmpty ? children : _escape(text)}</h3>';
      case 'empty-line':
        return '<br/>';
      case 'v':
      case 'text-field':
        return text.isEmpty ? '' : '<p>${_escape(text)}</p>';
      default:
        return children.isNotEmpty ? children : _escape(text);
    }
  }

  static String _baseName(String path) {
    final base = path.replaceAll('\\', '/').split('/').last;
    final dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }
}
