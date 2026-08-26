import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:epub_reader/services/book_parser.dart';
import 'package:epub_reader/services/cover_generator.dart';
import 'package:epub_reader/services/converters/fb2_converter.dart';
import 'package:epub_reader/services/converters/html_converter.dart';
import 'package:epub_reader/services/converters/markdown_converter.dart';
import 'package:epub_reader/services/converters/txt_converter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('book_formats');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<File> write(String ext, String content) async {
    final f = File('${tempDir.path}/sample.$ext');
    await f.writeAsString(content);
    return f;
  }

  group('TxtConverter', () {
    test('splits blank-line paragraphs into <p> blocks', () async {
      final f = await write('txt', 'First para.\n\nSecond para.\n\nThird.');
      final parsed = await const TxtConverter().parse(f.path);
      expect(parsed.chapters, hasLength(1));
      expect(parsed.chapters.first.htmlContent,
          contains('<p>First para.</p>'));
      expect(parsed.chapters.first.htmlContent, contains('Third.'));
      expect(parsed.title, isNotEmpty);
    });

    test('groups long books into Part chapters', () async {
      final paras =
          List.generate(45, (i) => 'Paragraph number $i of the text.').join('\n\n');
      final f = await write('txt', paras);
      final parsed = await const TxtConverter().parse(f.path);
      expect(parsed.chapters.length, greaterThan(1));
      expect(parsed.chapters.last.title, startsWith('Part'));
      expect(
        parsed.chapters.map((c) => c.htmlContent).join(),
        contains('Paragraph number 44'),
      );
    });
  });

  group('MarkdownConverter', () {
    test('splits chapters at H1 headings; title from first H1', () async {
      final f = await write(
          'md',
          '# My Book\nIntro paragraph.\n\n## Section A\nMore text.\n'
          '\n# Second\nLater text.');
      final parsed = await const MarkdownConverter().parse(f.path);

      expect(parsed.title, 'My Book');
      // Chunks split at H1 boundaries: [pre-first-H1? none] -> chunks are
      // ['# My Book ... ## Section A ...'] and ['# Second ...'].
      expect(parsed.chapters.length, 2);
      final allHtml = parsed.chapters.map((c) => c.htmlContent).join();
      expect(allHtml, contains('More text.'));
      expect(allHtml, contains('<h1>My Book</h1>'));
    });

    test('fenced code does not trigger chapter splits', () async {
      final f = await write(
          'md',
          '# Title\n```\n# not a heading\n```\nbody text');
      final parsed = await const MarkdownConverter().parse(f.path);
      expect(parsed.chapters, hasLength(1));
    });
  });

  group('HtmlConverter', () {
    test('title from <title>; h2 boundaries create chapters', () async {
      final f = await write(
          'html',
          '<html><head><title>Doc T</title></head><body>'
          '<p>intro</p><h2>S1</h2><p>a</p><h2>S2</h2><p>b</p></body></html>');
      final parsed = await const HtmlConverter().parse(f.path);

      expect(parsed.title, 'Doc T');
      expect(parsed.chapters.map((c) => c.title), ['Doc T', 'S1', 'S2']);
      final joined = parsed.chapters.map((c) => c.htmlContent).join();
      expect(joined, contains('intro'));
      expect(joined, contains('>b<'));
    });
  });

  group('Fb2Converter', () {
    const fb2 = '<?xml version="1.0" encoding="utf-8"?>'
        '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">'
        '<description><title-info>'
        '<book-title>FB Title</book-title>'
        '<author><first-name>Ann</first-name><last-name>Lee</last-name></author>'
        '</title-info></description>'
        '<body>'
        '<section><title><p>One</p></title><p>Hello <emphasis>world</emphasis>.</p></section>'
        '<section><title><p>Two</p></title><p><strong>Bold text</strong></p></section>'
        '</body></FictionBook>';

    test('sections become chapters with metadata', () async {
      final f = await write('fb2', fb2);
      final parsed = await const Fb2Converter().parse(f.path);

      expect(parsed.title, 'FB Title');
      expect(parsed.author, 'Ann Lee');
      expect(parsed.chapters.map((c) => c.title), ['One', 'Two']);
      final html = parsed.chapters.map((c) => c.htmlContent).join();
      expect(html, contains('<em>world</em>'));
      expect(html, contains('<strong>Bold text</strong>'));
    });
  });

  group('BookParser facade', () {
    test('routes txt through the txt converter', () async {
      final f = await write('txt', 'Hello facade.');
      final parsed = await bookParser.parseFile(f.path);
      expect(parsed.chapters.first.htmlContent, contains('Hello facade.'));
    });

    test('throws FormatException for unsupported extensions', () async {
      final f = await write('doc', 'not really a word doc');
      expect(() => bookParser.parseFile(f.path), throwsFormatException);
    });

    test('supportedExtensions covers every routed format', () {
      expect(BookParser.supportedExtensions,
          containsAll(['epub', 'txt', 'md', 'markdown', 'html', 'htm', 'fb2']));
      for (final ext in BookParser.supportedExtensions) {
        expect(BookParser.isSupported('book.$ext'), isTrue);
      }
      expect(BookParser.isSupported('book.doc'), isFalse);
    });
  });

  group('CoverGenerator', () {
    test('produces a non-empty PNG with correct dimensions', () async {
      final bytes = await CoverGenerator.generate(
          title: 'Int Reader', author: 'Peejay');
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));
      // PNG magic number.
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50); // 'P'
    });

    test('handles empty titles without crashing', () async {
      final bytes = await CoverGenerator.generate(title: '', author: '');
      expect(bytes, isNotEmpty);
    });
  });
}
