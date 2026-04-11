import 'dart:typed_data';
import '../../crypto/crypto_service.dart';
import '../domain/gallery_item_model.dart';
import 'gallery_api_service.dart';

class GalleryRepository {
  GalleryRepository({
    required this.api,
    required this.crypto,
  });

  final GalleryApiService api;
  final CryptoService crypto;

  Future<List<GalleryItemModel>> fetchItems() => api.fetchGalleryItems();

  Future<GalleryItemModel> uploadPhoto({
    required Uint8List imageBytes,
    required String partnerId,
    required String partnerPublicKeyPem,
    DateTime? lockedUntil,
  }) async {
    if (!crypto.isReady) throw Exception('CryptoService not ready.');

    // Kilitli zaman kapsülü için çift şifreleme mekanizması (Zero-Leak)
    
    // 1. Kendi private key'imle okumak için kendime şifrele
    final forSenderPayload = crypto.encryptForSelf(imageBytes);
    
    // 2. Partnerimin public key'i ile ona özel şifrele
    final forReceiverPayload = crypto.encrypt(imageBytes, partnerPublicKeyPem);

    // Byte array'lere dönüştür
    final senderBytes = forSenderPayload.toBytes();
    final receiverBytes = forReceiverPayload.toBytes();

    // RAM'i temizle
    CryptoService.zeroFill(imageBytes);

    // API'ye yolla
    return api.uploadGalleryItem(
      encryptedForSender: senderBytes,
      encryptedForReceiver: receiverBytes,
      partnerId: partnerId,
      lockedUntil: lockedUntil,
    );
  }

  Future<Uint8List> downloadAndDecrypt(String mediaId) async {
    // 1. Şifreli blob'u çek (Güvenlik gereği LockedUntil backend'de kontrol ediliyor)
    final encryptedBytes = await api.downloadEncryptedMedia(mediaId);

    // 2. Payload'a çevir
    final payload = EncryptedPayload.fromBytes(encryptedBytes);

    // 3. Decrypt et (Sadece RAM'de plain text)
    final plainBytes = crypto.decrypt(payload);

    return plainBytes;
  }
}
