import 'server_date.dart';

class FavoriteBook {
  const FavoriteBook({
    required this.olKey,
    required this.title,
    this.author,
    this.coverId,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  final String olKey;
  final String title;
  final String? author;
  final int? coverId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  String? coverUrl({String size = 'M'}) => coverId == null
      ? null
      : 'https://covers.openlibrary.org/b/id/$coverId-$size.jpg';

  factory FavoriteBook.fromJson(Map<String, dynamic> json) => FavoriteBook(
    olKey: json['ol_key'] as String,
    title: json['title'] as String,
    author: json['author'] as String?,
    coverId: json['cover_id'] as int?,
    createdAt: parseServerDate(json['created_at'] as String),
    updatedAt: parseServerDate(json['updated_at'] as String),
    deleted: (json['deleted'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'ol_key': olKey,
    'title': title,
    'author': author,
    'cover_id': coverId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted': deleted,
  };
}
