/// Plain-text search utilities for the in-reader find feature.
///
/// Matches run on tag-stripped text so HTML markup can never produce
/// false hits; offsets returned refer to positions within that stripped
/// text.
class SearchTextUtils {
  SearchTextUtils._();

  static final _tagRe = RegExp(r'<[^>]*>');

  /// Remove all HTML tags from a fragment.
  static String stripTags(String html) => html.replaceAll(_tagRe, '');

  /// Collapse runs of whitespace so matches read naturally in snippets.
  static String normalize(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// All case-insensitive occurrences of [query] in [text] as
  /// (start, end) offset pairs on the original (non-lowercased) string.
  static List<(int, int)> occurrences(String text, String query) {
    final results = <(int, int)>[];
    if (query.isEmpty) return results;
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    var start = 0;
    while (true) {
      final idx = lower.indexOf(q, start);
      if (idx == -1) break;
      results.add((idx, idx + q.length));
      start = idx + q.length;
    }
    return results;
  }

  /// Build a short context snippet around a match, with ellipses where
  /// text was trimmed. Offsets refer to [text].
  static String snippet(String text, int start, int end,
      {int radius = 48}) {
    final from =
        (start - radius).clamp(0, text.length);
    final to = (end + radius).clamp(0, text.length);
    final prefix = from > 0 ? '…' : '';
    final suffix = to < text.length ? '…' : '';
    return '$prefix${text.substring(from, to).trim()}$suffix';
  }
}

/// One search result location: fragment/item [chapterIdx]/[itemIdx] plus
/// the match span inside its stripped plain text.
class SearchHit {
  final int chapterIdx;
  final int itemIdx;
  final int start;
  final int end;

  const SearchHit({
    required this.chapterIdx,
    required this.itemIdx,
    required this.start,
    required this.end,
  });
}

/// Result of the background isolate: stripped plain text per chapter
/// (snippet source) plus every match for the query.
class BookSearchResult {
  final List<List<String>> plainChapters;
  final List<SearchHit> hits;
  final String query;

  const BookSearchResult({
    required this.plainChapters,
    required this.hits,
    required this.query,
  });
}

/// Pure, isolate-safe worker: strips tags per chapter item and finds all
/// case-insensitive matches for [query]. Runs inside compute() so large
/// books never block the UI thread.
BookSearchResult buildAndSearch(
    List<List<String>> itemsPerChapter, String query) {
  final plainChapters = <List<String>>[];
  final hits = <SearchHit>[];

  final q = query.trim();
  final lowerQ = q.toLowerCase();

  for (var c = 0; c < itemsPerChapter.length; c++) {
    final items = itemsPerChapter[c];
    final plain = <String>[];
    for (var i = 0; i < items.length; i++) {
      final text = SearchTextUtils.stripTags(items[i]);
      plain.add(text);

      if (lowerQ.isEmpty) continue;
      final lowerText = text.toLowerCase();
      var cursor = 0;
      while (true) {
        final idx = lowerText.indexOf(lowerQ, cursor);
        if (idx == -1) break;
        hits.add(SearchHit(
          chapterIdx: c,
          itemIdx: i,
          start: idx,
          end: idx + q.length,
        ));
        cursor = idx + q.length;
      }
    }
    plainChapters.add(plain);
  }

  return BookSearchResult(
    plainChapters: plainChapters,
    hits: hits,
    query: q,
  );
}

/// compute()-friendly entry point taking a single record argument.
BookSearchResult buildAndSearchEntry((List<List<String>>, String) args) =>
    buildAndSearch(args.$1, args.$2);
