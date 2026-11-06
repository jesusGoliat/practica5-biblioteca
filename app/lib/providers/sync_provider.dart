import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/repository.dart';

/// Sincroniza al iniciar, al recuperar conexión, tras cada cambio y con
/// reintentos con retroceso exponencial (5 s … 5 min) mientras haya errores.
class SyncProvider extends ChangeNotifier {
  SyncProvider(this.repository, {this.onSynced});

  final Repository repository;
  final Future<void> Function()? onSynced;

  SyncStatus status = const SyncStatus();
  bool online = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _retry;
  int _failures = 0;
  bool _running = false;

  Future<void> start() async {
    final current = await Connectivity().checkConnectivity();
    online = !current.contains(ConnectivityResult.none);
    _sub ??= Connectivity().onConnectivityChanged.listen((results) {
      final nowOnline = !results.contains(ConnectivityResult.none);
      final recovered = nowOnline && !online;
      online = nowOnline;
      notifyListeners();
      if (recovered) syncNow();
    });
    await refreshStatus();
    if (online) await syncNow();
  }

  Future<void> refreshStatus() async {
    if (repository.userId == null) return;
    status = await repository.syncStatus();
    notifyListeners();
  }

  /// Llamar tras un cambio local: actualiza el contador y, con red, sincroniza.
  Future<void> localChanged() async {
    await refreshStatus();
    if (online) unawaited(syncNow());
  }

  Future<bool> syncNow() async {
    if (_running || repository.userId == null) return false;
    _running = true;
    _retry?.cancel();
    status = SyncStatus(
      pending: status.pending,
      lastSyncAt: status.lastSyncAt,
      lastError: status.lastError,
      syncing: true,
    );
    notifyListeners();
    final ok = await repository.sync();
    _running = false;
    status = await repository.syncStatus();
    if (ok) {
      _failures = 0;
      await onSynced?.call();
    } else {
      _failures++;
      final seconds = (5 * (1 << (_failures - 1).clamp(0, 6))).clamp(5, 300);
      _retry = Timer(Duration(seconds: seconds), () {
        if (online) syncNow();
      });
    }
    notifyListeners();
    return ok;
  }

  void reset() {
    _retry?.cancel();
    _failures = 0;
    status = const SyncStatus();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _retry?.cancel();
    super.dispose();
  }
}
