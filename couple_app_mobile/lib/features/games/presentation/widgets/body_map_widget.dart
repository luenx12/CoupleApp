// ═══════════════════════════════════════════════════════════════════════════════
// 🧭 Body Map Widget — Vücut Haritası Erojen Bölge İşaretleme
// Kullanıcı kendi silueti üzerinde noktalar işaretler → partnere gönderir.
// Zero-Leak: sunucu içeriğe bakmaz, sadece şifreli JSON iletir.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/red_room_notifier.dart';
import '../../../../core/theme/app_theme.dart';

// ── Vücut bölge etiketleri ve konumları (normalize 0-1) ─────────────────────
// Bölgeler arka plana referans vücuda göre hizalandı
const _bodySuggestions = <String, Offset>{
  'Baş':        Offset(0.50, 0.05),
  'Boyun':      Offset(0.50, 0.12),
  'Omuz-Sol':   Offset(0.35, 0.20),
  'Omuz-Sağ':   Offset(0.65, 0.20),
  'Göğüs':      Offset(0.50, 0.28),
  'Bel':        Offset(0.50, 0.43),
  'Kalça-Sol':  Offset(0.40, 0.55),
  'Kalça-Sağ':  Offset(0.60, 0.55),
  'Uyluk-Sol':  Offset(0.38, 0.68),
  'Uyluk-Sağ':  Offset(0.62, 0.68),
  'Diz-Sol':    Offset(0.38, 0.80),
  'Diz-Sağ':    Offset(0.62, 0.80),
};

class BodyMapWidget extends ConsumerStatefulWidget {
  const BodyMapWidget({super.key});

  @override
  ConsumerState<BodyMapWidget> createState() => _BodyMapWidgetState();
}

class _BodyMapWidgetState extends ConsumerState<BodyMapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _sendController;
  final List<_BodyPoint> _points = [];
  bool _showPartnerMap  = false;
  bool _isSending       = false;

  @override
  void initState() {
    super.initState();
    _sendController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _sendController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details, BoxConstraints constraints) {
    final dx = details.localPosition.dx / constraints.maxWidth;
    final dy = details.localPosition.dy / constraints.maxHeight;
    final label = _nearestLabel(dx, dy);
    HapticFeedback.selectionClick();
    setState(() {
      _points.add(_BodyPoint(x: dx, y: dy, label: label));
    });
  }

  String _nearestLabel(double x, double y) {
    String best = 'Özel Bölge';
    double bestDist = double.infinity;
    for (final entry in _bodySuggestions.entries) {
      final d = (entry.value.dx - x).abs() + (entry.value.dy - y).abs();
      if (d < bestDist) {
        bestDist = d;
        best = entry.key;
      }
    }
    return best;
  }

  Future<void> _sendMap() async {
    if (_points.isEmpty) return;
    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();
    final mapData = _points.map((p) => {
      'x': p.x,
      'y': p.y,
      'label': p.label,
    }).toList();

    await ref.read(redRoomNotifierProvider.notifier).sendBodyMap(mapData);
    setState(() => _isSending = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🧭 Vücut haritası partnerine gönderildi!'),
          backgroundColor: Color(0xFF00BCD4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearPoints() {
    setState(() => _points.clear());
    ref.read(redRoomNotifierProvider.notifier).clearBodyMap();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(redRoomNotifierProvider);
    final partnerPoints = state.partnerBodyMapPoints;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00101A), Color(0xFF001A33)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00BCD4).withOpacity(0.12), blurRadius: 20),
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
                  color: const Color(0xFF00BCD4).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🧭', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vücut Haritası',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('Dokunulmasını istediğin yerleri işaretle',
                      style: TextStyle(color: Color(0xFF4DD0E1), fontSize: 11)),
                ],
              ),
              const Spacer(),
              // Benim / Partner toggle
              GestureDetector(
                onTap: () => setState(() => _showPartnerMap = !_showPartnerMap),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _showPartnerMap
                        ? AppColors.primary.withOpacity(0.2)
                        : const Color(0xFF00BCD4).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _showPartnerMap ? AppColors.primary : const Color(0xFF00BCD4),
                    ),
                  ),
                  child: Text(
                    _showPartnerMap ? '💑 Partner' : '🙋 Ben',
                    style: TextStyle(
                      color: _showPartnerMap ? AppColors.primary : const Color(0xFF00BCD4),
                      fontSize: 11, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Harita alanı
          LayoutBuilder(
            builder: (context, constraints) {
              final points = _showPartnerMap
                  ? partnerPoints.map((p) => _BodyPoint(
                      x: (p['x'] as num).toDouble(),
                      y: (p['y'] as num).toDouble(),
                      label: p['label']?.toString() ?? '')).toList()
                  : _points;

              return GestureDetector(
                onTapDown: _showPartnerMap
                    ? null
                    : (d) => _onTapDown(d, constraints),
                child: Container(
                  width: double.infinity,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _showPartnerMap
                          ? AppColors.primary.withOpacity(0.4)
                          : const Color(0xFF00BCD4).withOpacity(0.3),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Arka plan silüet
                      Center(
                        child: Opacity(
                          opacity: 0.12,
                          child: Icon(
                            Icons.accessibility_new_rounded,
                            size: 220,
                            color: _showPartnerMap ? AppColors.primary : const Color(0xFF00BCD4),
                          ),
                        ),
                      ),

                      // Yardımcı etiketler (sadece kendi haritamda)
                      if (!_showPartnerMap && _points.isEmpty)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('👆', style: TextStyle(fontSize: 32)),
                              const SizedBox(height: 8),
                              Text(
                                'Silüetin üzerine dokun\nbölgeler otomatik etiketlenir',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                      // Nokta işaretleri
                      ...points.map((p) => _BodyDot(
                        point: p,
                        isPartner: _showPartnerMap,
                        containerSize: Size(constraints.maxWidth, 280),
                      )),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Nokta sayısı + butonlar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                ),
                child: Text(
                  '${_points.length} nokta işaretlendi',
                  style: const TextStyle(color: Color(0xFF4DD0E1), fontSize: 12),
                ),
              ),
              const Spacer(),
              if (_points.isNotEmpty) ...[
                IconButton(
                  onPressed: _clearPoints,
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                  tooltip: 'Temizle',
                ),
                const SizedBox(width: 4),
              ],
              ElevatedButton.icon(
                onPressed: (_points.isEmpty || _isSending) ? null : _sendMap,
                icon: _isSending
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(_isSending ? 'Gönderiliyor...' : 'Gönder',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),

          // Partner haritası var mı?
          if (partnerPoints.isNotEmpty && !_showPartnerMap) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _showPartnerMap = true),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite, color: Color(0xFFFF4D8B), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Partnerin ${partnerPoints.length} bölge işaretledi — Görmek için dokun!',
                      style: const TextStyle(color: Color(0xFFFF4D8B), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Veri sınıfı ───────────────────────────────────────────────────────────────

class _BodyPoint {
  final double x;
  final double y;
  final String label;
  const _BodyPoint({required this.x, required this.y, required this.label});
}

// ── Nokta widget'ı ────────────────────────────────────────────────────────────

class _BodyDot extends StatefulWidget {
  final _BodyPoint point;
  final bool isPartner;
  final Size containerSize;

  const _BodyDot({required this.point, required this.isPartner, required this.containerSize});

  @override
  State<_BodyDot> createState() => _BodyDotState();
}

class _BodyDotState extends State<_BodyDot> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _anim, curve: Curves.elasticOut));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.isPartner ? AppColors.primary : const Color(0xFF00BCD4);
    final px = widget.point.x * widget.containerSize.width;
    final py = widget.point.y * widget.containerSize.height;

    return Positioned(
      left: px - 16,
      top: py - 16,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: dotColor.withOpacity(0.85),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: dotColor.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)],
              ),
              child: const Center(
                child: Icon(Icons.touch_app_rounded, color: Colors.white, size: 14),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.point.label,
                style: TextStyle(color: dotColor, fontSize: 8, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
