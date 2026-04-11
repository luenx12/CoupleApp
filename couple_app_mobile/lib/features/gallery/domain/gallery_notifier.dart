import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_notifier.dart';
import 'gallery_item_model.dart';
import 'gallery_provider.dart';

class GalleryState {
  const GalleryState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<GalleryItemModel> items;
  final bool isLoading;
  final String? error;

  GalleryState copyWith({
    List<GalleryItemModel>? items,
    bool? isLoading,
    String? error,
  }) {
    return GalleryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error, // overwrite error (can be null to clear)
    );
  }
}

final galleryNotifierProvider =
    StateNotifierProvider<GalleryNotifier, GalleryState>((ref) {
  return GalleryNotifier(ref);
});

class GalleryNotifier extends StateNotifier<GalleryState> {
  GalleryNotifier(this.ref) : super(const GalleryState()) {
    fetchItems();
  }

  final Ref ref;

  Future<void> fetchItems() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(galleryRepoProvider);
      final items = await repo.fetchItems();
      if (mounted) {
        state = state.copyWith(items: items, isLoading: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<void> uploadPhoto(Uint8List imageBytes, DateTime? lockedUntil) async {
    try {
      final repo = ref.read(galleryRepoProvider);
      final auth = ref.read(authNotifierProvider);

      if (auth.partnerId == null || auth.partnerPublicKey == null) {
        throw Exception("You must have a partner to upload to the shared gallery.");
      }

      final newItem = await repo.uploadPhoto(
        imageBytes: imageBytes,
        partnerId: auth.partnerId!,
        partnerPublicKeyPem: auth.partnerPublicKey!,
        lockedUntil: lockedUntil,
      );

      // Ekle ve listeyi güncelle
      if (mounted) {
        state = state.copyWith(
          items: [newItem, ...state.items], // Başa ekle
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Uint8List> downloadImage(String mediaId) async {
    final repo = ref.read(galleryRepoProvider);
    return repo.downloadAndDecrypt(mediaId);
  }
}
