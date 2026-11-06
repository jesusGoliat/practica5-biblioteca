/// El backend serializa fechas UTC sin sufijo de zona; sin `Z` Dart las
/// interpretaría como hora local.
DateTime parseServerDate(String value) {
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
  return DateTime.parse(hasZone ? value : '${value}Z');
}
