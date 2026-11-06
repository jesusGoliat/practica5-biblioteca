import 'package:flutter_test/flutter_test.dart';

import 'package:biblioteca/core/models/history_entry.dart';
import 'package:biblioteca/core/models/server_date.dart';

void main() {
  test('fecha del servidor sin zona se interpreta como UTC', () {
    final date = parseServerDate('2026-11-06T04:10:00.123456');
    expect(date.isUtc, isTrue);
    expect(date.hour, 4);
  });

  test('fecha con Z u offset conserva su instante', () {
    expect(parseServerDate('2026-11-06T04:10:00Z').hour, 4);
    expect(parseServerDate('2026-11-05T22:10:00-06:00').toUtc().hour, 4);
  });

  test('HistoryEntry usa la conversión UTC', () {
    final entry = HistoryEntry.fromJson({
      'id': 'a',
      'query': 'dune',
      'created_at': '2026-11-06T04:10:00',
    });
    expect(entry.createdAt.toUtc().hour, 4);
  });
}
