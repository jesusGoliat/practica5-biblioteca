class LibraryItem {
  const LibraryItem({
    required this.publicId,
    required this.olKey,
    required this.title,
    this.author,
    this.coverId,
    this.status = 'want_to_read',
    this.rating,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  final String publicId;
  final String olKey;
  final String title;
  final String? author;
  final int? coverId;
  final String status;
  final int? rating;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  String? coverUrl({String size = 'M'}) => coverId == null
      ? null
      : 'https://covers.openlibrary.org/b/id/$coverId-$size.jpg';

  String get statusLabel => switch (status) {
    'reading' => 'Leyendo',
    'read' => 'Leído',
    _ => 'Por leer',
  };

  LibraryItem copyWith({
    String? status,
    int? rating,
    String? notes,
    DateTime? updatedAt,
    bool? deleted,
  }) => LibraryItem(
    publicId: publicId,
    olKey: olKey,
    title: title,
    author: author,
    coverId: coverId,
    status: status ?? this.status,
    rating: rating ?? this.rating,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );

  factory LibraryItem.fromJson(Map<String, dynamic> json) => LibraryItem(
    publicId: json['public_id'] as String,
    olKey: json['ol_key'] as String,
    title: json['title'] as String,
    author: json['author'] as String?,
    coverId: json['cover_id'] as int?,
    status: (json['status'] as String?) ?? 'want_to_read',
    rating: json['rating'] as int?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    deleted: (json['deleted'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'public_id': publicId,
    'ol_key': olKey,
    'title': title,
    'author': author,
    'cover_id': coverId,
    'status': status,
    'rating': rating,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted': deleted,
  };
}
