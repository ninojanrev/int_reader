import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:epub_reader/services/epub_parser.dart';
import 'package:epub_reader/models/chapter.dart';

void main() {
  group('EpubParserService.inlineImages', () {
    const pngBytes = <int>[1, 2, 3, 4];
    const images = {
      'OEBPS/images/figure1.png': pngBytes,
      'OEBPS/media/photo.jpg': <int>[9, 9],
      'cover.jpg': <int>[7, 7, 7],
    };

    test('rewrites matching img src to a base64 data URI', () {
      const html = '<p><img src="../images/figure1.png" alt="f"/></p>';
      final result = EpubParserService.inlineImages(html, images);
      final expected =
          'data:image/png;base64,${base64Encode(pngBytes)}';
      expect(result, contains(expected));
      expect(result, isNot(contains('../images/figure1.png')));
    });

    test('resolves by basename regardless of directory prefix', () {
      const html = '<img src="Images/figure1.png"/>';
      expect(
        EpubParserService.inlineImages(html, images),
        contains('data:image/png;base64,'),
      );
    });

    test('leaves unknown and non-raster sources untouched', () {
      const html = '<img src="missing.png"/>'
          '<img src="vector.svg"/>'
          '<a href="OEBPS/media/photo.jpg">link</a>';
      final result = EpubParserService.inlineImages(html, images);
      expect(result, contains('src="missing.png"'));
      expect(result, contains('src="vector.svg"'));
      // href attributes are not rewritten.
      expect(result, isNot(contains('data:')));
    });

    test('returns input unchanged when no images exist', () {
      const html = '<p>plain</p>';
      expect(EpubParserService.inlineImages(html, const {}), html);
    });
  });

  group('ParsedEpub / ParsedChapter defaults', () {
    test('ParsedEpub has empty images map by default', () {
      const parsed = ParsedEpub(title: 'T', chapters: []);
      expect(parsed.images, isEmpty);
      expect(parsed.coverImageBytes, isNull);
      expect(parsed.author, isNull);
    });
  });
}


void debugFragments() {
  // ignore: avoid_print
  print('FRAGMENTS=');
}
