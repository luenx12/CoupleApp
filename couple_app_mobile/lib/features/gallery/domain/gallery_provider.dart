import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../crypto/crypto_provider.dart';
import '../data/gallery_api_service.dart';
import '../data/gallery_repository.dart';

// Returns null when not authenticated (avoids exception during app startup)
final galleryApiProvider = Provider<GalleryApiService?>((ref) {
  final token = ref.watch(authNotifierProvider).accessToken;
  if (token == null || token.isEmpty) return null;
  return GalleryApiService(token);
});

final galleryRepoProvider = Provider<GalleryRepository?>((ref) {
  final api = ref.watch(galleryApiProvider);
  if (api == null) return null;
  final crypto = ref.watch(cryptoServiceProvider);
  return GalleryRepository(api: api, crypto: crypto);
});
