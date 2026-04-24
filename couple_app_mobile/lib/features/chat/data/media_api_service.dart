// ═══════════════════════════════════════════════════════════════════════════════
// MediaApiService v2 — Encrypted media upload / download / self-destruct
//
// POST   /api/Media/upload    → şifreli blob yükle → mediaId
// GET    /api/Media/{id}      → şifreli blob indir  (Dio, 30s timeout, retry×3)
// DELETE /api/Media/{id}      → Self-Destruct 🔥
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/config/app_config.dart';

class MediaApiService {
  MediaApiService([this._initialToken]);

  final String? _initialToken;
  static const _maxRetries = 3;

  String get _base => AppConfig.baseUrl;

  Future<String> get _token async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: 'access_token') ?? _initialToken ?? '';
  }

  Future<Map<String, String>> get _authHeaders async =>
      {'Authorization': 'Bearer ${await _token}'};

  // ── Upload (multipart / http paketi) ────────────────────────────────────────

  Future<String> uploadEncryptedMedia({
    required Uint8List encryptedBytes,
    required String messageId,
  }) async {
    final uri     = Uri.parse('$_base/api/Media/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(await _authHeaders)
      ..fields['messageId'] = messageId
      ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            encryptedBytes,
            filename: '$messageId.aes',
          ));

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Media upload failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['mediaId'] as String;
  }

  // ── Download (Dio, 30s timeout, retry×3, stream → bytes) ────────────────────

  Future<Uint8List> downloadEncryptedMedia(String mediaId) async {
    final tok = await _token;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Authorization': 'Bearer $tok'},
    ));

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await dio.get<List<int>>(
          '$_base/api/Media/$mediaId',
          options: Options(responseType: ResponseType.bytes),
        );

        if (response.statusCode == 200 && response.data != null) {
          return Uint8List.fromList(response.data!);
        }
        throw Exception('Media download failed: ${response.statusCode}');
      } on DioException catch (e) {
        final isLast = attempt == _maxRetries - 1;
        if (isLast) rethrow;
        // Exponential backoff: 1s, 2s
        await Future.delayed(Duration(seconds: 1 << attempt));
        final _ = e;
      }
    }

    throw Exception('Media download failed after $_maxRetries attempts');
  }

  // ── Self-Destruct DELETE ─────────────────────────────────────────────────────

  Future<void> selfDestruct(String mediaId) async {
    final uri      = Uri.parse('$_base/api/Media/$mediaId');
    final response = await http.delete(uri, headers: await _authHeaders)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 204 &&
        response.statusCode != 200 &&
        response.statusCode != 404) {
      throw Exception('Self-destruct failed: ${response.statusCode}');
    }
  }
}
