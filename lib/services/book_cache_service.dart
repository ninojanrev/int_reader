import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/chapter.dart';

/// Top-level entry point for loading a cached book in a background isolate.
/// [cacheDirPath] is the full path to the book's cache directory.
Future<ParsedEpub?> loadBookFromDisk(String cacheDirPath) async {
  final dir = Directory(cacheDirPath);
  final metaFile = File(p.join(dir.path, 'meta.json'));
  if (!await metaFile.exists()) return null;

  final manifest =
      jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;

  // Load chapters in parallel.
  final chaptersDir = Directory(p.join(dir.path, 'chapters'));
  final chapterManifest = manifest['chapters'] as List;
  final chapterFutures = chapterManifest.map((entry) async {
    final index = entry['index'] as int;
    final title = entry['title'] as String;
    final file = File(p.join(chaptersDir.path, '$index.html'));
    final htmlContent = await file.readAsString();
    return ParsedChapter(title: title, htmlContent: htmlContent, index: index);
  }).toList();
  final chapters = await Future.wait(chapterFutures);

  // Load images in parallel.
  final images = <String, List<int>>{};
  final imageKeys = (manifest['imageKeys'] as List).cast<String>();
  if (imageKeys.isNotEmpty) {
    final imagesDir = Directory(p.join(dir.path, 'images'));
    final imageFutures = imageKeys.map((key) async {
      final safeName = key.replaceAll(RegExp(r'[/\\]'), '_');
      final file = File(p.join(imagesDir.path, safeName));
      if (await file.exists()) {
        return MapEntry(key, await file.readAsBytes());
      }
      return null;
    }).toList();
    final results = await Future.wait(imageFutures);
    for (final entry in results) {
      if (entry != null) images[entry.key] = entry.value;
    }
  }

  return ParsedEpub(
    title: manifest['title'] as String,
    author: manifest['author'] as String?,
    chapters: chapters,
    images: images,
  );
}

/// On-disk cache for parsed book content. During import, chapters and
/// embedded images are saved to a per-book directory so the reader can
/// load them instantly without re-parsing the EPUB/ZIP.
class BookCacheService {
  static const _cacheDirName = 'book_cache';

  Future<Directory> _cacheRoot() async {
    final appDir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(appDir.path, _cacheDirName));
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  /// Directory holding cached content for [bookId].
  Future<Directory> cacheDirFor(String bookId) async {
    final root = await _cacheRoot();
    return Directory(p.join(root.path, bookId));
  }

  /// Resolved cache directory path for [bookId] (for use with compute).
  Future<String> cacheDirPath(String bookId) async {
    final dir = await cacheDirFor(bookId);
    return dir.path;
  }

  /// True when a valid cache exists for [bookId].
  Future<bool> hasCache(String bookId) async {
    final dir = await cacheDirFor(bookId);
    final metaFile = File(p.join(dir.path, 'meta.json'));
    return metaFile.exists();
  }

  /// Save a [ParsedEpub]'s chapters and images to disk.
  Future<void> save(String bookId, ParsedEpub parsed) async {
    final dir = await cacheDirFor(bookId);
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    // Save chapters
    final chaptersDir = Directory(p.join(dir.path, 'chapters'));
    await chaptersDir.create();
    final chapterManifest = <Map<String, dynamic>>[];
    for (final ch in parsed.chapters) {
      final file = File(p.join(chaptersDir.path, '${ch.index}.html'));
      await file.writeAsString(ch.htmlContent);
      chapterManifest.add({
        'title': ch.title,
        'index': ch.index,
      });
    }

    // Save images
    final imagesDir = Directory(p.join(dir.path, 'images'));
    final imageKeys = <String>[];
    if (parsed.images.isNotEmpty) {
      await imagesDir.create();
      for (final entry in parsed.images.entries) {
        // Flatten key to a safe filename; keep original key in manifest.
        final safeName = entry.key.replaceAll(RegExp(r'[/\\]'), '_');
        final file = File(p.join(imagesDir.path, safeName));
        await file.writeAsBytes(entry.value);
        imageKeys.add(entry.key);
      }
    }

    // Write manifest
    final manifest = {
      'title': parsed.title,
      'author': parsed.author,
      'chapterCount': parsed.chapters.length,
      'chapters': chapterManifest,
      'imageKeys': imageKeys,
    };
    final metaFile = File(p.join(dir.path, 'meta.json'));
    await metaFile.writeAsString(jsonEncode(manifest));
  }

  /// Delete the cache for [bookId].
  Future<void> delete(String bookId) async {
    final dir = await cacheDirFor(bookId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// Global singleton instance.
final bookCache = BookCacheService();
