// ═══════════════════════════════════════════════════════════════════════════════
// 📸 Snapshot Roulette Widget
// Çark döner, bölge çıkar → anlık fotoğraf çekip partnere yollanır.
// 3 saniye sonra medya imha edilir.
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../domain/red_room_notifier.dart';
import '../../../crypto/crypto_provider.dart';
import '../../../crypto/crypto_service.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/games_notifier.dart';
import '../../../../core/theme/app_theme.dart';

const _zoneEmoji = <String, String>{
  'Dudaklar': '👄',
  'Boyun': '🦢',
  'Göğüz Dekoltesi': '💎',
  'Bacaklar': '🦵',
  'Bel Kavisi': '〰️',
  'Gözler': '👁️',
  'İstediğin Bir Yer': '🎯',
  'Omuzlar': '🤷',
  'El & Parmaklar': '🤚',
  'Kalçalar': '🍑',
  'Minnnak': '🤏',
  'Ağzının İçi': '👄',
  'İç Çamaşırın': '👙',
  'Sırt': '🫲',
  'Ayaklar': '🦶',
  'Bacak Arası': '🦵',
  'Çıplak Vücudun': '👙',
};

const _zoneColors = <String, Color>{
  'Dudaklar': Color(0xFFFF4D8B),
  'Boyun': Color(0xFFBB86FC),
  'Göğüs Dekoltesi': Color(0xFFFF6B35),
  'Bacaklar': Color(0xFF00BCD4),
  'Bel Kavisi': Color(0xFFFF9800),
  'Gözler': Color(0xFF4CAF50),
  'İstediğin Bir Yer': Color(0xFFE91E8C),
  'Omuzlar': Color(0xFF2196F3),
  'El & Parmaklar': Color(0xFF9C27B0),
  'Kalçalar': Color(0xFF9C27B0),
  'Minnnak': Color(0xFF9C27B0),
  'Ağzının İçi': Color(0xFF9C27B0),
  'İç Çamaşırın': Color(0xFF9C27B0),
  'Sırt': Color(0xFF9C27B0),
  'Ayaklar': Color(0xFF9C27B0),
  'Bacak Arası': Color(0xFF9C27B0),
  'Çıplak Vücudun': Color(0xFF9C27B0),
};

// Çark dilimleri
final _wheelSegments = _zoneEmoji.keys.toList();

class SnapshotRouletteWidget extends ConsumerStatefulWidget {
  const SnapshotRouletteWidget({super.key});

  @override
  ConsumerState<SnapshotRouletteWidget> createState() =>
      _SnapshotRouletteWidgetState();
}

class _SnapshotRouletteWidgetState extends ConsumerState<SnapshotRouletteWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _spinAnim;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _spinAnim =
        CurvedAnimation(parent: _spinController, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    HapticFeedback.heavyImpact();
    _spinController.reset();
    _spinController.forward();
    await ref.read(redRoomNotifierProvider.notifier).spinRoulette();
  }

  Future<void> _captureAndSend(String zone) async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 70);

    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      final crypto = ref.read(cryptoServiceProvider);
      final auth = ref.read(authNotifierProvider);

      final partnerPubPem = auth.partnerPublicKey;
      if (partnerPubPem == null || partnerPubPem.isEmpty) {
        throw Exception(
            "Partnerin henüz giriş yapmamış veya eşleşme tamamlanmamış.");
      }

      if (!crypto.isReady) {
        throw Exception("Kripto servisi hazır değil.");
      }

      final payload = crypto.encrypt(bytes, partnerPubPem);
      CryptoService.zeroFill(bytes);

      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) throw Exception("Oturum süresi doldu.");

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/api/Media/upload'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        payload.toBytes(),
        filename: 'encrypted_roulette.aes',
      ));

      final streamed = await request.send();
      final respStr = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final decoded = jsonDecode(respStr) as Map<String, dynamic>;
        final realMediaId = decoded['mediaId'] as String? ??
            "redroom_${DateTime.now().millisecondsSinceEpoch}";

        await ref
            .read(gamesNotifierProvider.notifier)
            .sendRedRoomMediaTask(realMediaId, 5); // 5 saniye

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("📸 Fotoğraf şifrelenip partnerine gönderildi!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Upload failed: $respStr");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: $e"),
            backgroundColor: Colors.red[900],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(redRoomNotifierProvider);
    final result = state.rouletteResult;

    ref.listen<RedRoomState>(redRoomNotifierProvider, (prev, next) {
      if (next.rouletteResult != null &&
          next.rouletteResult != prev?.rouletteResult) {
        _spinController.forward(from: 0);
        HapticFeedback.heavyImpact();
      }
    });

    final zoneColor = result != null
        ? (_zoneColors[result.zone] ?? AppColors.primary)
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF001A0D), Color(0xFF00330A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: const Color(0xFF00FF88).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF00FF88).withOpacity(0.1), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('📸', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Snapshot Roulette',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  Text('Bölge çıkar → çek → 3 sn sonra imha!',
                      style: TextStyle(color: Color(0xFF69FF96), fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Çark
          AnimatedBuilder(
            animation: _spinAnim,
            builder: (_, child) => Transform.rotate(
              angle: _spinAnim.value * 4 * math.pi,
              child: child,
            ),
            child: SizedBox(
              width: 180,
              height: 180,
              child: CustomPaint(
                  painter: _WheelPainter(
                      segments: _wheelSegments, zoneColors: _zoneColors)),
            ),
          ),

          const SizedBox(height: 20),

          // Zone Result
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: result != null
                ? _ZoneResult(
                    result: result,
                    color: zoneColor,
                    onSendPhoto: () => _captureAndSend(result.zone),
                  )
                : const _ZonePlaceholder(),
          ),

          const SizedBox(height: 20),

          // Spin Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isSpinning ? null : _spin,
              icon: state.isSpinning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('🎡', style: TextStyle(fontSize: 18)),
              label: Text(
                state.isSpinning ? 'Çark Dönüyor...' : 'RULETA ÇEVİR',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: const Color(0xFF00FF88).withOpacity(0.5),
              ),
            ),
          ),

          if (result != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, color: Colors.redAccent, size: 14),
                  SizedBox(width: 6),
                  Text('Görsel 3 saniye sonra otomatik imha edilir',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Çark boyacısı ─────────────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  final List<String> segments;
  final Map<String, Color> zoneColors;

  _WheelPainter({required this.segments, required this.zoneColors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segAngle = 2 * math.pi / segments.length;

    for (int i = 0; i < segments.length; i++) {
      final startAngle = i * segAngle - math.pi / 2;
      final color = (zoneColors[segments[i]] ?? Colors.grey).withOpacity(0.85);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segAngle - 0.04,
        true,
        paint,
      );

      // Emoji label
      final textPainter = TextPainter(
        text: TextSpan(
          text: _zoneEmoji[segments[i]] ?? '•',
          style: const TextStyle(fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final angle = startAngle + segAngle / 2;
      final labelRadius = radius * 0.68;
      canvas.save();
      canvas.translate(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );
      textPainter.paint(
          canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    // Merkez daire
    canvas.drawCircle(center, 16, Paint()..color = Colors.black87);
    canvas.drawCircle(
        center,
        14,
        Paint()
          ..color = const Color(0xFF00FF88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => false;
}

// ── Zone Result ───────────────────────────────────────────────────────────────

class _ZoneResult extends StatelessWidget {
  final RouletteResult result;
  final Color color;
  final VoidCallback onSendPhoto;

  const _ZoneResult(
      {required this.result, required this.color, required this.onSendPhoto});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(result.zone),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_zoneEmoji[result.zone] ?? '🎯',
              style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BÖLGEN:',
                  style: TextStyle(
                      color: Colors.white38, fontSize: 10, letterSpacing: 1)),
              Text(result.zone,
                  style: TextStyle(
                      color: color, fontSize: 22, fontWeight: FontWeight.w900)),
              const Text('Çek & Gönder!',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onSendPhoto,
                icon: const Icon(Icons.camera_alt, size: 16),
                label: const Text("FOTOĞRAF GÖNDER",
                    style:
                        TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZonePlaceholder extends StatelessWidget {
  const _ZonePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('placeholder'),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🎡', style: TextStyle(fontSize: 28)),
          SizedBox(width: 12),
          Text('Çevirince bölgen belirlenir...',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}
