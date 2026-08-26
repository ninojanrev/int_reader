/// A reading position bookmark saved by the user.
class Bookmark {
  final int? id;
  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final String? label;
  final DateTime createdAt;

  const Bookmark({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.pageIndex,
    this.label,
    required this.createdAt,
  });

  /// Create from a database map.
  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as int?,
      bookId: map['book_id'] as String,
      chapterIndex: map['chapter_index'] as int,
      pageIndex: map['page_index'] as int,
      label: map['label'] as String?,
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
      'label': label,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
