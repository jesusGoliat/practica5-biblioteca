import 'server_date.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.query,
    required this.createdAt,
  });

  final String id;
  final String query;
  final DateTime createdAt;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    query: json['query'] as String,
    createdAt: parseServerDate(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'query': query,
    'created_at': createdAt.toIso8601String(),
  };
}
