import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book.dart';
import '../models/book_category.dart';
import '../models/highlight.dart';
import '../models/bookmark.dart';

/// One row per day the user read, holding accumulated reading minutes.
class DailyReadingStat {
  final DateTime date;
  final double minutes;
  const DailyReadingStat({required this.date, required this.minutes});
}

/// Centralized SQLite database for the EPUB reader.
class DatabaseHelper {
  static Database? _database;
  static Future<Database>? _pendingInit;
  static const _dbName = 'epub_reader.db';
  static const _dbVersion = 6;

  /// Get the singleton database instance.
  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_pendingInit != null) return _pendingInit!;
    _pendingInit = _initDatabase();
    _database = await _pendingInit!;
    _pendingInit = null;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        file_path TEXT NOT NULL,
        cover_image_path TEXT,
        shelf TEXT DEFAULT 'Uncategorized',
        progress REAL DEFAULT 0.0,
        current_chapter INTEGER DEFAULT 0,
        current_page INTEGER DEFAULT 0,
        total_chapters INTEGER DEFAULT 0,
        added_at INTEGER NOT NULL,
        last_read_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE highlights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        page_index INTEGER NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        page_index INTEGER NOT NULL,
        label TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    await _createDailyStatsTable(db);
    await _createCategoryTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createDailyStatsTable(db);
    }
    if (oldVersion < 3) {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE COLLATE NOCASE,
            starred INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS book_categories (
            book_id TEXT NOT NULL,
            category_id INTEGER NOT NULL,
            PRIMARY KEY (book_id, category_id),
            FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
            FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
          )
        ''');
        // Migrate legacy single-shelf values into real categories.
        final rows = await txn.query('books', columns: ['id', 'shelf']);
        final catIds = <String, int>{};
        for (final row in rows) {
          final shelf = (row['shelf'] as String?)?.trim() ?? '';
          if (shelf.isEmpty || shelf == 'Uncategorized') continue;
          var id = catIds[shelf];
          if (id == null) {
            id = await txn.insert('categories', {'name': shelf});
            catIds[shelf] = id;
          }
          await txn.insert(
            'book_categories',
            {'book_id': row['id'] as String, 'category_id': id},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });
    }
    if (oldVersion < 4) {
      // Starred/favorite flag for the library-tab filter.
      await db.execute(
          'ALTER TABLE categories ADD COLUMN starred INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 5) {
      // Scroll offset within a chapter for scrolling-mode position restore.
      await db.execute(
          'ALTER TABLE books ADD COLUMN scroll_offset REAL NOT NULL DEFAULT 0.0');
    }
    if (oldVersion < 6) {
      // Fragment-level anchor for more precise scroll restoration.
      await db.execute(
          'ALTER TABLE books ADD COLUMN scroll_fragment INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<void> _createDailyStatsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_stats (
        date TEXT PRIMARY KEY,
        minutes REAL NOT NULL DEFAULT 0.0
      )
    ''');
  }

  Future<void> _createCategoryTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        starred INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS book_categories (
        book_id TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        PRIMARY KEY (book_id, category_id),
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');
  }

  // ========== BOOKS ==========

  /// Insert a new book.
  Future<void> insertBook(Book book) async {
    final db = await database;
    await db.insert('books', book.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get all books, ordered by most recently read.
  Future<List<Book>> getBooks() async {
    final db = await database;
    final maps = await db.query('books', orderBy: 'last_read_at DESC');
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  /// Get a single book by ID.
  Future<Book?> getBook(String id) async {
    final db = await database;
    final maps = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  /// Update reading progress for a book.
  Future<void> updateProgress(String bookId, int chapter, int page, double progress, {double scrollOffset = 0.0, int scrollFragment = 0}) async {
    final db = await database;
    await db.update(
      'books',
      {
        'current_chapter': chapter,
        'current_page': page,
        'progress': progress,
        'scroll_offset': scrollOffset,
        'scroll_fragment': scrollFragment,
        'last_read_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  /// Update content-related metadata after a replace-on-import.
  Future<void> updateBookContentMeta(
    String bookId, {
    required int totalChapters,
    String? coverImagePath,
  }) async {
    final db = await database;
    await db.update(
      'books',
      {
        'total_chapters': totalChapters,
        'cover_image_path': coverImagePath,
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  // ========== CATEGORIES (multi-category) ==========

  /// All user-defined categories, sorted by name.
  Future<List<BookCategory>> getCategories() async {
    final db = await database;
    final maps =
        await db.query('categories', orderBy: 'name COLLATE NOCASE ASC');
    return maps.map(BookCategory.fromMap).toList();
  }

  /// Insert a category; returns its id. Throws on duplicate name.
  Future<int> insertCategory(String name) async {
    final db = await database;
    return db.insert('categories', {'name': name});
  }

  Future<void> renameCategoryById(int id, String newName) async {
    final db = await database;
    await db
        .update('categories', {'name': newName}, where: 'id = ?', whereArgs: [id]);
  }

  /// Toggle the starred (favorite) flag shown in the library tab filter.
  Future<void> setCategoryStarred(int id, bool starred) async {
    final db = await database;
    await db.update('categories', {'starred': starred ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Deleting a category cascades to its book memberships.
  Future<void> deleteCategoryById(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  /// Map of bookId -> set of category ids.
  Future<Map<String, Set<int>>> getMemberships() async {
    final db = await database;
    final maps = await db.query('book_categories');
    final result = <String, Set<int>>{};
    for (final m in maps) {
      result
          .putIfAbsent(m['book_id'] as String, () => {})
          .add(m['category_id'] as int);
    }
    return result;
  }

  /// Replace a book's category memberships atomically.
  Future<void> replaceBookCategories(
      String bookId, Iterable<int> categoryIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('book_categories',
          where: 'book_id = ?', whereArgs: [bookId]);
      for (final id in categoryIds) {
        await txn.insert(
          'book_categories',
          {'book_id': bookId, 'category_id': id},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  /// Delete a book and its highlights/bookmarks (cascade).
  Future<void> deleteBook(String bookId) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
  }

  // ========== HIGHLIGHTS ==========

  /// Insert a highlight.
  Future<void> insertHighlight(Highlight highlight) async {
    final db = await database;
    await db.insert('highlights', highlight.toMap());
  }

  /// Get all highlights for a book.
  Future<List<Highlight>> getHighlightsForBook(String bookId) async {
    final db = await database;
    final maps = await db.query(
      'highlights',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Highlight.fromMap(map)).toList();
  }

  /// Get all highlights across all books.
  Future<List<Highlight>> getAllHighlights() async {
    final db = await database;
    final maps = await db.query('highlights', orderBy: 'created_at DESC');
    return maps.map((map) => Highlight.fromMap(map)).toList();
  }

  /// Delete a highlight.
  Future<void> deleteHighlight(int id) async {
    final db = await database;
    await db.delete('highlights', where: 'id = ?', whereArgs: [id]);
  }

  // ========== BOOKMARKS ==========

  /// Insert a bookmark.
  Future<void> insertBookmark(Bookmark bookmark) async {
    final db = await database;
    await db.insert('bookmarks', bookmark.toMap());
  }

  /// Get all bookmarks for a book.
  Future<List<Bookmark>> getBookmarksForBook(String bookId) async {
    final db = await database;
    final maps = await db.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Bookmark.fromMap(map)).toList();
  }

  /// Get all bookmarks across all books.
  Future<List<Bookmark>> getAllBookmarks() async {
    final db = await database;
    final maps = await db.query('bookmarks', orderBy: 'created_at DESC');
    return maps.map((map) => Bookmark.fromMap(map)).toList();
  }

  /// Delete a bookmark.
  Future<void> deleteBookmark(int id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  /// Check if a position is bookmarked.
  Future<bool> isBookmarked(String bookId, int chapterIndex, int pageIndex) async {
    final db = await database;
    final maps = await db.query(
      'bookmarks',
      where: 'book_id = ? AND chapter_index = ? AND page_index = ?',
      whereArgs: [bookId, chapterIndex, pageIndex],
    );
    return maps.isNotEmpty;
  }

  // ========== READING STATS ==========

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Accumulate [minutes] of reading on the given day (upsert).
  Future<void> addReadingTime(DateTime day, double minutes) async {
    if (minutes <= 0) return;
    final db = await database;
    final key = _dateKey(day);
    await db.execute('''
      INSERT INTO daily_stats (date, minutes) VALUES (?, ?)
      ON CONFLICT(date) DO UPDATE SET minutes = minutes + excluded.minutes
    ''', [key, minutes]);
  }

  /// All reading stats ordered by date ascending.
  Future<List<DailyReadingStat>> getAllReadingStats() async {
    final db = await database;
    final maps = await db.query('daily_stats', orderBy: 'date ASC');
    return maps.map((m) => DailyReadingStat(
      date: DateTime.parse(m['date'] as String),
      minutes: (m['minutes'] as num).toDouble(),
    )).toList();
  }

  /// Total accumulated reading time in minutes.
  Future<double> getTotalReadingMinutes() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COALESCE(SUM(minutes), 0.0) AS total FROM daily_stats');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}

/// Global singleton instance.
final dbHelper = DatabaseHelper();
