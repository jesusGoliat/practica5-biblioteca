import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/book.dart';
import '../core/models/history_entry.dart';
import '../core/network/api_exception.dart';
import '../data/repository.dart';

class SearchProvider extends ChangeNotifier {
  SearchProvider(this.repository);

  final Repository repository;
  Timer? _debounce;
  int _token = 0;

  String query = '';
  List<Book> results = const [];
  List<HistoryEntry> history = const [];
  bool isLoading = false;
  bool hasSearched = false;
  String? error;
  bool fromCache = false;
  DateTime? fetchedAt;
  Duration? elapsed;
  int total = 0;

  void onQueryChanged(String value) {
    query = value;
    _debounce?.cancel();
    if (value.trim().length < 2) {
      _token++;
      results = const [];
      hasSearched = false;
      isLoading = false;
      error = null;
      notifyListeners();
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => search(value, recordHistory: false),
    );
  }

  /// La búsqueda automática al teclear no se guarda en el historial; sólo la
  /// que el usuario confirma (lupa del teclado o una entrada del historial).
  Future<void> search(String value, {bool recordHistory = true}) async {
    final q = value.trim();
    if (q.isEmpty) return;
    query = q;
    final token = ++_token;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final outcome = await repository.search(q, recordHistory: recordHistory);
      if (token != _token) return;
      results = outcome.books;
      total = outcome.total;
      fromCache = outcome.fromCache;
      fetchedAt = outcome.fetchedAt;
      elapsed = outcome.elapsed;
      error = outcome.error?.message;
    } on ApiException catch (e) {
      if (token != _token) return;
      results = const [];
      fromCache = false;
      error = e.message;
    } finally {
      if (token == _token) {
        isLoading = false;
        hasSearched = true;
        notifyListeners();
      }
    }
    await loadHistory();
  }

  Future<void> loadHistory() async {
    if (repository.userId == null) return;
    history = await repository.history();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await repository.clearHistory();
    await loadHistory();
  }

  void reset() {
    _debounce?.cancel();
    _token++;
    query = '';
    results = const [];
    history = const [];
    hasSearched = false;
    error = null;
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
