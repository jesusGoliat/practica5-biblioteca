import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../data/repository.dart';

class RecommendationsProvider extends ChangeNotifier {
  RecommendationsProvider(this.repository);

  final Repository repository;

  RecommendationSet? data;
  bool isLoading = false;
  String? error;

  Future<void> load({bool refresh = true}) async {
    if (repository.userId == null) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      data = await repository.recommendations(refresh: refresh);
    } on ApiException catch (e) {
      error = e.message;
      data ??= await repository.cachedRecommendations();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    data = null;
    error = null;
    notifyListeners();
  }
}
