import 'package:flutter/foundation.dart';

import '../core/models/book.dart';
import '../core/models/favorite_book.dart';
import '../data/repository.dart';

class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider(this.repository, {this.onChanged});

  final Repository repository;
  final VoidCallback? onChanged;

  List<FavoriteBook> items = const [];

  bool isFavorite(String olKey) => items.any((f) => f.olKey == olKey);

  Future<void> load() async {
    if (repository.userId == null) return;
    items = await repository.favorites();
    notifyListeners();
  }

  Future<void> toggle(Book book) async {
    await repository.setFavorite(book, !isFavorite(book.olKey));
    await load();
    onChanged?.call();
  }

  Future<void> remove(FavoriteBook favorite) async {
    await toggleByFavorite(favorite);
  }

  Future<void> toggleByFavorite(FavoriteBook favorite) async {
    final book = await repository.cachedBook(favorite.olKey) ??
        Book(
          olKey: favorite.olKey,
          title: favorite.title,
          authors: favorite.author == null ? const [] : [favorite.author!],
          coverId: favorite.coverId,
        );
    await repository.setFavorite(book, false);
    await load();
    onChanged?.call();
  }

  void reset() {
    items = const [];
    notifyListeners();
  }
}
