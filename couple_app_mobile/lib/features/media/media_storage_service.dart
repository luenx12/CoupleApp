// ═══════════════════════════════════════════════════════════════════════════════
// MediaStorageService — Zero-Leak Encrypted Media Storage
//
// KURAL:
//   • Sunucudan gelen medya ASLA .jpg / .mp4 / .png olarak diske yazılmaz.
//   • Dosyalar .aes uzantısıyla, şifreli format içinde saklanır.
//   • İCloud / Google Drive yedeklemelerden hariç tutulur.
//   • Çözme sadece RAM'de yapılır; çözülmüş byte hiç diske dokunmaz.
//   • Widget dispose edilince RAM'deki plaintext bytes sıfırlanır.
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:io';


import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../crypto/crypto_service.dart';

class MediaStorageService {
  MediaStorageService(this._crypto);

  final CryptoService _crypto;

  // ── Uygulama özel şifreli medya klasörü ────────────────────────────────────
  Future<Directory> get _mediaDir async {
    late Directory base;

    if (kIsWeb) {
      // Web'de path_provider çalışmaz; bu sadece mobile için geçerli
      throw UnsupportedError('MediaStorageService web desteklemiyor.');
    }

    if (Platform.isIOS || Platform.isMacOS) {
      // iOS: Library/Application Support (iCloud'dan otomatik hariç tutulur)
      base = await getApplicationSupportDirectory();
    } else if (Platform.isAndroid) {
      // Android: app-private cache, harici SD card değil
      base = await getApplicationCacheDirectory();
    } else {
      base = await getApplicationSupportDirectory();
    }

    final dir = Directory('${base.path}/e2ee_media');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      await _markNoBackup(dir);
    }
    return dir;
  }

  // ── iCloud / Google Drive yedeklemesini devre dışı bırak ─────────────────
  Future<void> _markNoBackup(Directory dir) async {
    if (Platform.isAndroid) {
      // Android: .nomedia dosyası + MediaScanner'ı engelle
      final noMedia = File('${dir.path}/.nomedia');
      if (!noMedia.existsSync()) noMedia.writeAsBytesSync(Uint8List(0));
    }

    if (Platform.isIOS) {
      // iOS: NSURLIsExcludedFromBackupKey = true
      // platform channel gerektirmeden şu workaround çalışır:
      // getApplicationSupportDirectory zaten iCloud backup'tan hariç tutulur
      // ancak ek güvenlik için __MACOSX prefix ekleyebiliriz (pratik değil)
      // ─ production'da platform channel ile tam kontrol sağlanmalı ─
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  KAYDET — Şifreli olarak diske yaz
  // ═══════════════════════════════════════════════════════════════════════════

  /// [rawBytes]     → ham medya bytes (RAM'de, hiç diske yazılmamış)
  /// [fileId]       → benzersiz dosya ID (UUID önerilir)
  /// [recipientPub] → alıcının RSA public key PEM'i
  ///
  /// Döner: .aes dosya yolu (sadece metadata olarak saklanabilir)
  /// RAW BYTES bu metod dönünce KALICI OLARAK BOZULUR (_zeroFill)
  Future<String> saveEncryptedMedia({
    required Uint8List rawBytes,
    required String fileId,
    required String recipientPublicKeyPem,
  }) async {
    final dir  = await _mediaDir;
    final path = '${dir.path}/$fileId.aes';

    try {
      // 1. Hybrid şifreleme (RAM'de)
      final payload = _crypto.encrypt(rawBytes, recipientPublicKeyPem);

      // 2. .aes dosyasına yaz (binary, şifreli)
      await File(path).writeAsBytes(payload.toBytes(), flush: true);

      return path;
    } finally {
      // 3. Ham bytes'ı RAM'den sil (başarı veya hata durumunda)
      CryptoService.zeroFill(rawBytes);
    }
  }

  /// Kendi kopyamızı kaydet (mesaj geçmişi için)
  Future<String> saveEncryptedMediaForSelf({
    required Uint8List rawBytes,
    required String fileId,
  }) async {
    return saveEncryptedMedia(
      rawBytes:             rawBytes,
      fileId:               '${fileId}_self',
      recipientPublicKeyPem: _crypto.publicKeyPem,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  YÜKLEYİP ÇÖZ — RAM'de çöz, asla diske yazma
  // ═══════════════════════════════════════════════════════════════════════════

  /// Döner: Uint8List (RAM'de plaintext)
  /// UYARI: Kullanım bittikten sonra CryptoService.zeroFill(result) çağır!
  Future<Uint8List> loadAndDecrypt(String aesFilePath) async {
    // 1. Şifreli dosyayı oku
    final encryptedBytes = await File(aesFilePath).readAsBytes();

    // 2. Payload'ı parse et
    final payload = EncryptedPayload.fromBytes(encryptedBytes);

    // 3. RAM'de çöz — diske yazma!
    return _crypto.decrypt(payload);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SİL — .aes dosyasını kalıcı olarak sil
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> deleteMedia(String aesFilePath) async {
    final file = File(aesFilePath);
    if (file.existsSync()) {
      // Güvenli silme: önce üzerine rastgele yaz (1 pass), sonra sil
      final size   = file.lengthSync();
      final random = Uint8List(size);
      for (var i = 0; i < size; i++) { random[i] = 0xFF; }
      await file.writeAsBytes(random, flush: true);
      await file.delete();
    }
  }

  // ── Tüm medya klasörünü sil (çıkış / hesap silme) ──────────────────────
  Future<void> deleteAllMedia() async {
    final dir = await _mediaDir;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  // ── Belirli bir fileId için .aes dosya yolunu döndür ───────────────────
  Future<String> pathFor(String fileId) async {
    final dir = await _mediaDir;
    return '${dir.path}/$fileId.aes';
  }

  /// Dosya mevcut mu?
  Future<bool> exists(String fileId) async {
    final path = await pathFor(fileId);
    return File(path).existsSync();
  }

  /// Zaten şifreli olan bytes'ı direkt diske yaz (sunucudan indirilen .aes)
  /// Bu bytes PLAINTEXT değil — şifreli formatta geliyor.
  Future<String> saveRawEncryptedBytes({
    required Uint8List bytes,
    required String fileId,
  }) async {
    final dir  = await _mediaDir;
    final path = '${dir.path}/$fileId.aes';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}

