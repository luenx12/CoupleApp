// ═══════════════════════════════════════════════════════════════════════════════
// EncryptedImageWidget — In-Memory Decryption Widget
//
// ZERO-LEAK PRENSIBI:
//   1. .aes dosyasını oku
//   2. RAM'de çöz (Image.memory ile göster)  
//   3. Widget dispose edilince plaintext bytes _zeroFill ile sıfırlanır
//   4. Hiçbir aşamada .jpg / .png diske yazılmaz
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../crypto/crypto_service.dart';
import 'media_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  EncryptedImageWidget
// ─────────────────────────────────────────────────────────────────────────────
class EncryptedImageWidget extends ConsumerStatefulWidget {
  const EncryptedImageWidget({
    super.key,
    required this.aesFilePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  /// .aes dosyasının tam yolu
  final String aesFilePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  ConsumerState<EncryptedImageWidget> createState() => _EncryptedImageWidgetState();
}

class _EncryptedImageWidgetState extends ConsumerState<EncryptedImageWidget> {
  /// RAM'deki çözülmüş bytes — dispose'da sıfırlanacak
  Uint8List? _plaintextBytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAndDecrypt();
  }

  @override
  void dispose() {
    // ✅ ZERO-LEAK: Widget kapanırken plaintext bytes'ı RAM'den sıfırla
    if (_plaintextBytes != null) {
      CryptoService.zeroFill(_plaintextBytes!);
      _plaintextBytes = null;
    }
    super.dispose();
  }

  Future<void> _loadAndDecrypt() async {
    try {
      final storage = ref.read(mediaStorageServiceProvider);
      // RAM'de çöz — diske asla yazma
      final bytes = await storage.loadAndDecrypt(widget.aesFilePath);
      if (mounted) {
        setState(() {
          _plaintextBytes = bytes;
          _loading = false;
        });
      } else {
        // Widget dispose edilmişse bytes'ı hemen sıfırla
        CryptoService.zeroFill(bytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.placeholder ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(child: CircularProgressIndicator()),
          );
    }

    if (_error != null) {
      return widget.errorWidget ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
          );
    }

    // ✅ Image.memory → plaintext ASLA diske gitmez
    return Image.memory(
      _plaintextBytes!,
      width:  widget.width,
      height: widget.height,
      fit:    widget.fit,
      // gaplessPlayback: true — önceki frame görünmeye devam eder yüklenirken
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          widget.errorWidget ??
          const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EncryptedThumbnailWidget — Listelerde küçük önizleme için
//  Daha az bellek: 150x150 decode limit
// ─────────────────────────────────────────────────────────────────────────────
class EncryptedThumbnailWidget extends ConsumerStatefulWidget {
  const EncryptedThumbnailWidget({
    super.key,
    required this.aesFilePath,
    this.size = 60,
    this.borderRadius = 8,
  });

  final String aesFilePath;
  final double size;
  final double borderRadius;

  @override
  ConsumerState<EncryptedThumbnailWidget> createState() => _EncryptedThumbnailWidgetState();
}

class _EncryptedThumbnailWidgetState extends ConsumerState<EncryptedThumbnailWidget> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_bytes != null) {
      CryptoService.zeroFill(_bytes!);
      _bytes = null;
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final storage = ref.read(mediaStorageServiceProvider);
      final bytes = await storage.loadAndDecrypt(widget.aesFilePath);
      if (mounted) {
        setState(() { _bytes = bytes; _loading = false; });
      } else {
        CryptoService.zeroFill(bytes);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _loading
            ? const ColoredBox(color: Color(0xFF251535))
            : _bytes == null
                ? const Icon(Icons.broken_image, color: Colors.grey)
                : Image.memory(
                    _bytes!,
                    fit: BoxFit.cover,
                    cacheWidth:  150,  // decode limit → daha az RAM
                    cacheHeight: 150,
                    gaplessPlayback: true,
                  ),
      ),
    );
  }
}
