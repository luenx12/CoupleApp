// ─────────────────────────────────────────────────────────────────────────────
// MediaProvider — Riverpod providers for media services
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../crypto/crypto_provider.dart';
import 'media_storage_service.dart';

/// MediaStorageService provider
final mediaStorageServiceProvider = Provider<MediaStorageService>((ref) {
  final crypto = ref.read(cryptoServiceProvider);
  return MediaStorageService(crypto);
});
