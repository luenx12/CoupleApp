// ═══════════════════════════════════════════════════════════════════════════════
// 🎲 Spicy Dice Widget — İkimizin Zarları
// Neon zar animasyonuyla Mekan + Pozisyon çeker. Pozisyona özel görsel/emoji
// assets/red_room/positions/<imageKey>.png ile eşleşir.
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/red_room_notifier.dart';

// ── Pozisyon → Emoji haritası (asset yokken fallback) ────────────────────────
const _positionEmoji = <String, String>{
  'pos_missionary':  '❤️',
  'pos_doggy':       '🐾',
  'pos_cowgirl':     '🤠',
  'pos_rev_cowgirl': '🔄',
  'pos_standing':    '🧍',
  'pos_spooning':    '🥄',
  'pos_rev_spooning':'↩️',
  'pos_lotus':       '🪷',
  'pos_69':          '♾️',
  'pos_edge':        '🪑',
  'pos_lap_face':    '🤗',
  'pos_amazon':      '💪',
  'pos_scissors':    '✂️',
  'pos_shoulders':   '🏋️',
  'pos_bridge':      '🌉',
};

// ── Mekan → İkon haritası ────────────────────────────────────────────────────
const _locationIcon = <String, IconData>{
  'Yatak Odası':             Icons.bed_rounded,
  'Duşakabin':               Icons.shower_rounded,
  'Mutfak Tezgahı':         Icons.kitchen_rounded,
  'Koltuk':                  Icons.chair_rounded,
  'Arka Koltuk':             Icons.directions_car_rounded,
  'Boy Aynası Karşısı':     Icons.person_outline_rounded,
  'Çamaşır Makinesi Üzeri': Icons.local_laundry_service_rounded,
  'Balkon (Dikkatli Olun!)': Icons.balcony_rounded,
  'Yemek Masası':            Icons.table_restaurant_rounded,
};

class SpicyDiceWidget extends ConsumerStatefulWidget {
  const SpicyDiceWidget({super.key});

  @override
  ConsumerState<SpicyDiceWidget> createState() => _SpicyDiceWidgetState();
}

class _SpicyDiceWidgetState extends ConsumerState<SpicyDiceWidget>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _revealController;
  late Animation<double> _shakeAnim;
  late Animation<double> _revealAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.06), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: -0.06), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.06, end: 0), weight: 1),
    ]).animate(_shakeController);

    _revealController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _revealAnim = CurvedAnimation(parent: _revealController, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _rollDice() async {
    HapticFeedback.heavyImpact();
    _revealController.reset();
    await _shakeController.forward(from: 0);
    await ref.read(redRoomNotifierProvider.notifier).rollDice();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(redRoomNotifierProvider);
    final result = state.diceResult;

    // Yeni sonuç gelince reveal animasyonu
    ref.listen<RedRoomState>(redRoomNotifierProvider, (prev, next) {
      if (next.diceResult != null && next.diceResult != prev?.diceResult) {
        _revealController.forward(from: 0);
        HapticFeedback.mediumImpact();
      }
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0008), Color(0xFF2D0015)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF0055).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF0055).withOpacity(0.15), blurRadius: 20, spreadRadius: 2),
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
                  color: const Color(0xFFFF0055).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🎲', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('İkimizin Zarları',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('Bu gecenin kurgusu rastgele belirleniyor...',
                      style: TextStyle(color: Color(0xFFFF6699), fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dice Visual
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.rotate(
              angle: _shakeAnim.value * math.pi,
              child: child,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NeonDice(
                  emoji: '🎲',
                  label: result?.location ?? '?',
                  sublabel: 'MEKAN',
                  icon: result != null ? _locationIcon[result.location] : null,
                ),
                const SizedBox(width: 20),
                const Text('×', style: TextStyle(color: Colors.white30, fontSize: 28)),
                const SizedBox(width: 20),
                _NeonDice(
                  emoji: result != null
                      ? (_positionEmoji[result.imageKey] ?? '💫')
                      : '🎲',
                  imageKey: result?.imageKey,
                  label: result?.position ?? '?',
                  sublabel: 'POZİSYON',
                ),
              ],
            ),
          ),

          // Result Card
          if (result != null)
            ScaleTransition(
              scale: _revealAnim,
              child: _ResultCard(result: result),
            ),

          const SizedBox(height: 20),

          // Roll Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isDiceRolling ? null : _rollDice,
              icon: state.isDiceRolling
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('🎲', style: TextStyle(fontSize: 18)),
              label: Text(state.isDiceRolling ? 'Zarlar Uçuyor...' : 'ZARLARI AT',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0055),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: const Color(0xFFFF0055).withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Neon Zar Kutusu ───────────────────────────────────────────────────────────

class _NeonDice extends StatelessWidget {
  final String emoji;
  final String? imageKey;
  final String label;
  final String sublabel;
  final IconData? icon;

  const _NeonDice({
    required this.emoji,
    this.imageKey,
    required this.label,
    required this.sublabel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF1A0808),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFF0055).withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF0055).withOpacity(0.3), blurRadius: 15),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Icon(icon, color: Colors.white70, size: 28)
              else if (imageKey != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/red_room/positions/$imageKey.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(emoji, style: const TextStyle(fontSize: 32)),
                  ),
                )
              else
                Text(emoji, style: const TextStyle(fontSize: 32)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(sublabel,
            style: const TextStyle(color: Color(0xFFFF0055), fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 2),
        SizedBox(
          width: 90,
          child: Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ),
      ],
    );
  }
}

// ── Sonuç Kartı ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final DiceResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D0015),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF0055).withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite, color: Color(0xFFFF0055), size: 14),
              SizedBox(width: 6),
              Text('Bu Geceye Özel Program',
                  style: TextStyle(color: Color(0xFFFF0055), fontSize: 12,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
              SizedBox(width: 6),
              Icon(Icons.favorite, color: Color(0xFFFF0055), size: 14),
            ],
          ),
          const SizedBox(height: 16),
          _row('📍 Mekan', result.location),
          const Divider(color: Colors.white10, height: 20),
          _row(
            '${_positionEmoji[result.imageKey] ?? "💫"} Pozisyon',
            result.position,
          ),
          const Divider(color: Colors.white10, height: 20),
          _row('⏱️ Süre', result.duration),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      );
}
