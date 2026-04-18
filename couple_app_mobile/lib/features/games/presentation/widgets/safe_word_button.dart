// ═══════════════════════════════════════════════════════════════════════════════
// 🛑 Safe Word Button — Her zaman erişilebilir acil durdurma
// Red Room'un herhangi bir yerinde görünür. Tetiklenince tüm oturumlar durur.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/red_room_notifier.dart';

class SafeWordButton extends ConsumerStatefulWidget {
  const SafeWordButton({super.key});

  @override
  ConsumerState<SafeWordButton> createState() => _SafeWordButtonState();
}

class _SafeWordButtonState extends ConsumerState<SafeWordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _showConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SafeWordDialog(),
    );
    if (confirmed == true && mounted) {
      HapticFeedback.heavyImpact();
      await ref.read(redRoomNotifierProvider.notifier).triggerSafeWord();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(redRoomNotifierProvider);

    // Safe word tetiklendi — uyarı banner'ı göster
    ref.listen<RedRoomState>(redRoomNotifierProvider, (prev, next) {
      if (next.safeWordTriggered && !prev!.safeWordTriggered && mounted) {
        _showSafeWordBanner(context);
      }
    });

    return Column(
      children: [
        // Safe Word aktivasyonu varsa uyarı
        if (state.safeWordTriggered)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GÜVEN KELİMESİ TETİKLENDİ',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 13)),
                      Text('Tüm oturumlar durduruldu.',
                          style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(redRoomNotifierProvider.notifier).dismissSafeWord(),
                  child: const Text('Tamam', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          )
        else
          ScaleTransition(
            scale: _pulseAnim,
            child: GestureDetector(
              onLongPress: _showConfirmation,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Güvenli kelime için BASILI TUTUN'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.red.withOpacity(0.15), blurRadius: 12),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stop_circle_outlined, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Column(
                      children: [
                        Text('KIRMIZI — Güvenli Kelime',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.5)),
                        Text('Durdurmak için basılı tut',
                            style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showSafeWordBanner(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('GÜVEN KELİMESİ! Tüm oturumlar durduruldu.', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.red[800],
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Onay Dialog'u ─────────────────────────────────────────────────────────────

class _SafeWordDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A0000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.red.withOpacity(0.6), width: 2),
      ),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          SizedBox(width: 10),
          Text('Güvenli Kelime', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
        ],
      ),
      content: const Text(
        'KIRMIZI kelimesini tetiklemek tüm aktif Red Room oturumlarını anında durduracak.\n\nDevam etmek istiyor musun?',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('İptal', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.stop_circle),
          label: const Text('DURDUR'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
