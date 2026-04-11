// ─────────────────────────────────────────────────────────────────────────────
// CryptoProvider — Riverpod providers for CryptoService
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'crypto_service.dart';
import '../auth/domain/auth_state.dart';

export 'crypto_service.dart';

/// Singleton CryptoService provider
/// init() çağrılana kadar null döner → FutureProvider kullan
final cryptoServiceProvider = Provider<CryptoService>((ref) {
  final storage = ref.read(secureStorageProvider);
  return CryptoService(storage);
});

/// CryptoService'i başlat + RSA key üret/yükle
final cryptoInitProvider = FutureProvider<void>((ref) async {
  final service = ref.read(cryptoServiceProvider);
  await service.init();
});
