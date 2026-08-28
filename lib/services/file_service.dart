import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import 'book_parser.dart';
import 'book_cache_service.dart';
import 'cover_generator.dart';
import '../database/database_helper.dart';

/// Handles file picking, copying to app storage, and cover extraction.
class FileService {
  static const _uuid = Uuid();

  /// Pick a single book file (any supported format).
  Future<String?> pickEpubFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: BookParser.supportedExtensions,
    );
    if (files.isEmpty) return null;
    return files.first.path;
  }

  /// Pick any file (used for font imports).
  Future<String?> pickAnyFile() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return null;
    return files.first.path;
  }

  /// Pick a directory. Returns null when cancelled or unavailable.
  Future<String?> pickFolder() async {
    try {
      return await FilePicker.getDirectoryPath();
    } catch (_) {
      return null;
    }
  }

  /// All supported book files directly inside [folderPath] (not recursive),
  /// sorted by file name.
  ///
  /// [FolderScanResult.accessDenied] distinguishes "folder can't be read
  /// (storage permission)" from "folder readable but no books inside".
  Future<FolderScanResult> listEpubsInFolder(String folderPath) async {
    try {
      final dir = Directory(folderPath);
      if (!dir.existsSync()) return const FolderScanResult([]);
      final epubs = <String>[];
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is File &&
            BookParser.isSupported(entity.path)) {
          epubs.add(entity.path);
        }
      }
      epubs.sort((a, b) => p.basename(a).toLowerCase().compareTo(
          p.basename(b).toLowerCase()));
      return FolderScanResult(epubs);
    } catch (_) {
      // Folder existed but couldn't be listed -> almost certainly a
      // storage-permission problem on Android scoped storage.
      return const FolderScanResult([], accessDenied: true);
    }
  }

  /// Import any supported book file: copy to app storage, parse via the
  /// BookParser facade, attach a cover (embedded or generated), save to DB.
  /// Pass [preParsed] (from batch duplicate checks) to skip re-parsing.
  /// Returns the created Book, or null if import failed.
  Future<Book?> importEpub(String sourcePath, {ParsedEpub? preParsed}) async {
    final bookId = _uuid.v4();
    Directory? booksDir;
    String? epubPath;

    try {
      // Get app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      booksDir = Directory(p.join(appDir.path, 'books'));
      await booksDir.create(recursive: true);

      // Copy book to app storage, preserving its original extension.
      final srcExt = p.extension(sourcePath);
      epubPath = p.join(booksDir.path, '$bookId$srcExt');
      await File(sourcePath).copy(epubPath);

      // Parse via the multi-format facade.
      final parsed =
          preParsed ?? await bookParser.parseFile(epubPath);

      // Cover: embedded bytes, or a generated gradient for text formats.
      List<int>? coverBytes = parsed.coverImageBytes;
      if (coverBytes == null || coverBytes.isEmpty) {
        coverBytes = await CoverGenerator.generate(
          title: parsed.title,
          author: parsed.author ?? '',
        );
      }

      String? coverPath;
      if (coverBytes.isNotEmpty) {
        final coverDir = Directory(p.join(booksDir.path, bookId));
        await coverDir.create(recursive: true);
        coverPath = p.join(coverDir.path, 'cover.png');
        await File(coverPath).writeAsBytes(coverBytes);
      }

      // Create book record
      final book = Book(
        id: bookId,
        title: parsed.title,
        author: parsed.author ?? 'Unknown Author',
        filePath: epubPath,
        coverImagePath: coverPath,
        shelf: 'Uncategorized',
        totalChapters: parsed.chapters.length,
        addedAt: DateTime.now(),
      );

      // Save to database
      await dbHelper.insertBook(book);

      // Cache parsed content for instant reader opening.
      await bookCache.save(bookId, parsed);

      return book;
    } catch (e) {
      // Import failed - clean up any partial files
      try {
        if (epubPath != null) {
          final partialEpub = File(epubPath);
          if (await partialEpub.exists()) await partialEpub.delete();
        }
        if (booksDir != null) {
          final coverDir = Directory(p.join(booksDir.path, bookId));
          if (await coverDir.exists()) {
            await coverDir.delete(recursive: true);
          }
        }
      } catch (_) {}
      return null;
    }
  }

  /// Get the app's books directory.
  Future<Directory> getBooksDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'books'));
    await booksDir.create(recursive: true);
    return booksDir;
  }

  /// Size in bytes of a book's stored EPUB; 0 when missing/unreadable.
  Future<int> epubFileSize(Book book) async {
    try {
      final f = File(book.filePath);
      if (!await f.exists()) return 0;
      return await f.length();
    } catch (_) {
      return 0;
    }
  }

  /// Replace an existing book's stored file with a new source file,
  /// keeping the same book ID (progress, categories, highlights and
  /// bookmarks survive). Regenerates the cover from the new parse when
  /// available, falling back to a generated cover. Returns the updated Book.
  Future<Book> replaceEpubFile({
    required Book existing,
    required String newSourcePath,
    required ParsedEpub parsed,
  }) async {
    // Overwrite the stored book (preserve original stored extension).
    await File(newSourcePath).copy(existing.filePath);

    // Regenerate the cover: embedded bytes, else a generated gradient —
    // every replaced book ends up with a fresh cover.
    List<int>? coverBytes = parsed.coverImageBytes;
    if (coverBytes == null || coverBytes.isEmpty) {
      coverBytes = await CoverGenerator.generate(
        title: parsed.title.isNotEmpty ? parsed.title : existing.title,
        author: parsed.author ?? '',
      );
    }

    final appDir = await getApplicationDocumentsDirectory();
    final coverDir = Directory(p.join(appDir.path, 'books', existing.id));
    await coverDir.create(recursive: true);
    var coverPath = p.join(coverDir.path, 'cover.png');
    await File(coverPath).writeAsBytes(coverBytes);

    await dbHelper.updateBookContentMeta(
      existing.id,
      totalChapters: parsed.chapters.length,
      coverImagePath: coverPath,
    );

    // Refresh the cache with new content.
    await bookCache.save(existing.id, parsed);

    return existing.copyWith(
      totalChapters: parsed.chapters.length,
      coverImagePath: coverPath,
      lastReadAt: DateTime.now(),
    );
  }

  /// Delete a book's files from disk (stored book + cover directory).
  Future<void> deleteBookFiles(String bookId) async {
    try {
      final booksDir = await getBooksDirectory();
      // Stored file may carry any supported extension.
      for (final entity
          in booksDir.listSync(followLinks: false).whereType<File>()) {
        if (p.basenameWithoutExtension(entity.path) == bookId) {
          await entity.delete();
        }
      }

      final coverDir = Directory(p.join(booksDir.path, bookId));
      if (await coverDir.exists()) await coverDir.delete(recursive: true);

      // Remove parsed content cache.
      await bookCache.delete(bookId);
    } catch (_) {}
  }

  /// Total bytes on disk used by the library (EPUBs and cover images).
  Future<int> getLibraryStorageBytes() async {
    try {
      final booksDir = await getBooksDirectory();
      var total = 0;
      await for (final entity in booksDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Remove cover directories whose book id has no matching EPUB file
  /// (e.g. leftovers from failed imports).
  Future<void> clearOrphanedCovers() async {
    try {
      final booksDir = await getBooksDirectory();
      await for (final entity in booksDir.list(followLinks: false)) {
        if (entity is Directory) {
          final id = p.basename(entity.path);
          final epub = File(p.join(booksDir.path, '$id.epub'));
          if (!await epub.exists()) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}

/// Global singleton instance.
final fileService = FileService();

/// Outcome of scanning a folder for EPUB files.
class FolderScanResult {
  final List<String> bookPaths;

  /// True when the folder exists but the OS denied listing it
  /// (storage permission missing on Android).
  final bool accessDenied;

  const FolderScanResult(this.bookPaths, {this.accessDenied = false});
}

