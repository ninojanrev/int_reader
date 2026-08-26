import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:epub_reader/services/epub_parser.dart';

const shapes = <String, String>{
  'full xhtml with prolog':
      '<?xml version="1.0" encoding="utf-8"?>'
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">'
      '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>T</title></head>'
      '<body><h1>Chapter One</h1><p>Hello world paragraph.</p>'
      '<div><p>Nested in div.</p></div></body></html>',
  'html without prolog':
      '<html><head><title>T</title></head><body><p>Hello world paragraph.</p></body></html>',
  'body only':
      '<body><p>Hello world paragraph.</p><p>Second para.</p></body>',
  'bare paragraphs': '<p>Hello world paragraph.</p><p>Second para.</p>',
  'with comments and cdata':
      '<body><!-- a comment with <p>fake tags</p> inside -->'
      '<p>Hello <![CDATA[world]]> paragraph.</p></body>',
};

void main() {
  shapes.forEach((name, html) {
    testWidgets('renders text: $name', (tester) async {
      final frags = EpubParserService.chapterFragments(html);
      expect(frags, isNotEmpty, reason: 'no fragments for "$name"');
      final joined = frags.join();
      expect(joined.contains('Hello world'), isTrue,
          reason: 'text lost for "$name": $frags');

      for (var i = 0; i < frags.length; i++) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SizedBox(width: 300, child: Html(data: frags[i]))),
        ));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull,
          reason: 'render exception for "$name"');
    });
  });

  test('long chapters split into multiple fragments', () {
    final manyParas = List.generate(
        60, (i) => '<p>Paragraph number $i with some extra words.</p>').join();
    final frags =
        EpubParserService.chapterFragments('<body>$manyParas</body>');
    expect(frags.length, greaterThan(1));
    expect(frags.join().contains('Paragraph number 59'), isTrue);
  });

  test('giant single paragraph is split at sentence boundaries', () {
    final longText =
        List.generate(120, (i) => 'Sentence number $i explains something.')
            .join(' ');
    final html = '<body><p>$longText</p></body>';
    final frags = EpubParserService.chapterFragments(html);

    expect(frags.length, greaterThan(1),
        reason: 'one huge <p> must become multiple fragments');
    // Every fragment stays small enough to fit comfortably on a page.
    for (final f in frags) {
      expect(f.length, lessThan(700), reason: 'fragment too long: $f');
    }
    // No text lost.
    final joined = frags.join();
    for (var i = 0; i < 120; i++) {
      expect(joined.contains('Sentence number $i'), isTrue);
    }
  });

  test('dialogue: fragments never end inside an open quote', () {
    // 60 dialogue sentences — naive splitting would sever quote pairs.
    final dialogue = List.generate(30, (i) {
      final inner = i.isEven
          ? 'Why not number $i?'
          : 'Because $i, that is simply how it is.';
      return '"$inner" he said.';
    }).join(' ');
    final frags =
        EpubParserService.chapterFragments('<body><p>$dialogue</p></body>');

    expect(frags.length, greaterThan(1));
    for (final frag in frags) {
      expect(EpubParserService.endsInsideOpenQuote(frag), isFalse,
          reason: 'fragment ends inside an open quote: $frag');
    }
    // No text lost.
    expect(frags.join().contains('Because 29'), isTrue);
  });

  test('unbalanced quote cannot produce an unbounded fragment', () {
    // One stray open quote with lots of sentences after it.
    final text = '"Oops. ${List.generate(80, (i) => 'Sentence $i keeps going on and on.').join(' ')}';    final frags =
        EpubParserService.chapterFragments('<body><p>$text</p></body>');
    expect(frags.length, greaterThan(1),
        reason: 'safety valve must force splits');
  });

  test('vertical scrolling blocks are natural top-level elements', () {
    const html = '<body>'
        '<h1>Title</h1>'
        '<p>First paragraph.</p>'
        '<div><p>Second inside div.</p><p>Third also inside.</p></div>'
        '</body>';
    final blocks = EpubParserService.chapterBlocksForScrolling(html);
    // Natural boundaries: h1, p, div (no sentence-level or merge passes).
    expect(blocks.length, 3);
    expect(blocks.join(), contains('First paragraph.'));
    expect(blocks.join(), contains('Third also inside.'));
  });

  test('unparseable input still yields the full chapter as fallback', () {
    const weird = 'plain text without any tags';
    final frags = EpubParserService.chapterFragments(weird);
    expect(frags, hasLength(1));
    expect(frags.first.contains('plain text'), isTrue);
  });
}
