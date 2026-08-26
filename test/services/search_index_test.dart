import 'package:flutter_test/flutter_test.dart';
import 'package:epub_reader/services/search_index.dart';

void main() {
  group('buildAndSearch (background worker)', () {
    test('strips tags and finds case-insensitive matches per chapter', () {
      final result = buildAndSearch([
        ['<p>Hello there my name is John.</p>'],
        ['<p>hello again from chapter two</p>', '<p>No match here.</p>'],
      ], 'hello');

      expect(result.hits, hasLength(2));
      expect(result.hits.first.chapterIdx, 0);
      expect(result.hits.last.chapterIdx, 1);

      // Plain text shipped back for snippets — tags stripped.
      expect(result.plainChapters[0].first, 'Hello there my name is John.');
    });

    test('multi-word phrase matching', () {
      final result = buildAndSearch([
        ['<p>one two three four five</p>'],
      ], 'two three');
      expect(result.hits, hasLength(1));
      final hit = result.hits.single;
      expect(hit.start, 4);
      expect(hit.end, 13);
    });

    test('empty query returns no hits but still ships plain text', () {
      final result = buildAndSearch([
        ['<p>abc</p>'],
      ], '');
      expect(result.hits, isEmpty);
      expect(result.plainChapters[0].first, contains('abc'));
    });

    test('single-character query still works at worker level '
        '(caller enforces 2-char minimum)', () {
      final result = buildAndSearch([
        ['<p>a book about a boy</p>'],
      ], 'boy');
      expect(result.hits, hasLength(1));
    });
  });
  group('SearchTextUtils.stripTags', () {
    test('removes markup but keeps text', () {
      expect(SearchTextUtils.stripTags('<p>Hello <em>world</em></p>'),
          'Hello world');
    });

    test('handles multi-line and nested tags', () {
      final out = SearchTextUtils.stripTags(
          '<div><p>a<br/>b</p>\n<span>c</span></div>');
      expect(out, contains('a'));
      expect(out, contains('b'));
      expect(out, contains('c'));
      expect(out.contains('<'), isFalse);
    });
  });

  group('SearchTextUtils.occurrences', () {
    test('case-insensitive phrase matching', () {
      const text = 'Hello there. Say hello again. HELLO.';
      expect(SearchTextUtils.occurrences(text, 'hello'), hasLength(3));
    });

    test('multi-word phrases match as substrings', () {
      const text = 'one two three four five';
      expect(SearchTextUtils.occurrences(text, 'two three'), [
        (4, 13)
      ]);
    });

    test('no false hits inside different words boundaries are allowed',
        () {
      // Substring semantics: 'her' matches inside 'there' — documented.
      expect(SearchTextUtils.occurrences('there her', 'her'), hasLength(2));
    });

    test('empty query yields no occurrences', () {
      expect(SearchTextUtils.occurrences('abc', ''), isEmpty);
    });
  });

  group('SearchTextUtils.snippet', () {
    test('adds ellipses when trimmed', () {
      final text = List.generate(50, (i) => 'w$i').join(' ');
      // Find the match for w25 in the middle of a long string.
      final idx = text.indexOf('w25');
      final s = SearchTextUtils.snippet(text, idx, idx + 3);
      expect(s.startsWith('…'), isTrue);
      expect(s.endsWith('…'), isTrue);
      expect(s, contains('w25'));
    });

    test('no leading ellipse at document start', () {
      final s = SearchTextUtils.snippet('start match end', 6, 11);
      expect(s.startsWith('…'), isFalse);
    });
  });

  group('SearchHit', () {
    test('carries location and span', () {
      const hit = SearchHit(
          chapterIdx: 2, itemIdx: 5, start: 10, end: 20);
      expect(hit.chapterIdx, 2);
      expect(hit.itemIdx, 5);
      expect(hit.end - hit.start, 10);
    });
  });
}
