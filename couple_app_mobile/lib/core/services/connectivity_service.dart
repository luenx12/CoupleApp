// ═══════════════════════════════════════════════════════════════════════════════
// ConnectivityService — İnternet bağlantısını izler
// connectivity_plus paketi ile gerçek zamanlı bağlantı durumu sağlar.
// Riverpod StreamProvider ile tüm uygulamada reaktif kullanılabilir.
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Basit bağlantı durumu
enum NetworkStatus { online, offline }

// ── Provider ──────────────────────────────────────────────────────────────────

/// Anlık bağlantı durumunu Stream olarak izler.
final connectivityStreamProvider = StreamProvider<NetworkStatus>((ref) {
  return ConnectivityService.instance.statusStream;
});

/// Anlık tek değer — senkron okuma için.
final networkStatusProvider = StateProvider<NetworkStatus>((ref) {
  // İlk değer sync olarak belirlenemez; varsayılan online kabul et.
  return NetworkStatus.online;
});

// ── Service ───────────────────────────────────────────────────────────────────

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<NetworkStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  NetworkStatus _current = NetworkStatus.online;

  NetworkStatus get current => _current;
  Stream<NetworkStatus> get statusStream => _controller.stream;

  /// Uygulama başında bir kez çağrılmalı (main.dart veya ProviderScope).
  Future<void> init() async {
    // İlk durumu belirle
    final results = await _connectivity.checkConnectivity();
    _current = _mapResults(results);

    // Sonraki değişiklikleri dinle
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final next = _mapResults(results);
      if (next != _current) {
        _current = next;
        _controller.add(_current);
      }
    });
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }

  static NetworkStatus _mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty) return NetworkStatus.offline;
    return results.any((r) => r != ConnectivityResult.none)
        ? NetworkStatus.online
        : NetworkStatus.offline;
  }
}
