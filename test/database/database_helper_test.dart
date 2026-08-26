import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:epub_reader/database/database_helper.dart';
import 'package:epub_reader/models/book.dart';
import 'package:epub_reader/models/highlight.dart';
import 'package:epub_reader/models/bookmark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dbHelper = DatabaseHelper();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // The ffi database persists on disk between runs; start each test clean.
    final db = await dbHelper.database;
    await db.delete('book_categories');
    await db.delete('categories');
    await db.delete('highlights');
    await db.delete('bookmarks');
    await db.delete('daily_stats');
    await db.delete('books');
  });

  Book makeBook(String id, {String shelf = 'Uncategorized', double progress = 0.0}) {
    return Book(
      id: id,
      title: 'Title $id',
      author: 'Author $id',
      filePath: '/books/$id.epub',
      shelf: shelf,
      progress: progress,
      totalChapters: 5,
      addedAt: DateTime.now(),
    );
  }

  group('DatabaseHelper books', () {
    test('insert, get, update progress, delete', () async {
      const id = 'book-crud';
      await dbHelper.insertBook(makeBook(id));

      var fetched = await dbHelper.getBook(id);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Title $id');

      await dbHelper.updateProgress(id, 2, 1, 0.4);
      fetched = await dbHelper.getBook(id);
      expect(fetched!.currentChapter, 2);
      expect(fetched.currentPage, 1);
      expect(fetched.progress, 0.4);
      expect(fetched.lastReadAt, isNotNull);

      await dbHelper.deleteBook(id);
      expect(await dbHelper.getBook(id), isNull);
    });

    test('getBooks orders by most recently read', () async {
      await dbHelper.insertBook(makeBook('order-a'));
      await dbHelper.insertBook(makeBook('order-b'));

      await dbHelper.updateProgress('order-a', 0, 0, 0.1);
      // Give a distinct timestamp ordering.
      await Future.delayed(const Duration(milliseconds: 20));
      await dbHelper.updateProgress('order-b', 0, 0, 0.2);

      final books = await dbHelper.getBooks();
      expect(books.first.id, 'order-b');
    });
  });

  group('DatabaseHelper categories', () {
    test('insert, list, rename, delete, memberships replace', () async {
      const bookId = 'cat-book';
      await dbHelper.insertBook(makeBook(bookId));

      final fictionId = await dbHelper.insertCategory('Fiction');
      await dbHelper.insertCategory('Fantasy');

      var cats = await dbHelper.getCategories();
      expect(cats.map((c) => c.name), containsAll(['Fiction', 'Fantasy']));

      // Replace memberships with two categories.
      final fantasyId = (await dbHelper.getCategories())
          .firstWhere((c) => c.name == 'Fantasy')
          .id;
      await dbHelper.replaceBookCategories(bookId, [fictionId, fantasyId]);
      var members = await dbHelper.getMemberships();
      expect(members[bookId], containsAll([fictionId, fantasyId]));

      // Replacing again overwrites, not appends.
      await dbHelper.replaceBookCategories(bookId, [fictionId]);
      members = await dbHelper.getMemberships();
      expect(members[bookId], {fictionId});

      // Renaming keeps the id.
      await dbHelper.renameCategoryById(fictionId, 'Fiction & Literature');
      cats = await dbHelper.getCategories();
      expect(cats.where((c) => c.id == fictionId).single.name,
          'Fiction & Literature');

      // Starred flag defaults to 0 and round-trips.
      expect(cats.firstWhere((c) => c.id == fantasyId).starred, isFalse);
      await dbHelper.setCategoryStarred(fantasyId, true);
      cats = await dbHelper.getCategories();
      expect(cats.firstWhere((c) => c.id == fantasyId).starred, isTrue);

      // Deleting a category cascades its memberships.
      await dbHelper.deleteCategoryById(fictionId);
      members = await dbHelper.getMemberships();
      expect(members[bookId] ?? {}, isEmpty);

      // Deleting the book cascades too.
      await dbHelper.insertCategory('Temp');
      final temp = (await dbHelper.getCategories())
          .firstWhere((c) => c.name == 'Temp');
      await dbHelper.replaceBookCategories(bookId, [temp.id]);
      await dbHelper.deleteBook(bookId);
      members = await dbHelper.getMemberships();
      expect(members[bookId] ?? {}, isEmpty);

      // Cleanup
      for (final c in await dbHelper.getCategories()) {
        await dbHelper.deleteCategoryById(c.id);
      }
    });
  });

  group('DatabaseHelper highlights and bookmarks cascade on book delete', () {
    test('highlights CRUD', () async {
      const bookId = 'highlight-book';
      await dbHelper.insertBook(makeBook(bookId));

      await dbHelper.insertHighlight(Highlight(
        bookId: bookId,
        chapterIndex: 1,
        pageIndex: 0,
        text: 'A great line',
        createdAt: DateTime.now(),
      ));

      final highlights = await dbHelper.getHighlightsForBook(bookId);
      expect(highlights, hasLength(1));
      expect(highlights.first.text, 'A great line');
      final highlightId = highlights.first.id!;

      await dbHelper.deleteHighlight(highlightId);
      expect(await dbHelper.getHighlightsForBook(bookId), isEmpty);

      await dbHelper.deleteBook(bookId);
    });

    test('deleting a book cascades to its bookmarks', () async {
      const bookId = 'cascade-book';
      await dbHelper.insertBook(makeBook(bookId));
      await dbHelper.insertBookmark(Bookmark(
        bookId: bookId,
        chapterIndex: 2,
        pageIndex: 0,
        label: 'Chapter 3',
        createdAt: DateTime.now(),
      ));

      expect(await dbHelper.isBookmarked(bookId, 2, 0), isTrue);

      await dbHelper.deleteBook(bookId);
      expect(await dbHelper.getAllBookmarks(), isEmpty);
    });
  });
}
