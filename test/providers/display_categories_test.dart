import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:epub_reader/database/database_helper.dart';
import 'package:epub_reader/models/book.dart';
import 'package:epub_reader/providers/library_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    final db = await DatabaseHelper().database;
    for (final table in [
      'book_categories', 'categories', 'highlights',
      'bookmarks', 'daily_stats', 'books',
    ]) {
      await db.delete(table);
    }
  });

  Book makeBook(String id, [DateTime? added]) => Book(
        id: id,
        title: 'Title $id',
        author: 'Author $id',
        filePath: '/books/$id.epub',
        totalChapters: 3,
        addedAt: added ?? DateTime(2026, 1, 1),
      );

  group('displayCategories starring rules', () {
    late LibraryState library;
    late int fictionId;

    setUp(() async {
      final dbHelper = DatabaseHelper();
      await dbHelper.insertBook(makeBook('b1'));
      await dbHelper.insertBook(makeBook('b2', DateTime(2026, 1, 2)));
      fictionId = await dbHelper.insertCategory('Fiction');
      await dbHelper.insertCategory('Fantasy');
      await dbHelper.replaceBookCategories('b1', [fictionId]);

      library = LibraryState();
      await library.loadBooks();
    });

    test('no stars -> all categories (uncategorized surfaces via Recently added)',
        () {
      // b1=Fiction, b2=no category. Uncategorized no longer appears as a
      // library section; it lives in browseCategories + Recently added.
      expect(library.displayCategories, ['Fantasy', 'Fiction']);
      expect(library.browseCategories,
          ['Fantasy', 'Fiction', 'Uncategorized']);
    });

    test('starring filters the library tab to starred only', () async {
      await library.toggleStar(fictionId);
      expect(
        library.categories.firstWhere((c) => c.id == fictionId).starred,
        isTrue,
      );
      expect(library.displayCategories, ['Fiction']);
    });

    test('recentlyAddedBooks returns newest-first across all books', () {
      final recent = library.recentlyAddedBooks;
      expect(recent, hasLength(2));
      // b2 was inserted after b1 -> newest first.
      expect(recent.first.id, 'b2');
      expect(recent.last.id, 'b1');
    });

    test('unstarring restores the full listing', () async {
      await library.toggleStar(fictionId);
      await library.toggleStar(fictionId);
      expect(library.displayCategories, ['Fantasy', 'Fiction']);
    });
  });
}

