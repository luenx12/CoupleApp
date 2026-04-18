// ═══════════════════════════════════════════════════════════════════════════════
// 🔦 Dark Room Widget — Karanlık Oda (Spotlight & Live Heatmap)
// Can alıcı modül: Partner'ın gönderdiği şifreli kare tamamen karanlık.
// Parmakla "el feneri" sürükleyerek keşfedersin.
// Partner kendi ekranında senin ısı haritanı görür.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/red_room_notifier.dart';
import '../../../../core/theme/app_theme.dart';

// Spotlight yarıçapı (dp)
const _kSpotRadius = 80.0;

class DarkRoomWidget extends ConsumerStatefulWidget {
  const DarkRoomWidget({super.key});

  @override
  ConsumerState<DarkRoomWidget> createState() => _DarkRoomWidgetState();
}

class _DarkRoomWidgetState extends ConsumerState<DarkRoomWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  Offset? _spotlightPos;          // Yerel parmak konumu (px)
  Offset? _partnerSpotlight;      // Partner'ın normalize konumu (0-1)
  final List<Offset> _heatPoints = []; // Isı haritası nokta listesi

  static const _heatmapSendInterval = Duration(milliseconds: 500);
  DateTime _lastHeatmapSend = DateTime.fromMillisecondsSinceEpoch(0);

  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final nx = d.localPosition.dx / _canvasSize.width;
    final ny = d.localPosition.dy / _canvasSize.height;

    setState(() => _spotlightPos = d.localPosition);
    _heatPoints.add(d.localPosition);

    // Spotlgiht → partner'a düşük gecikmeli gönder
    ref.read(redRoomNotifierProvider.notifier).sendSpotlightMove(nx.clamp(0, 1), ny.clamp(0, 1));

    // Heatmap'ı 500ms'de bir toplu gönder
    final now = DateTime.now();
    if (now.difference(_lastHeatmapSend) >= _heatmapSendInterval) {
      _lastHeatmapSend = now;
      // (fire and forget — no await needed in gesture callback)
    }
  }

  void _onPanEnd(DragEndDetails _) {
    // Parmak kaldırıldığında spotlight kaybolsun
    setState(() => _spotlightPos = null);
  }

  void _startSession() {
    HapticFeedback.heavyImpact();
    _fadeController.forward(from: 0);
    ref.read(redRoomNotifierProvider.notifier).startDarkRoom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(redRoomNotifierProvider);

    // Partner'ın spotlight konumunu takip et
    ref.listen<RedRoomState>(redRoomNotifierProvider, (prev, next) {
      if (next.spotlightX != null && next.spotlightY != null) {
        setState(() {
          _partnerSpotlight = Offset(
            (next.spotlightX! * _canvasSize.width).clamp(0, _canvasSize.width),
            (next.spotlightY! * _canvasSize.height).clamp(0, _canvasSize.height),
          );
        });
      }
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.red.withOpacity(0.08), blurRadius: 30),
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
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🔦', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Karanlık Oda',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('Parmağınla el feneri sür, keşfet...', style:
                      TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!state.isDarkRoomActive)
            _IdlePanel(onStart: _startSession)
          else ...[
            // Karanlık canvas
            LayoutBuilder(builder: (context, constraints) {
              _canvasSize = Size(constraints.maxWidth, 260);
              return GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: 260,
                    child: Stack(
                      children: [
                        // Siyah zemin
                        Container(color: Colors.black),

                        // Gizli içerik (sembolik — gerçekte DecryptedImage olur)
                        Positioned.fill(
                          child: FadeTransition(
                            opacity: _fadeAnim,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: const Alignment(0, -0.2),
                                  radius: 0.9,
                                  colors: [
                                    AppColors.primary.withOpacity(0.08),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: Text('❤️‍🔥',
                                    style: TextStyle(fontSize: 80, color: Colors.transparent)),
                              ),
                            ),
                          ),
                        ),

                        // Karanlık örtü (spotlight'sız siyah)
                        CustomPaint(
                          size: Size(constraints.maxWidth, 260),
                          painter: _DarknessOverlayPainter(
                            spotlightPos: _spotlightPos,
                            radius: _kSpotRadius,
                          ),
                        ),

                        // Partner spotlight (farklı renk)
                        if (_partnerSpotlight != null)
                          CustomPaint(
                            size: Size(constraints.maxWidth, 260),
                            painter: _PartnerSpotlightPainter(pos: _partnerSpotlight!),
                          ),

                        // Isı haritası
                        if (_heatPoints.isNotEmpty)
                          CustomPaint(
                            size: Size(constraints.maxWidth, 260),
                            painter: _HeatmapPainter(points: List.from(_heatPoints)),
                          ),

                        // Spotlight yok — ipucu
                        if (_spotlightPos == null)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('☝️', style: TextStyle(fontSize: 36)),
                                const SizedBox(height: 8),
                                Text('Parmağını sürükle — karanlığı aydınlat',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.3),
                                        fontSize: 12)),
                              ],
                            ),
                          ),

                        // Safe word kısayolu
                        Positioned(
                          top: 8, right: 8,
                          child: GestureDetector(
                            onLongPress: () =>
                                ref.read(redRoomNotifierProvider.notifier).triggerSafeWord(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.red.withOpacity(0.4)),
                              ),
                              child: const Text('KIRMIZI',
                                  style: TextStyle(color: Colors.red, fontSize: 9,
                                      fontWeight: FontWeight.w800, letterSpacing: 1)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Isı haritası istatistikleri
            Row(
              children: [
                const Icon(Icons.thermostat_rounded, color: Colors.deepOrangeAccent, size: 16),
                const SizedBox(width: 6),
                Text('${_heatPoints.length} nokta keşfedildi',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _heatPoints.clear());
                    ref.read(redRoomNotifierProvider.notifier).closeDarkRoom();
                  },
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white38),
                  label: const Text('Kapat', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Idle Panel ─────────────────────────────────────────────────────────────────

class _IdlePanel extends StatelessWidget {
  final VoidCallback onStart;
  const _IdlePanel({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔦', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Partnerin bir kare yolladığında,\nekran karanlık olur — sen keşfedersin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
            label: const Text('DEMO: Karanlık Modu Başlat',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.08),
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.15)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Karanlık örtü boyacısı ────────────────────────────────────────────────────

class _DarknessOverlayPainter extends CustomPainter {
  final Offset? spotlightPos;
  final double radius;

  _DarknessOverlayPainter({this.spotlightPos, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    if (spotlightPos == null) {
      // Tüm alanı siyah yap
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black.withOpacity(0.97),
      );
      return;
    }

    // Spotlight deliği olan maske
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final spotPath = Path()
      ..addOval(Rect.fromCircle(center: spotlightPos!, radius: radius));

    final darkPath = Path.combine(PathOperation.difference, path, spotPath);

    canvas.drawPath(darkPath, Paint()..color = Colors.black.withOpacity(0.97));

    // Spotlight kenar glow
    canvas.drawCircle(
      spotlightPos!,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  @override
  bool shouldRepaint(_DarknessOverlayPainter old) =>
      old.spotlightPos != spotlightPos;
}

// ── Partner spotlight boyacısı ────────────────────────────────────────────────

class _PartnerSpotlightPainter extends CustomPainter {
  final Offset pos;
  _PartnerSpotlightPainter({required this.pos});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      pos,
      20,
      Paint()
        ..color = AppColors.primary.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );
    canvas.drawCircle(
      pos,
      8,
      Paint()..color = AppColors.primary.withOpacity(0.8),
    );
  }

  @override
  bool shouldRepaint(_PartnerSpotlightPainter old) => old.pos != pos;
}

// ── Isı haritası boyacısı ─────────────────────────────────────────────────────

class _HeatmapPainter extends CustomPainter {
  final List<Offset> points;
  _HeatmapPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in points) {
      canvas.drawCircle(
        p,
        18,
        Paint()
          ..color = Colors.deepOrange.withOpacity(0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.points.length != points.length;
}
