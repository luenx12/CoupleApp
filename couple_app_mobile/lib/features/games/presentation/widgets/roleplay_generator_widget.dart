// ═══════════════════════════════════════════════════════════════════════════════
// 🎭 Roleplay Generator Widget
// Rastgele senaryo + karakter üretir. Her iki tarafa farklı rol verilir.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/red_room_notifier.dart';
import '../../../../core/theme/app_theme.dart';

const _atmosphereEmoji = <String, String>{
  'Gece Geç Saat, Boş Ofis':  '🏢',
  'Otel Barında İlk Tanışma': '🍸',
  'Cezaya Kalınan Sınıf':     '📚',
  'Sorgu Odası':               '🔦',
  'Kırmızı Oda (BDSM)':       '⛓️',
  'Özel Muayenehane':          '🏥',
  'VIP Spa Odası':             '💆',
  'Hapishane Koridoru':        '🔒',
  'Karanlık Ofis':             '🕵️',
  'Ortaçağ Sarayı':            '🏰',
};

class RoleplayGeneratorWidget extends ConsumerStatefulWidget {
  const RoleplayGeneratorWidget({super.key});

  @override
  ConsumerState<RoleplayGeneratorWidget> createState() =>
      _RoleplayGeneratorWidgetState();
}

class _RoleplayGeneratorWidgetState
    extends ConsumerState<RoleplayGeneratorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _flipAnim = CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack);
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    HapticFeedback.mediumImpact();
    _flipController.reset();
    await ref.read(redRoomNotifierProvider.notifier).generateRoleplay();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(redRoomNotifierProvider);
    final roleplay = state.roleplay;

    ref.listen<RedRoomState>(redRoomNotifierProvider, (prev, next) {
      if (next.roleplay != null && next.roleplay != prev?.roleplay) {
        _flipController.forward(from: 0);
        HapticFeedback.mediumImpact();
      }
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0015), Color(0xFF1A0030)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.secondary.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.secondary.withOpacity(0.15), blurRadius: 20),
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
                child: const Text('🎭', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Roleplay Jeneratör',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('Senaryonuzu sistem belirler...',
                      style: TextStyle(color: Color(0xFFBB86FC), fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Result
          if (roleplay != null)
            AnimatedBuilder(
              animation: _flipAnim,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX((1 - _flipAnim.value) * 3.14159),
                  child: _flipAnim.value > 0.5 ? child : const SizedBox(height: 170),
                );
              },
              child: _RoleplayCard(roleplay: roleplay),
            )
          else
            Container(
              height: 140,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎭', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(state.isGeneratingRoleplay
                      ? 'Senaryo yazılıyor...'
                      : 'Hazır mısın? Senaryonu üret!',
                      style: const TextStyle(color: Colors.white38, fontSize: 14)),
                ],
              ),
            ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isGeneratingRoleplay ? null : _generate,
              icon: state.isGeneratingRoleplay
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('🎲', style: TextStyle(fontSize: 18)),
              label: Text(
                state.isGeneratingRoleplay ? 'Senaryo Yazılıyor...' : 'YENİ SENARYO ÜRETİLSİN',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: AppColors.secondary.withOpacity(0.5),
              ),
            ),
          ),

          if (roleplay != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Güvenli kelime: "KIRMIZI" — Her an durabiliriz.',
                      style: TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Roleplay Kartı ────────────────────────────────────────────────────────────

class _RoleplayCard extends StatelessWidget {
  final RoleplayResult roleplay;
  const _RoleplayCard({required this.roleplay});

  @override
  Widget build(BuildContext context) {
    final emoji = _atmosphereEmoji[roleplay.atmosphere] ?? '🎭';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withOpacity(0.3),
            Colors.black87,
          ],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(roleplay.atmosphere,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFBB86FC), fontSize: 12,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _RoleBox(label: 'SEN', role: roleplay.myRole, isMe: true)),
              const SizedBox(width: 12),
              const Text('vs', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(width: 12),
              Expanded(child: _RoleBox(label: 'PARTNERİN', role: roleplay.partnerRole, isMe: false)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleBox extends StatelessWidget {
  final String label;
  final String role;
  final bool isMe;

  const _RoleBox({required this.label, required this.role, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final color = isMe ? AppColors.primary : AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(color: color, fontSize: 9,
                  fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(role,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
