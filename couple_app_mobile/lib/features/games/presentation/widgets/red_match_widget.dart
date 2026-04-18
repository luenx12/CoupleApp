// ═══════════════════════════════════════════════════════════════════════════════
// 🔥 Red Match Widget — Swipe To Passion
// Tinder mantığında pozisyon/fantezi kaydırma.
// Her iki taraf aynı kartı sağa kaydırırsa "IT'S A MATCH!" ekranı açılır.
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/red_room_notifier.dart';
import '../../../../core/theme/app_theme.dart';

// ── Kategori renkleri ─────────────────────────────────────────────────────────
const _catColors = <String, Color>{
  'position': Color(0xFFE91E8C),
  'fantasy':  Color(0xFF7C3AED),
  'bdsm':     Color(0xFFFF3D00),
};
const _catLabels = <String, String>{
  'position': 'POZİSYON',
  'fantasy':  'FANTEZİ',
  'bdsm':     'HARDCORE',
};

// ── Pozisyon / fantezi emoji haritası ────────────────────────────────────────
const _itemEmoji = <String, String>{
  'pos_missionary':   '❤️',
  'pos_doggy':        '🐾',
  'pos_cowgirl':      '🤠',
  'pos_rev_cowgirl':  '🔄',
  'pos_standing':     '🧍',
  'pos_spooning':     '🥄',
  'pos_lotus':        '🪷',
  'pos_69':           '♾️',
  'pos_amazon':       '💪',
  'fantasy_roleplay': '🎭',
  'fantasy_bdsm':     '⛓️',
  'fantasy_outdoor':  '🌿',
  'fantasy_mirror':   '🪞',
  'fantasy_shower':   '🚿',
  'fantasy_kitchen':  '🍴',
};

class RedMatchWidget extends ConsumerStatefulWidget {
  const RedMatchWidget({super.key});

  @override
  ConsumerState<RedMatchWidget> createState() => _RedMatchWidgetState();
}

class _RedMatchWidgetState extends ConsumerState<RedMatchWidget>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  double _dragDx = 0;

  late AnimationController _matchBurstController;
  late Animation<double> _matchBurstAnim;

  @override
  void initState() {
    super.initState();
    _matchBurstController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    );
    _matchBurstAnim = CurvedAnimation(
      parent: _matchBurstController, curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _matchBurstController.dispose();
    super.dispose();
  }

  FantasyItem get _current => kFantasyItems[_currentIndex];

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    setState(() => _dragDx += d.delta.dx);
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    final direction = _dragDx > 80 ? 'right' : (_dragDx < -80 ? 'left' : null);
    if (direction != null) {
      HapticFeedback.mediumImpact();
      ref.read(redRoomNotifierProvider.notifier).swipeFantasy(_current.id, direction);
      _advanceCard();
    }
    setState(() => _dragDx = 0);
  }

  void _swipe(String direction) {
    HapticFeedback.mediumImpact();
    ref.read(redRoomNotifierProvider.notifier).swipeFantasy(_current.id, direction);
    _advanceCard();
  }

  void _advanceCard() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % kFantasyItems.length;
      _dragDx = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(redRoomNotifierProvider);

    // Match patlaması
    ref.listen<RedRoomState>(redRoomNotifierProvider, (prev, next) {
      if (next.matchedItemId != null && next.matchedItemId != prev?.matchedItemId) {
        _matchBurstController.forward(from: 0);
        HapticFeedback.heavyImpact();
        _showMatchDialog(context, next.matchedItemId!);
        ref.read(redRoomNotifierProvider.notifier).clearMatch();
      }
    });

    final item = _current;
    final catColor = _catColors[item.category] ?? AppColors.primary;
    final swipeProgress = (_dragDx / 200).clamp(-1.0, 1.0);
    final isRight = swipeProgress > 0.2;
    final isLeft  = swipeProgress < -0.2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D0020), Color(0xFF1A0035)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.secondary.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.secondary.withOpacity(0.12), blurRadius: 20, spreadRadius: 2),
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
                  color: AppColors.secondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🔥', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Red Match', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('Swipe to passion — eşleşince patlıyor!',
                      style: TextStyle(color: Color(0xFFBB86FC), fontSize: 11)),
                ],
              ),
              const Spacer(),
              _PartnerSwipeIndicator(state: state),
            ],
          ),
          const SizedBox(height: 20),

          // Swipe Card
          GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: Transform.rotate(
              angle: swipeProgress * 0.15,
              child: Transform.translate(
                offset: Offset(_dragDx, 0),
                child: Stack(
                  children: [
                    _FantasyCard(item: item, catColor: catColor),
                    // Swipe overlay
                    if (isRight)
                      _SwipeOverlay(label: 'EVET 💚', color: Colors.green),
                    if (isLeft)
                      _SwipeOverlay(label: 'PASS ❌', color: Colors.red, alignment: Alignment.topLeft),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              math.min(kFantasyItems.length, 8),
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _currentIndex % 8 ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _currentIndex % 8 ? catColor : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                label: 'PASS',
                color: Colors.red,
                icon: Icons.close_rounded,
                onTap: () => _swipe('left'),
              ),
              Text('${_currentIndex + 1}/${kFantasyItems.length}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              _ActionButton(
                label: 'EVET!',
                color: Colors.green,
                icon: Icons.favorite_rounded,
                onTap: () => _swipe('right'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMatchDialog(BuildContext context, String itemId) {
    final matched = kFantasyItems.firstWhere(
      (f) => f.id == itemId,
      orElse: () => const FantasyItem(id: '', label: '?', imageKey: '', category: 'fantasy'),
    );
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _MatchDialog(item: matched, animation: _matchBurstAnim),
    );
  }
}

// ── Fantasy Kartı ─────────────────────────────────────────────────────────────

class _FantasyCard extends StatelessWidget {
  final FantasyItem item;
  final Color catColor;

  const _FantasyCard({required this.item, required this.catColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [catColor.withOpacity(0.3), Colors.black87],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: catColor.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(color: catColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/red_room/positions/${item.imageKey}.png',
              width: 90,
              height: 90,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                _itemEmoji[item.imageKey] ?? '💫',
                style: const TextStyle(fontSize: 64),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(item.label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: catColor.withOpacity(0.5)),
            ),
            child: Text(
              _catLabels[item.category] ?? item.category.toUpperCase(),
              style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Swipe overlay ─────────────────────────────────────────────────────────────

class _SwipeOverlay extends StatelessWidget {
  final String label;
  final Color color;
  final Alignment alignment;

  const _SwipeOverlay({
    required this.label,
    required this.color,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 2),
            ),
            child: Text(label,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ),
    );
  }
}

// ── Partner swipe göstergesi ──────────────────────────────────────────────────

class _PartnerSwipeIndicator extends StatelessWidget {
  final RedRoomState state;
  const _PartnerSwipeIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.partnerSwipedItemId == null) return const SizedBox.shrink();
    final isRight = state.partnerSwipeDirection == 'right';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(state.partnerSwipedItemId),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (isRight ? Colors.green : Colors.red).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isRight ? Colors.green : Colors.red),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isRight ? Icons.favorite : Icons.close,
                color: isRight ? Colors.green : Colors.red, size: 14),
            const SizedBox(width: 4),
            Text('Partner', style: TextStyle(
                color: isRight ? Colors.green : Colors.red, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 12)],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Match Dialog ──────────────────────────────────────────────────────────────

class _MatchDialog extends StatelessWidget {
  final FantasyItem item;
  final Animation<double> animation;

  const _MatchDialog({required this.item, required this.animation});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: animation,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              colors: [Color(0xFF4D0033), Color(0xFF1A0015), Colors.black],
              radius: 1.5,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.primary.withOpacity(0.8), width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 30, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('❤️‍🔥', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              const Text("IT'S A MATCH!",
                  style: TextStyle(
                      color: Color(0xFFFF0055), fontSize: 28,
                      fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 8),
              Text(item.label,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/red_room/positions/${item.imageKey}.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    _itemEmoji[item.imageKey] ?? '💫',
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('İkiniz de aynı şeyi seçtiniz 🔥\nBu gece planlandı!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 14)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                ),
                child: const Text('Harika! 🎉', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
