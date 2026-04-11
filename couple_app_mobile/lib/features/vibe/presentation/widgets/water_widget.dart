import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/vibe_notifier.dart';

class WaterWidget extends ConsumerWidget {
  const WaterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vibeNotifierProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        children: [
          const Text(
            'Günlük Su',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWaterCounter(
                'Ben',
                state.myWater,
                Colors.blueAccent,
                () {
                  ref.read(vibeNotifierProvider.notifier).incrementWater();
                },
              ),
              Container(
                width: 1,
                height: 50,
                color: AppColors.onSurfaceMuted.withAlpha(50),
              ),
              _buildWaterCounter(
                'Partner',
                state.partnerWater,
                AppColors.accent,
                null, // Cannot increment partner's water
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterCounter(String label, int count, Color color, VoidCallback? onTap) {
    Widget content = Column(
      children: [
        Icon(Icons.local_drink_rounded, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: content,
    );
  }
}
