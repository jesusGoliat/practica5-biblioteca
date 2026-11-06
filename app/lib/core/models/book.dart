/// Libro normalizado a partir de las respuestas JSON de Open Library.
class Book {
  const Book({
    required this.olKey,
    required this.title,
    this.authors = const [],
    this.firstPublishYear,
    this.coverId,
    this.subjects = const [],
    this.editionCount,
    this.description,
    this.raw = const {},
  });

  final String olKey;
  final String title;
  final List<String> authors;
  final int? firstPublishYear;
  final int? coverId;
  final List<String> subjects;
  final int? editionCount;
  final String? description;
  final Map<String, dynamic> raw;

  String? get author => authors.isEmpty ? null : authors.join(', ');

  String? coverUrl({String size = 'M'}) {
    if (coverId == null) return null;
    return 'https://covers.openlibrary.org/b/id/$coverId-$size.jpg';
  }

  /// Acepta tanto un documento de `/search.json` como una obra de
  /// `/works/{key}.json`.
  factory Book.fromJson(Map<String, dynamic> json, {String? fallbackKey}) {
    final key = _asString(json['key'] ?? json['ol_key'] ?? fallbackKey) ?? '';
    final title = _asString(json['title']) ?? 'Sin título';

    final authors = <String>[
      ...?_asStringList(json['author_name']),
      ...?_authorNames(json['authors']),
    ];
    if (authors.isEmpty) {
      final author = _asString(json['author']);
      if (author != null) authors.add(author);
    }

    final subjects = <String>[
      ...?_asStringList(json['subject']),
      ...?_asStringList(json['subjects']),
    ];

    final description = _description(json['description']);
    final coverId = _asInt(json['cover_i'] ?? json['cover_id']);

    return Book(
      olKey: key,
      title: title,
      authors: authors,
      firstPublishYear: _asInt(json['first_publish_year']),
      coverId: coverId,
      subjects: subjects,
      editionCount: _asInt(json['edition_count']),
      description: description,
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => {
    'key': olKey,
    'title': title,
    'author_name': authors,
    'first_publish_year': firstPublishYear,
    'cover_i': coverId,
    'subject': subjects,
    'edition_count': editionCount,
    'description': description,
  };

  static String? _asString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// `authors` llega como textos (búsqueda) o como objetos `{name: ...}` (temas).
  static List<String>? _authorNames(Object? value) {
    if (value is! List) return _asStringList(value);
    final names = <String>[];
    for (final item in value) {
      if (item is String && item.trim().isNotEmpty) {
        names.add(item.trim());
      } else if (item is Map && item['name'] is String) {
        final name = (item['name'] as String).trim();
        if (name.isNotEmpty) names.add(name);
      }
    }
    return names;
  }

  static List<String>? _asStringList(Object? value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return null;
  }

  static String? _description(Object? value) {
    if (value is String) return value;
    if (value is Map && value['value'] is String) return value['value'] as String;
    return null;
  }
}
