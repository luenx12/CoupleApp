// ═══════════════════════════════════════════════════════════════════════════════
// LocationService — GPS + E2EE encryption wrapper
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import '../../crypto/crypto_service.dart';

class LocationService {
  LocationService(this._crypto);

  final CryptoService _crypto;

  // ── Konum izni iste + GPS al ─────────────────────────────────────────────

  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Konum servisleri kapalı. Lütfen açın.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Konum izni reddedildi.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Konum izni kalıcı olarak reddedildi. Ayarlardan açın.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  // ── Konumu E2EE ile şifrele ────────────────────────────────────────────────

  /// [partnerPublicKeyPem] → alıcının RSA public key'i
  /// Döner: Base64 encrypted payload string
  Future<String> encryptLocation({
    required double lat,
    required double lon,
    required String partnerPublicKeyPem,
  }) async {
    final json = jsonEncode({'lat': lat, 'lon': lon, 'ts': DateTime.now().toIso8601String()});
    final bytes = Uint8List.fromList(utf8.encode(json));
    final payload = _crypto.encrypt(bytes, partnerPublicKeyPem);
    CryptoService.zeroFill(bytes);
    return payload.toBase64();
  }

  // ── Şifreli konumu çöz ────────────────────────────────────────────────────

  Future<({double lat, double lon, DateTime timestamp})> decryptLocation(
    String encryptedBase64,
  ) async {
    final payload = EncryptedPayload.fromBase64(encryptedBase64);
    final bytes   = _crypto.decrypt(payload);
    final json    = utf8.decode(bytes);
    CryptoService.zeroFill(bytes);

    final data = jsonDecode(json) as Map<String, dynamic>;
    return (
      lat:       (data['lat'] as num).toDouble(),
      lon:       (data['lon'] as num).toDouble(),
      timestamp: DateTime.parse(data['ts'] as String),
    );
  }
}
