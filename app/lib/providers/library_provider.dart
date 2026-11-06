import 'package:flutter/foundation.dart';

import '../core/models/book.dart';
import '../core/models/library_item.dart';
import '../data/repository.dart';

class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this.repository, {this.onChanged});

  final Repository repository;
  final VoidCallback? onChanged;

  List<LibraryItem> items = const [];
  bool isLoading = false;

  List<LibraryItem> byStatus(String status) =>
      items.where((i) => i.status == status).toList();

  LibraryItem? find(String olKey) {
    for (final item in items) {
      if (item.olKey == olKey) return item;
    }
    return null;
  }

  Future<void> load() async {
    if (repository.userId == null) return;
    isLoading = true;
    notifyListeners();
    items = await repository.library();
    isLoading = false;
    notifyListeners();
  }

  Future<void> add(Book book, String status) async {
    await repository.addToLibrary(book, status);
    await load();
    onChanged?.call();
  }

  Future<void> update(LibraryItem item, {String? status, int? rating}) async {
    await repository.updateLibraryItem(item, status: status, rating: rating);
    await load();
    onChanged?.call();
  }

  Future<void> remove(LibraryItem item) async {
    await repository.deleteLibraryItem(item);
    await load();
    onChanged?.call();
  }

  void reset() {
    items = const [];
    notifyListeners();
  }
}
