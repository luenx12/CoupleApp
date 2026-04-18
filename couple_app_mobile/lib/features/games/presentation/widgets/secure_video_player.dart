import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../crypto/crypto_service.dart';
import '../../../crypto/crypto_provider.dart';
import '../../domain/games_notifier.dart';

class SecureVideoPlayer extends ConsumerStatefulWidget {
  final String mediaId;
  const SecureVideoPlayer({super.key, required this.mediaId});

  @override
  ConsumerState<SecureVideoPlayer> createState() => _SecureVideoPlayerState();
}

class _SecureVideoPlayerState extends ConsumerState<SecureVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _fetchAndPlay();
  }

  Future<void> _fetchAndPlay() async {
    try {
      // Read the auth token from secure storage
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) throw Exception('Not authenticated — no access token.');

      final authHeader = {'Authorization': 'Bearer $token'};

      // 1. Fetch encrypted blob (with auth)
      final uri = Uri.parse('${AppConfig.baseUrl}/api/Media/${widget.mediaId}');
      final response = await http.get(uri, headers: authHeader);

      if (response.statusCode != 200) {
        throw Exception('Media fetch failed: ${response.statusCode}');
      }

      // 2. Decrypt in RAM
      final crypto = ref.read(cryptoServiceProvider);
      final payload = EncryptedPayload.fromBytes(response.bodyBytes);
      final decryptedBytes = crypto.decrypt(payload);

      // 3. Write securely to temp file
      final dir = await getTemporaryDirectory();
      _tempFile = File('${dir.path}/${widget.mediaId}.mp4');
      await _tempFile!.writeAsBytes(decryptedBytes, flush: true);

      // Clear RAM bytes immediately
      CryptoService.zeroFill(decryptedBytes);

      // 4. Play — guard with mounted check
      if (!mounted) return;
      _controller = VideoPlayerController.file(_tempFile!)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          _controller!.play();
          _controller!.setLooping(false);
          _controller!.addListener(_videoListener);
        }).catchError((err) {
          if (mounted) setState(() => _error = err.toString());
        });

      // 5. Delete from server immediately (Self-Destruct) — with auth
      try {
        await http.delete(uri, headers: authHeader);
      } catch (_) {
        // Self-destruct is best-effort; don't block playback on failure
      }

    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _videoListener() {
    if (_controller != null && _controller!.value.position >= _controller!.value.duration && _controller!.value.duration > Duration.zero) {
      // Video finished
      _cleanupAndClose();
    }
  }

  Future<void> _cleanupAndClose() async {
    if (_tempFile != null && await _tempFile!.exists()) {
      // Zero-Leak overwrite
      final size = await _tempFile!.length();
      final wipe = Uint8List(size); // fill with 0s
      await _tempFile!.writeAsBytes(wipe, flush: true);
      await _tempFile!.delete();
    }
    if (mounted) {
      ref.read(gamesNotifierProvider.notifier).clearIncomingMedia();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _cleanupAndClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        height: 200,
        color: Colors.black,
        alignment: Alignment.center,
        child: Text("Hata: $_error", style: const TextStyle(color: Colors.red)),
      );
    }
    
    if (_isLoading) {
      return Container(
        height: 200,
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.redAccent),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller!),
          VideoProgressIndicator(_controller!, allowScrubbing: false, colors: const VideoProgressColors(playedColor: Colors.redAccent)),
        ],
      ),
    );
  }
}
