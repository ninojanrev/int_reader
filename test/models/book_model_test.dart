import 'package:flutter_test/flutter_test.dart';
import 'package:epub_reader/models/book.dart';

void main() {
  final book = Book(
    id: 'test-id',
    title: 'Test Title',
    author: 'Test Author',
    filePath: '/books/test-id.epub',
    coverImagePath: '/books/test-id/cover.jpg',
    shelf: 'Fiction',
    progress: 0.5,
    currentChapter: 3,
    currentPage: 2,
    totalChapters: 10,
    addedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    lastReadAt: DateTime.fromMillisecondsSinceEpoch(1700000050000),
  );

  group('Book', () {
    test('toMap/fromMap round-trips all fields', () {
      final restored = Book.fromMap(book.toMap());
      expect(restored.id, book.id);
      expect(restored.title, book.title);
      expect(restored.author, book.author);
      expect(restored.filePath, book.filePath);
      expect(restored.coverImagePath, book.coverImagePath);
      expect(restored.shelf, book.shelf);
      expect(restored.progress, book.progress);
      expect(restored.currentChapter, book.currentChapter);
      expect(restored.currentPage, book.currentPage);
      expect(restored.totalChapters, book.totalChapters);
      expect(restored.addedAt, book.addedAt);
      expect(restored.lastReadAt, book.lastReadAt);
    });

    test('fromMap applies defaults for nullable columns', () {
      final map = book.toMap()
        ..remove('cover_image_path')
        ..remove('shelf')
        ..remove('progress')
        ..remove('current_chapter')
        ..remove('current_page')
        ..remove('total_chapters')
        ..remove('last_read_at');
      final restored = Book.fromMap(map);
      expect(restored.coverImagePath, isNull);
      expect(restored.shelf, 'Uncategorized');
      expect(restored.progress, 0.0);
      expect(restored.currentChapter, 0);
      expect(restored.currentPage, 0);
      expect(restored.totalChapters, 0);
      expect(restored.lastReadAt, isNull);
    });

    test('copyWith overrides only the given fields', () {
      final updated = book.copyWith(shelf: 'Sci-Fi', progress: 1.0);
      expect(updated.shelf, 'Sci-Fi');
      expect(updated.progress, 1.0);
      expect(updated.id, book.id);
      expect(updated.title, book.title);
    });

    test('isInProgress reflects progress range', () {
      final now = DateTime.now();
      Book withProgress(double p) => Book(
        id: 'a', title: 't', author: 'a', filePath: '/f',
        progress: p, addedAt: now,
      );
      expect(withProgress(0).isInProgress, isFalse);
      expect(withProgress(0.5).isInProgress, isTrue);
      expect(withProgress(1.0).isInProgress, isFalse);
    });
  });
}
