// ═══════════════════════════════════════════════════════════════════════════════
// MediaBubble — Self-destruct encrypted image bubble
//
// Kurallar:
//   • Görüntü RAM'de çözülür (EncryptedImageWidget gibi)
//   • İlk görüntülendiği an backend'e DELETE isteği atılır (self-destruct 🔥)
//   • Silindikten sonra "🔥 Fotoğraf silindi" placeholder gösterilir
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../media/media_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/message_model.dart';
import '../../../features/crypto/crypto_service.dart';

class MediaBubble extends ConsumerStatefulWidget {
  const MediaBubble({
    super.key,
    required this.message,
    required this.onViewed,
    required this.onDownloadRequest,
  });

  final MessageModel message;
  final VoidCallback onViewed;
  final Future<String?> Function() onDownloadRequest;

  @override
  ConsumerState<MediaBubble> createState() => _MediaBubbleState();
}

class _MediaBubbleState extends ConsumerState<MediaBubble>
    with SingleTickerProviderStateMixin {
  Uint8List? _bytes;
  bool _loading = false;
  bool _viewed  = false;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    if (widget.message.mediaDeleted) {
      _viewed = true;
    } else if (widget.message.localMediaPath != null) {
      _loadLocal();
    }
    // Gönderenin kendi mesajında .aes zaten var
    if (widget.message.isMine && widget.message.localMediaPath != null) {
      _loadLocal();
    }
  }

  @override
  void dispose() {
    if (_bytes != null) {
      CryptoService.zeroFill(_bytes!);
      _bytes = null;
    }
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocal() async {
    if (_bytes != null || _loading || widget.message.localMediaPath == null) return;
    setState(() => _loading = true);
    try {
      final storage = ref.read(mediaStorageServiceProvider);
      final bytes   = await storage.loadAndDecrypt(widget.message.localMediaPath!);
      if (mounted) setState(() { _bytes = bytes; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onTap() async {
    if (widget.message.mediaDeleted) return;

    // İlk tıklamada indir
    if (widget.message.localMediaPath == null) {
      setState(() => _loading = true);
      final path = await widget.onDownloadRequest();
      if (path != null && mounted) {
        await _loadLocal();
      } else {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    if (_bytes == null) {
      await _loadLocal();
      return;
    }

    // Tam ekran göster
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(220),
      builder: (_) => _FullscreenImageDialog(
        bytes: _bytes!,
        onClose: () {
          Navigator.of(context).pop();
          if (!_viewed && !widget.message.isMine) {
            _triggerSelfDestruct();
          }
        },
      ),
    );
  }

  void _triggerSelfDestruct() {
    _viewed = true;
    // Fade-out animasyonu
    _fadeCtrl.forward();
    // Callback → backend DELETE
    widget.onViewed();
    // RAM'i temizle
    if (_bytes != null) {
      CryptoService.zeroFill(_bytes!);
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMine = widget.message.isMine;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left:  isMine ? 64 : 12,
          right: isMine ? 12 : 64,
          top:   2,
          bottom: 2,
        ),
        child: GestureDetector(
          onTap: _onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 200,
              height: 200,
              child: _buildContent(),
            ),
          ),
        ),
      ),
    ).animate().slideX(
      begin: isMine ? 0.3 : -0.3,
      duration: 280.ms,
      curve: Curves.easeOutCubic,
    ).fadeIn(duration: 200.ms);
  }

  Widget _buildContent() {
    // Silindi
    if (widget.message.mediaDeleted || _viewed) {
      return _DeletedPlaceholder();
    }

    // Yükleniyor
    if (_loading) {
      return Container(
        color: AppColors.card,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // İndirilmedi henüz (alıcı tarafı)
    if (_bytes == null && !widget.message.isMine) {
      return _DownloadPlaceholder();
    }

    // Gönderen kendi görmüyor
    if (_bytes == null) {
      return Container(
        color: AppColors.card,
        child: const Center(
          child: Icon(Icons.image_rounded, color: AppColors.onSurfaceMuted, size: 48),
        ),
      );
    }

    // Görüntü göster + fade animasyonu
    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_bytes!, fit: BoxFit.cover),
          // Self-destruct rozeti
          if (!widget.message.isMine)
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🔥', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 4),
                    Text('1×', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Placeholders ──────────────────────────────────────────────────────────────

class _DeletedPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            'Fotoğraf silindi',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DownloadPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.download_rounded, color: AppColors.primary, size: 40),
          const SizedBox(height: 8),
          const Text('🔥', style: TextStyle(fontSize: 16)),
          Text(
            'Görüntülemek için dokun',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Fullscreen dialog ─────────────────────────────────────────────────────────

class _FullscreenImageDialog extends StatelessWidget {
  const _FullscreenImageDialog({required this.bytes, required this.onClose});
  final Uint8List bytes;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.memory(bytes),
              ),
            ),
            Positioned(
              top: 48, right: 16,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
            const Positioned(
              bottom: 60,
              left: 0, right: 0,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '🔥 Bu fotoğraf kapatıldığında sunucudan kalıcı silecek',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
