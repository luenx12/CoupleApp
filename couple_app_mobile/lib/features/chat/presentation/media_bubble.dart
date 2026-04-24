// ═══════════════════════════════════════════════════════════════════════════════
// MediaBubble v2 — Encrypted media bubble (image + video)
//
// Değişiklikler:
//   • Alıcı tarafında mount anında otomatik indir (tıklama bekleme yok)
//   • İndirme sırasında ilerleme çubuğu göster
//   • Retry mekanizması (3 deneme, exponential backoff)
//   • Gönderen kendi görselini sorunsuz görür (self AES)
//   • RAM'den self-destruct: görüntüleme sonrası bytes sıfırla
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/crypto/crypto_service.dart';
import '../../media/media_provider.dart';
import '../domain/message_model.dart';

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
  double? _downloadProgress; // null = not downloading, 0.0–1.0 = progress
  String? _errorMsg;
  int _retryCount = 0;
  static const _maxRetries = 3;

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
      return;
    }

    if (widget.message.localMediaPath != null) {
      // Dosya zaten diskte — direkt yükle (gönderen veya daha önce indirilen)
      _loadLocal();
    } else if (!widget.message.isMine) {
      // Alıcı tarafında: uygulama açılınca otomatik indir
      _autoDownload();
    }
  }

  @override
  void dispose() {
    _zeroBytes();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _zeroBytes() {
    if (_bytes != null) {
      CryptoService.zeroFill(_bytes!);
      _bytes = null;
    }
  }

  // ── Otomatik indir (alıcı, mount anında) ────────────────────────────────────
  Future<void> _autoDownload() async {
    if (_loading || _bytes != null) return;
    if (!mounted) return;

    setState(() {
      _loading = true;
      _downloadProgress = 0.0;
      _errorMsg = null;
    });

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      if (!mounted) return;
      try {
        // Simule progress (gerçek streaming yoksa 0→0.9 animasyonu)
        _simulateProgress();
        final path = await widget.onDownloadRequest();
        if (!mounted) return;
        if (path != null) {
          await _loadLocal();
          if (mounted) {
            setState(() {
              _downloadProgress = null;
              _errorMsg = null;
            });
          }
          return;
        }
      } catch (_) {
        if (attempt < _maxRetries - 1) {
          final waitMs = 1000 * (1 << attempt); // 1s, 2s, 4s
          await Future.delayed(Duration(milliseconds: waitMs));
        }
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _downloadProgress = null;
        _errorMsg = 'İndirilemedi. Dokun, tekrar dene.';
        _retryCount++;
      });
    }
  }

  void _simulateProgress() {
    const steps = [0.1, 0.3, 0.55, 0.75, 0.9];
    int i = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted || _downloadProgress == null) return false;
      if (i < steps.length) {
        if (mounted) setState(() => _downloadProgress = steps[i]);
        i++;
        return true;
      }
      return false;
    });
  }

  // ── Yerel AES dosyasını yükle ve çöz ────────────────────────────────────────
  Future<void> _loadLocal() async {
    if (_bytes != null) return; // zaten yüklü
    if (widget.message.localMediaPath == null) return;
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final storage = ref.read(mediaStorageServiceProvider);
      final bytes   = await storage.loadAndDecrypt(widget.message.localMediaPath!);
      if (mounted) {
        setState(() {
          _bytes   = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading  = false;
          _errorMsg = 'Fotoğraf açılamadı.';
        });
      }
    }
  }

  // ── Tap → tam ekran ──────────────────────────────────────────────────────────
  Future<void> _onTap() async {
    if (widget.message.mediaDeleted || _viewed) return;

    // Hata durumunda tekrar indir
    if (_errorMsg != null && widget.message.localMediaPath == null) {
      setState(() => _errorMsg = null);
      await _autoDownload();
      return;
    }

    // Henüz yüklenmemişse bekle
    if (_loading) return;

    if (_bytes == null) {
      await _loadLocal();
      if (_bytes == null) return;
    }

    if (!mounted) return;

    final isVideo = _isVideo(_bytes!);
    await showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(220),
      builder: (_) => isVideo
          ? _FullscreenVideoDialog(
              bytes: _bytes!,
              onClose: () {
                Navigator.of(context).pop();
                if (!_viewed && !widget.message.isMine) _triggerSelfDestruct();
              },
            )
          : _FullscreenImageDialog(
              bytes: _bytes!,
              onClose: () {
                Navigator.of(context).pop();
                if (!_viewed && !widget.message.isMine) _triggerSelfDestruct();
              },
            ),
    );
  }

  void _triggerSelfDestruct() {
    _viewed = true;
    _fadeCtrl.forward();
    widget.onViewed();
    _zeroBytes();
  }

  bool _isVideo(Uint8List bytes) {
    if (bytes.length < 12) return false;
    // MP4 (ftyp box)
    if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) return true;
    // MOV (moov box)
    if (bytes[4] == 0x6D && bytes[5] == 0x6F && bytes[6] == 0x6F && bytes[7] == 0x76) return true;
    // WEBM
    if (bytes[0] == 0x1A && bytes[1] == 0x45 && bytes[2] == 0xDF && bytes[3] == 0xA3) return true;
    return false;
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMine = widget.message.isMine;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left:   isMine ? 64 : 12,
          right:  isMine ? 12 : 64,
          top:    2,
          bottom: 2,
        ),
        child: GestureDetector(
          onTap: _onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 210,
              height: 210,
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
    // ── Silindi
    if (widget.message.mediaDeleted || _viewed) {
      return _DeletedPlaceholder();
    }

    // ── Hata
    if (_errorMsg != null && !_loading) {
      return _ErrorPlaceholder(
        message: _errorMsg!,
        onRetry: () { setState(() => _errorMsg = null); _autoDownload(); },
      );
    }

    // ── İndiriliyor
    if (_loading || _downloadProgress != null) {
      return Container(
        color: AppColors.card,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: _downloadProgress,
                      strokeWidth: 3,
                      color: AppColors.primary,
                      backgroundColor: AppColors.primary.withAlpha(40),
                    ),
                    const Center(
                      child: Icon(Icons.download_rounded, color: AppColors.primary, size: 22),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _downloadProgress != null
                    ? '%${((_downloadProgress ?? 0) * 100).round()}'
                    : 'Hazırlanıyor…',
                style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // ── Henüz indirilmedi (nadir: sadece otomatik indir başarısız olduysa)
    if (_bytes == null && !widget.message.isMine) {
      return _DownloadPlaceholder(onTap: _autoDownload);
    }

    // ── Gönderen — görsel yok (indirme gerekmiyor ama AES yoksa)
    if (_bytes == null) {
      return Container(
        color: AppColors.card,
        child: const Center(
          child: Icon(Icons.image_rounded, color: AppColors.onSurfaceMuted, size: 48),
        ),
      );
    }

    // ── Göster
    final isVideo = _isVideo(_bytes!);
    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isVideo)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 52),
              ),
            )
          else
            Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true),
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
  Widget build(BuildContext context) => Container(
    color: AppColors.card,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🔥', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text('Fotoğraf silindi',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
      ],
    ),
  );
}

class _DownloadPlaceholder extends StatelessWidget {
  const _DownloadPlaceholder({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      color: AppColors.card,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.download_rounded, color: AppColors.primary, size: 40),
          const SizedBox(height: 8),
          Text('Yeniden indir',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onRetry,
    child: Container(
      color: AppColors.card,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 36),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ── Fullscreen Image ─────────────────────────────────────────────────────────

class _FullscreenImageDialog extends StatelessWidget {
  const _FullscreenImageDialog({required this.bytes, required this.onClose});
  final Uint8List bytes;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          GestureDetector(
            onTap: onClose,
            child: Center(
              child: InteractiveViewer(
                child: Image.memory(bytes),
              ),
            ),
          ),
          Positioned(
            top: 48, right: 16,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
          ),
          const Positioned(
            bottom: 60, left: 0, right: 0,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '🔥 Bu fotoğraf kapatıldığında sunucudan kalıcı silinecek',
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
    );
  }
}

// ── Fullscreen Video ─────────────────────────────────────────────────────────

class _FullscreenVideoDialog extends StatefulWidget {
  const _FullscreenVideoDialog({required this.bytes, required this.onClose});
  final Uint8List bytes;
  final VoidCallback onClose;

  @override
  State<_FullscreenVideoDialog> createState() => _FullscreenVideoDialogState();
}

class _FullscreenVideoDialogState extends State<_FullscreenVideoDialog> {
  VideoPlayerController? _controller;
  File? _tempFile;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final dir      = await getTemporaryDirectory();
    final tempPath = '${dir.path}/tmp_vid_${DateTime.now().millisecondsSinceEpoch}.mp4';
    _tempFile = File(tempPath);
    await _tempFile!.writeAsBytes(widget.bytes, flush: true);

    _controller = VideoPlayerController.file(_tempFile!)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller!.play();
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (_tempFile != null && _tempFile!.existsSync()) {
      _tempFile!.deleteSync();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          GestureDetector(
            onTap: widget.onClose,
            child: Center(
              child: _initialized && _controller != null
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          VideoPlayer(_controller!),
                          VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          Positioned(
            top: 48, right: 16,
            child: IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
          ),
          const Positioned(
            bottom: 60, left: 0, right: 0,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '🔥 Bu video kapatıldığında sunucudan kalıcı silinecek',
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
    );
  }
}
