/// A single book in the user's library, backed by SQLite.
class Book {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String? coverImagePath;
  final String shelf;
  final double progress;
  final int currentChapter;
  final int currentPage;
  final double scrollOffset;
  final int scrollFragment;
  final int totalChapters;
  final DateTime addedAt;
  final DateTime? lastReadAt;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverImagePath,
    this.shelf = 'Uncategorized',
    this.progress = 0.0,
    this.currentChapter = 0,
    this.currentPage = 0,
    this.scrollOffset = 0.0,
    this.scrollFragment = 0,
    this.totalChapters = 0,
    required this.addedAt,
    this.lastReadAt,
  });

  bool get isInProgress => progress > 0 && progress < 1;

  /// Create from a database map.
  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      filePath: map['file_path'] as String,
      coverImagePath: map['cover_image_path'] as String?,
      shelf: map['shelf'] as String? ?? 'Uncategorized',
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      currentChapter: map['current_chapter'] as int? ?? 0,
      currentPage: map['current_page'] as int? ?? 0,
      scrollOffset: (map['scroll_offset'] as num?)?.toDouble() ?? 0.0,
      scrollFragment: map['scroll_fragment'] as int? ?? 0,
      totalChapters: map['total_chapters'] as int? ?? 0,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
      lastReadAt: map['last_read_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_read_at'] as int)
          : null,
    );
  }

  /// Convert to a database map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'file_path': filePath,
      'cover_image_path': coverImagePath,
      'shelf': shelf,
      'progress': progress,
      'current_chapter': currentChapter,
      'current_page': currentPage,
      'scroll_offset': scrollOffset,
      'scroll_fragment': scrollFragment,
      'total_chapters': totalChapters,
      'added_at': addedAt.millisecondsSinceEpoch,
      'last_read_at': lastReadAt?.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with updated fields.
  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? coverImagePath,
    String? shelf,
    double? progress,
    int? currentChapter,
    int? currentPage,
    double? scrollOffset,
    int? scrollFragment,
    int? totalChapters,
    DateTime? addedAt,
    DateTime? lastReadAt,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      shelf: shelf ?? this.shelf,
      progress: progress ?? this.progress,
      currentChapter: currentChapter ?? this.currentChapter,
      currentPage: currentPage ?? this.currentPage,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      scrollFragment: scrollFragment ?? this.scrollFragment,
      totalChapters: totalChapters ?? this.totalChapters,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}
