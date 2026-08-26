/// A user-defined category (shelf). Books can belong to many categories
/// through the book_categories join table. Categories can be starred to
/// appear as sections on the library tab.
class BookCategory {
  final int id;
  final String name;
  final bool starred;

  const BookCategory({
    required this.id,
    required this.name,
    this.starred = false,
  });

  factory BookCategory.fromMap(Map<String, dynamic> map) {
    return BookCategory(
      id: map['id'] as int,
      name: map['name'] as String,
      starred: (map['starred'] as int? ?? 0) == 1,
    );
  }

  BookCategory copyWith({bool? starred, String? name}) {
    return BookCategory(
      id: id,
      name: name ?? this.name,
      starred: starred ?? this.starred,
    );
  }
}
