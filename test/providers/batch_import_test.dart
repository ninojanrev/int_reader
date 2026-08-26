import 'package:flutter_test/flutter_test.dart';
import 'package:epub_reader/providers/library_provider.dart';
import 'package:epub_reader/models/book.dart';

Book makeBook(String title, String author) => Book(
      id: '$title-$author',
      title: title,
      author: author,
      filePath: '/books/x.epub',
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('LibraryState.isDuplicateBook', () {
    test('matches case-insensitively', () {
      final existing = makeBook('The Hobbit', 'J.R.R. Tolkien');
      expect(
        LibraryState.isDuplicateBook(existing, 'the hobbit', 'j.r.r. tolkien'),
        isTrue,
      );
    });

    test('ignores surrounding whitespace', () {
      final existing = makeBook('Dune', 'Frank Herbert');
      expect(LibraryState.isDuplicateBook(existing, '  Dune ', ' Frank Herbert '),
          isTrue);
    });

    test('different author is not a duplicate', () {
      final existing = makeBook('Dune', 'Frank Herbert');
      expect(LibraryState.isDuplicateBook(existing, 'Dune', 'Someone Else'),
          isFalse);
    });

    test('different title is not a duplicate', () {
      final existing = makeBook('Dune', 'Frank Herbert');
      expect(LibraryState.isDuplicateBook(existing, 'Dune Messiah',
          'Frank Herbert'), isFalse);
    });

    test('empty-ish strings still compare trimmed', () {
      final existing = makeBook('Untitled', 'Unknown Author');
      expect(
          LibraryState.isDuplicateBook(existing, 'untitled', 'unknown author'),
          isTrue);
    });
  });

  group('BatchImportResult', () {
    test('starts at zero and accumulates', () {
      final r = BatchImportResult();
      expect(r.added, 0);
      expect(r.updated, 0);
      expect(r.unchanged, 0);
      expect(r.failed, 0);
      r.added += 3;
      r.updated += 1;
      r.unchanged += 1;
      r.failed += 2;
      expect(r.added, 3);
      expect(r.toString(), contains('added=3'));
      expect(r.toString(), contains('updated=1'));
      expect(r.toString(), contains('unchanged=1'));
      expect(r.toString(), contains('failed=2'));
    });
  });
}
