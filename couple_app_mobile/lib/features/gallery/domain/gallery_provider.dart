import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../crypto/crypto_provider.dart';
import '../data/gallery_api_service.dart';
import '../data/gallery_repository.dart';

final galleryApiProvider = Provider<GalleryApiService>((ref) {
  final token = ref.watch(authNotifierProvider).accessToken;
  if (token == null) throw Exception('Not authenticated');
  return GalleryApiService(token);
});

final galleryRepoProvider = Provider<GalleryRepository>((ref) {
  final api = ref.watch(galleryApiProvider);
  final crypto = ref.watch(cryptoServiceProvider);
  return GalleryRepository(api: api, crypto: crypto);
});
