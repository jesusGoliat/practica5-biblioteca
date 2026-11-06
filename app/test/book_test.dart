import 'package:flutter_test/flutter_test.dart';

import 'package:biblioteca/core/models/book.dart';

void main() {
  test('autores como objetos {name} (endpoint de temas) se leen bien', () {
    final book = Book.fromJson({
      'key': '/works/OL1W',
      'title': 'Pride and Prejudice',
      'authors': [
        {'name': 'Jane Austen', 'key': '/authors/OL1A'},
      ],
      'cover_id': 12,
    });
    expect(book.author, 'Jane Austen');
  });

  test('autores como textos (búsqueda) siguen funcionando', () {
    final book = Book.fromJson({
      'key': '/works/OL2W',
      'title': 'Dune',
      'author_name': ['Frank Herbert'],
    });
    expect(book.author, 'Frank Herbert');
  });
}
