import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../models/book_category.dart';
import '../models/highlight.dart';
import '../models/bookmark.dart';
import '../database/database_helper.dart';
import '../services/book_parser.dart';
import '../services/file_service.dart';
import '../services/settings_service.dart';

/// Outcome of a batch folder import.
class BatchImportResult {
  int added = 0;
  int updated = 0; // replaced an existing book with a newer/larger file
  int unchanged = 0; // duplicate kept as-is (skipped or user chose keep)
  int failed = 0;

  @override
  String toString() =>
      'added=$added updated=$updated unchanged=$unchanged failed=$failed';
}

/// What to do when an imported file matches an existing book.
enum ImportConflictAction { replaceExisting, keepExisting }

/// Central state for the user's book library.
/// All screens read from this provider.
///
/// Categories are many-to-many: a book can belong to any number of
/// categories (backed by the categories + book_categories tables).
/// "Uncategorized" is virtual: it means a book has no category rows.
class LibraryState extends ChangeNotifier {
  List<Book> _books = [];
  bool _isLoading = false;
  String? _error;

  List<BookCategory> _categories = [];
  Map<String, Set<int>> _memberships = {};

  /// Bumped whenever highlights/bookmarks change so listeners (the Saved
  /// tab) know to re-query the database.
  int _savedVersion = 0;
  int get savedVersion => _savedVersion;

  // Getters
  List<Book> get books => List.unmodifiable(_books);
  List<BookCategory> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _books.isEmpty;

  // Computed getters
  /// Books opened at least once but not finished. Using lastReadAt (rather
  /// than progress>0) means single-chapter books — whose computed progress
  /// is always 0 — still count as in-progress once opened.
  List<Book> get inProgressBooks =>
      _books.where((b) => b.lastReadAt != null && b.progress < 1).toList();

  List<Book> get finishedBooks =>
      _books.where((b) => b.progress >= 1.0).toList();

  List<Book> get notStartedBooks =>
      _books.where((b) => b.progress == 0).toList();

  /// Real (stored) category names, sorted.
  List<String> get allCategories =>
      _categories.map((c) => c.name).toList();

  /// True when at least one book has no category.
  bool get _anyUncategorizedBooks =>
      _memberships.values.any((ids) => ids.isEmpty) ||
      _books.any((b) => (_memberships[b.id] ?? const <int>{}).isEmpty);

  /// Every stored category name plus the virtual Uncategorized bucket when
  /// non-empty. Used by full-browsing surfaces ("View all" screen) so
  /// uncategorized books stay reachable there.
  List<String> get browseCategories =>
      [...allCategories, ...(_anyUncategorizedBooks ? ['Uncategorized'] : <String>[])];

  /// Category names shown as library-tab sections:
  /// - Nothing starred -> every category
  /// - Anything starred -> ONLY starred categories
  /// (Uncategorized books surface via the "Recently added" section and
  /// remain reachable through View all / search / the category editor.)
  List<String> get displayCategories {
    final starred = _categories.where((c) => c.starred).map((c) => c.name).toList();
    if (starred.isEmpty) return allCategories;
    return starred;
  }

  /// Most recently imported books, newest first (for the "Recently added"
  /// library strip).
  List<Book> get recentlyAddedBooks {
    final sorted = [..._books]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return sorted;
  }

  /// Flip the starred flag on a category and persist it.
  Future<void> toggleStar(int categoryId) async {
    final idx = _categories.indexWhere((c) => c.id == categoryId);
    if (idx == -1) return;
    final newStarred = !_categories[idx].starred;
    try {
      await dbHelper.setCategoryStarred(categoryId, newStarred);
      _categories[idx] =
          _categories[idx].copyWith(starred: newStarred);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update category: $e';
      notifyListeners();
    }
  }

  // ================= Loading =================

  /// Load all data from the database and custom prefs.
  Future<void> loadBooks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        dbHelper.getBooks(),
        dbHelper.getCategories(),
        dbHelper.getMemberships(),
      ]);
      _books = results[0] as List<Book>;
      _categories = results[1] as List<BookCategory>;
      _memberships = results[2] as Map<String, Set<int>>;
      await migrateLegacyPrefsCategories();
    } catch (e) {
      _error = 'Failed to load books: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ================= Categories =================

  Set<int> _categoryIdsForBook(String bookId) =>
      _memberships[bookId] ?? const <int>{};

  /// Names of the categories a book belongs to.
  List<String> categoriesOfBook(String bookId) {
    final ids = _categoryIdsForBook(bookId);
    return _categories
        .where((c) => ids.contains(c.id))
        .map((c) => c.name)
        .toList();
  }

  BookCategory? _categoryByName(String name) {
    for (final c in _categories) {
      if (c.name.toLowerCase() == name.toLowerCase()) return c;
    }
    return null;
  }

  /// Create a category; returns false if it already exists.
  Future<bool> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        trimmed.toLowerCase() == 'uncategorized' ||
        _categoryByName(trimmed) != null) {
      return false;
    }
    try {
      final id = await dbHelper.insertCategory(trimmed);
      _categories = [..._categories, BookCategory(id: id, name: trimmed)]
        ..sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add category: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> renameCategory(String oldName, String newName) async {
    final cat = _categoryByName(oldName);
    final trimmed = newName.trim();
    if (cat == null ||
        trimmed.isEmpty ||
        trimmed == oldName ||
        trimmed.toLowerCase() == 'uncategorized' ||
        _categoryByName(trimmed) != null) {
      return;
    }
    try {
      await dbHelper.renameCategoryById(cat.id, trimmed);
      _categories = _categories
          .map((c) => c.id == cat.id ? BookCategory(id: c.id, name: trimmed) : c)
          .toList()
        ..sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
    } catch (e) {
      _error = 'Failed to rename category: $e';
      notifyListeners();
    }
  }

  /// Delete a category. Memberships cascade in the database.
  Future<void> deleteCategory(String name) async {
    final cat = _categoryByName(name);
    if (cat == null) return;
    try {
      await dbHelper.deleteCategoryById(cat.id);
      _categories = _categories.where((c) => c.id != cat.id).toList();
      _memberships = _memberships.map((bookId, ids) {
        final next = {...ids}..remove(cat.id);
        return MapEntry(bookId, next);
      });
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete category: $e';
      notifyListeners();
    }
  }

  /// Replace a book's category memberships with exactly [names].
  Future<void> setBookCategories(String bookId, Iterable<String> names) async {
    final ids = <int>{
      for (final name in names)
        if (_categoryByName(name) case final BookCategory c) c.id,
    };
    try {
      await dbHelper.replaceBookCategories(bookId, ids);
      setStateFor(bookId, ids);
    } catch (e) {
      _error = 'Failed to update categories: $e';
      notifyListeners();
    }
  }

  /// Add one more category to a book's memberships (keeps existing ones).
  Future<void> addBookToCategory(String bookId, String name) async {
    final cat = _categoryByName(name);
    if (cat == null) return;
    final current = {..._categoryIdsForBook(bookId)}..add(cat.id);
    await setBookCategories(
        bookId,
        _categories
            .where((c) => current.contains(c.id))
            .map((c) => c.name));
  }

  void setStateFor(String bookId, Set<int> ids) {
    _memberships = {..._memberships, bookId: ids};
    notifyListeners();
  }

  // ================= Books =================

  /// Outcome labels for single-file imports (used by the UI message).
  static const importOutcomeAdded = 'added';
  static const importOutcomeUpdated = 'updated';
  static const importOutcomeKept = 'kept';
  static const importOutcomeFailed = 'failed';

  /// Import an EPUB file from the given path.
  ///
  /// When [resolveConflict] is provided and the file matches an existing
  /// book, it decides replace-vs-keep (same semantics as batch imports).
  /// Returns one of the `importOutcome*` constants.
  Future<String> importBook(
    String filePath, {
    Future<ImportConflictAction> Function(Book existing, int newFileSize)?
        resolveConflict,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final parsed = await bookParser.parseFile(filePath);
      final title = parsed.title.trim().isEmpty ? 'Untitled' : parsed.title;
      final author = (parsed.author ?? 'Unknown Author').trim().isEmpty
          ? 'Unknown Author'
          : parsed.author!.trim();

      if (resolveConflict != null) {
        final existing = _findDuplicate(title, author);
        if (existing != null) {
          int newSize = 0;
          try {
            newSize = File(filePath).lengthSync();
          } catch (_) {}
          final action = await resolveConflict(existing, newSize);
          if (action == ImportConflictAction.replaceExisting) {
            final updated = await fileService.replaceEpubFile(
              existing: existing,
              newSourcePath: filePath,
              parsed: parsed,
            );
            final idx = _books.indexWhere((b) => b.id == existing.id);
            if (idx != -1) _books[idx] = updated;
            notifyListeners();
            return importOutcomeUpdated;
          }
          notifyListeners();
          return importOutcomeKept;
        }
      }

      final book = await fileService.importEpub(filePath, preParsed: parsed);
      if (book != null) {
        _books.insert(0, book);
        notifyListeners();
        return importOutcomeAdded;
      }
      return importOutcomeFailed;
    } catch (e) {
      _error = 'Failed to import book: $e';
      notifyListeners();
      return importOutcomeFailed;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Case-insensitive title+author duplicate check used by batch imports.
  static bool isDuplicateBook(Book existing, String title, String author) {
    String norm(String s) => s.trim().toLowerCase();
    return norm(existing.title) == norm(title) &&
        norm(existing.author) == norm(author);
  }

  Book? _findDuplicate(String title, String author) {
    for (final b in _books) {
      if (isDuplicateBook(b, title, author)) return b;
    }
    return null;
  }

  /// Import multiple EPUBs sequentially (batch folder import).
  ///
  /// When a file matches an existing book (title+author), [resolveConflict]
  /// decides whether to replace it (in-place update preserving progress,
  /// categories, highlights, bookmarks) or keep the existing one.
  /// When [addToCategory] is set, every added or replaced book also joins
  /// that category (union — existing memberships are preserved).
  /// One broken file never aborts the batch.
  /// [onProgress] fires after each file with (done, total).
  Future<BatchImportResult> importBooks(
    List<String> filePaths, {
    void Function(int done, int total)? onProgress,
    required Future<ImportConflictAction> Function(Book existing, int newFileSize)
        resolveConflict,
    String? addToCategory,
  }) async {
    final result = BatchImportResult();
    if (filePaths.isEmpty) return result;

    if (addToCategory != null && addToCategory.trim().isNotEmpty) {
      await addCategory(addToCategory);
    }

    Future<void> fileToCategory(String bookId) async {
      final cat = addToCategory?.trim();
      if (cat == null || cat.isEmpty) return;
      await addBookToCategory(bookId, cat);
    }

    _isLoading = true;
    notifyListeners();

    try {
      var done = 0;
      for (final path in filePaths) {
        done++;
        try {
          // Parse first so we can check duplicates before touching the DB.
          final parsed = await bookParser.parseFile(path);
          final title = parsed.title.trim().isEmpty ? 'Untitled' : parsed.title;
          final author =
              (parsed.author ?? 'Unknown Author').trim().isEmpty
                  ? 'Unknown Author'
                  : parsed.author!.trim();

          final existing = _findDuplicate(title, author);
          if (existing != null) {
            int newSize = 0;
            try {
              newSize = File(path).lengthSync();
            } catch (_) {}
            final action = await resolveConflict(existing, newSize);
            if (action == ImportConflictAction.replaceExisting) {
              try {
                final updated = await fileService.replaceEpubFile(
                  existing: existing,
                  newSourcePath: path,
                  parsed: parsed,
                );
                final idx = _books.indexWhere((b) => b.id == existing.id);
                if (idx != -1) _books[idx] = updated;
                result.updated++;
                await fileToCategory(updated.id);
              } catch (_) {
                result.failed++;
              }
            } else {
              result.unchanged++;
            }
            onProgress?.call(done, filePaths.length);
            continue;
          }

          final book =
              await fileService.importEpub(path, preParsed: parsed);
          if (book != null) {
            _books.insert(0, book);
            result.added++;
            await fileToCategory(book.id);
          } else {
            result.failed++;
          }
        } catch (e) {
          result.failed++;
        }
        onProgress?.call(done, filePaths.length);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return result;
  }

  /// Remove a book and its files (memberships cascade).
  Future<void> removeBook(String bookId) async {
    try {
      await dbHelper.deleteBook(bookId);
      await fileService.deleteBookFiles(bookId);
      _books.removeWhere((b) => b.id == bookId);
      final next = {..._memberships}..remove(bookId);
      _memberships = next;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove book: $e';
      notifyListeners();
    }
  }

  /// Restore a previously removed book (for undo).
  Future<void> restoreBook(Book book) async {
    try {
      await dbHelper.insertBook(book);
      _books.insert(0, book);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to restore book: $e';
      notifyListeners();
    }
  }

  /// Update reading progress for a book.
  Future<void> updateProgress(String bookId, int chapter, int page, double progress) async {
    try {
      await dbHelper.updateProgress(bookId, chapter, page, progress);
      final index = _books.indexWhere((b) => b.id == bookId);
      if (index != -1) {
        _books[index] = _books[index].copyWith(
          currentChapter: chapter,
          currentPage: page,
          progress: progress,
          lastReadAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update progress: $e';
      notifyListeners();
    }
  }

  /// Get books for a specific category name ('All' and 'Uncategorized'
  /// are supported virtual buckets).
  List<Book> booksForCategory(String category) {
    if (category == 'All') return _books;
    if (category == 'Uncategorized') {
      return _books
          .where((b) => _categoryIdsForBook(b.id).isEmpty)
          .toList();
    }
    final cat = _categoryByName(category);
    if (cat == null) return [];
    return _books
        .where((b) => _categoryIdsForBook(b.id).contains(cat.id))
        .toList();
  }

  /// Number of books in a category (for list subtitles).
  int countForCategory(String category) => booksForCategory(category).length;

  // ================= Sorting =================

  /// Sort according to the persisted Settings > Default sort order.
  List<Book> sortBooks(List<Book> input) {
    final copy = [...input];
    switch (settings.sortOrder) {
      case 'Title':
        copy.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'Author':
        copy.sort((a, b) =>
            a.author.toLowerCase().compareTo(b.author.toLowerCase()));
        break;
      case 'Reading progress':
        copy.sort((a, b) => b.progress.compareTo(a.progress));
        break;
      default: // 'Recently added'
        copy.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }
    return copy;
  }

  /// Search books by title or author.
  List<Book> searchBooks(String query) {
    if (query.isEmpty) return _books;
    final q = query.toLowerCase();
    return _books.where((b) =>
        b.title.toLowerCase().contains(q) ||
        b.author.toLowerCase().contains(q)).toList();
  }

  // ================= Highlights =================

  /// Get highlights for a book.
  Future<List<Highlight>> getHighlightsForBook(String bookId) async {
    return await dbHelper.getHighlightsForBook(bookId);
  }

  /// Get all highlights.
  Future<List<Highlight>> getAllHighlights() async {
    return await dbHelper.getAllHighlights();
  }

  /// Add a highlight.
  Future<void> addHighlight(Highlight highlight) async {
    await dbHelper.insertHighlight(highlight);
    _savedVersion++;
    notifyListeners();
  }

  /// Delete a highlight.
  Future<void> deleteHighlight(int id) async {
    await dbHelper.deleteHighlight(id);
    _savedVersion++;
    notifyListeners();
  }

  // ================= Bookmarks =================

  /// Get bookmarks for a book.
  Future<List<Bookmark>> getBookmarksForBook(String bookId) async {
    return await dbHelper.getBookmarksForBook(bookId);
  }

  /// Get all bookmarks.
  Future<List<Bookmark>> getAllBookmarks() async {
    return await dbHelper.getAllBookmarks();
  }

  /// Add a bookmark.
  Future<void> addBookmark(Bookmark bookmark) async {
    await dbHelper.insertBookmark(bookmark);
    _savedVersion++;
    notifyListeners();
  }

  /// Delete a bookmark.
  Future<void> deleteBookmark(int id) async {
    await dbHelper.deleteBookmark(id);
    _savedVersion++;
    notifyListeners();
  }

  /// Check if a position is bookmarked.
  Future<bool> isBookmarked(String bookId, int chapterIndex, int pageIndex) async {
    return await dbHelper.isBookmarked(bookId, chapterIndex, pageIndex);
  }

  // ================= Legacy prefs (unused categories json) ======

  /// Old SharedPreferences-based category list is no longer used; kept as a
  /// one-time import so users don't lose custom categories from earlier builds.
  Future<void> migrateLegacyPrefsCategories() async {
    if (_categories.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('custom_categories');
    if (json == null) return;
    try {
      final decoded = jsonDecode(json);
      for (final name in List<String>.from(decoded)) {
        if (_categoryByName(name) == null &&
            name != 'Uncategorized' &&
            name.trim().isNotEmpty) {
          final id = await dbHelper.insertCategory(name.trim());
          _categories = [..._categories, BookCategory(id: id, name: name.trim())];
        }
      }
      await prefs.remove('custom_categories');
      notifyListeners();
    } catch (_) {}
  }
}


