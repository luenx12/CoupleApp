// ═══════════════════════════════════════════════════════════════════════════════
// MediaApiService — Encrypted media upload + self-destruct DELETE
//
// POST  /api/Media/upload        → şifreli blob yükle, mediaId al
// GET   /api/Media/{mediaId}     → şifreli blob indir (RAM'de çözülecek)
// DELETE /api/Media/{mediaId}    → Self-Destruct: sunucudan kalıcı sil
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/config/app_config.dart';

class MediaApiService {
  MediaApiService(this._accessToken);

  final String _accessToken;

  String get _base => AppConfig.baseUrl;

  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer $_accessToken',
  };

  // ── Upload (multipart) ───────────────────────────────────────────────────

  /// [encryptedBytes] → zaten şifreli .aes bytes
  /// Döner: mediaId (String)
  Future<String> uploadEncryptedMedia({
    required Uint8List encryptedBytes,
    required String messageId,
  }) async {
    final uri     = Uri.parse('$_base/api/Media/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders)
      ..fields['messageId'] = messageId
      ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            encryptedBytes,
            filename: '$messageId.aes',
          ));

    final streamed  = await request.send();
    final response  = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Media upload failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['mediaId'] as String;
  }

  // ── Download (stream → bytes) ────────────────────────────────────────────

  Future<Uint8List> downloadEncryptedMedia(String mediaId) async {
    final uri      = Uri.parse('$_base/api/Media/$mediaId');
    final response = await http.get(uri, headers: _authHeaders);

    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('Media download failed: ${response.statusCode}');
  }

  // ── Self-Destruct DELETE ─────────────────────────────────────────────────

  /// Gösterildikten sonra sunucudan kalıcı sil — self-destruct 🔥
  Future<void> selfDestruct(String mediaId) async {
    final uri      = Uri.parse('$_base/api/Media/$mediaId');
    final response = await http.delete(uri, headers: _authHeaders);

    if (response.statusCode != 204 && response.statusCode != 200) {
      // Idempotent — zaten silinmişse hata fırlatma
      if (response.statusCode != 404) {
        throw Exception('Self-destruct failed: ${response.statusCode}');
      }
    }
  }
}
