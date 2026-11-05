import 'book.dart';

class Recommendation {
  const Recommendation({
    required this.book,
    required this.reason,
    required this.score,
  });

  final Book book;
  final String reason;
  final double score;

  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(
    book: Book.fromJson(json['book'] as Map<String, dynamic>),
    reason: json['reason'] as String,
    score: (json['score'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'book': book.toJson(),
    'reason': reason,
    'score': score,
  };
}
