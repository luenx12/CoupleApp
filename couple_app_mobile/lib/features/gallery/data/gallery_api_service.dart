import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/config/app_config.dart';
import '../domain/gallery_item_model.dart';

class GalleryApiService {
  GalleryApiService(this._accessToken);

  final String _accessToken;

  String get _base => AppConfig.baseUrl;

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_accessToken',
      };

  Future<List<GalleryItemModel>> fetchGalleryItems() async {
    final uri = Uri.parse('$_base/api/Gallery');
    final response = await http.get(uri, headers: _authHeaders);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch gallery: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => GalleryItemModel.fromMap(e)).toList();
  }

  Future<GalleryItemModel> uploadGalleryItem({
    required Uint8List encryptedForSender,
    required Uint8List encryptedForReceiver,
    required String partnerId,
    DateTime? lockedUntil,
  }) async {
    final uri = Uri.parse('$_base/api/Gallery');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders)
      ..fields['partnerId'] = partnerId;

    if (lockedUntil != null) {
      request.fields['lockedUntil'] = lockedUntil.toUtc().toIso8601String();
    }

    request.files.add(http.MultipartFile.fromBytes(
      'files',
      encryptedForSender,
      filename: 'sender.aes',
    ));
    
    request.files.add(http.MultipartFile.fromBytes(
      'files',
      encryptedForReceiver,
      filename: 'receiver.aes',
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Gallery upload failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GalleryItemModel.fromMap(data);
  }

  Future<Uint8List> downloadEncryptedMedia(String mediaId) async {
    final uri = Uri.parse('$_base/api/Gallery/media/$mediaId');
    final response = await http.get(uri, headers: _authHeaders);

    if (response.statusCode == 200) return response.bodyBytes;
    
    // Server enforces Zero-leak LockedUntil rule
    if (response.statusCode == 403) {
      throw Exception('This media is locked in a time capsule.');
    }
    
    throw Exception('Media download failed: ${response.statusCode}');
  }
}
