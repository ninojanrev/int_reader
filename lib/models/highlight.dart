/// A text highlight saved by the user while reading.
class Highlight {
  final int? id;
  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final String text;
  final DateTime createdAt;

  const Highlight({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.pageIndex,
    required this.text,
    required this.createdAt,
  });

  /// Create from a database map.
  factory Highlight.fromMap(Map<String, dynamic> map) {
    return Highlight(
      id: map['id'] as int?,
      bookId: map['book_id'] as String,
      chapterIndex: map['chapter_index'] as int,
      pageIndex: map['page_index'] as int,
      text: map['text'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// Convert to a database map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'page_index': pageIndex,
      'text': text,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
