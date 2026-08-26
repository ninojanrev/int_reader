import '../models/chapter.dart';
import 'converters/fb2_converter.dart';
import 'converters/html_converter.dart';
import 'converters/markdown_converter.dart';
import 'converters/txt_converter.dart';
import 'epub_parser.dart';

/// Parses any supported book file into the app-wide [ParsedEpub]
/// representation. The reader/pagination/stats pipeline is format-blind
/// downstream of this facade.
class BookParser {
  /// Extensions we know how to import (lowercase, no dot).
  static const supportedExtensions = [
    'epub',
    'txt',
    'md',
    'markdown',
    'html',
    'htm',
    'fb2',
  ];

  static bool isSupported(String path) =>
      supportedExtensions.contains(extensionOf(path));

  static String extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  /// Parse [path] into a [ParsedEpub]. Throws [FormatException] for
  /// unsupported extensions.
  Future<ParsedEpub> parseFile(String path) async {
    switch (extensionOf(path)) {
      case 'epub':
        return epubParser.parseFile(path);
      case 'txt':
        return const TxtConverter().parse(path);
      case 'md':
      case 'markdown':
        return const MarkdownConverter().parse(path);
      case 'html':
      case 'htm':
        return const HtmlConverter().parse(path);
      case 'fb2':
        return const Fb2Converter().parse(path);
      default:
        throw FormatException('Unsupported book format: ${extensionOf(path)}');
    }
  }
}

/// Global singleton instance.
final bookParser = BookParser();
