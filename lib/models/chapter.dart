/// A parsed chapter from an EPUB file.
class ParsedChapter {
  final String title;
  final String htmlContent;
  final int index;

  const ParsedChapter({
    required this.title,
    required this.htmlContent,
    required this.index,
  });
}

/// The result of parsing an EPUB file.
class ParsedEpub {
  final String title;
  final String? author;
  final List<ParsedChapter> chapters;
  final List<int>? coverImageBytes;
  final Map<String, List<int>> images;

  const ParsedEpub({
    required this.title,
    this.author,
    required this.chapters,
    this.coverImageBytes,
    this.images = const {},
  });
}
