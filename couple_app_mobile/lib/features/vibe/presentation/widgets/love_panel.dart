import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/vibe_notifier.dart';

class LovePanel extends ConsumerWidget {
  const LovePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF831b61), Color(0xFF4c1c73)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withAlpha(80)),
      ),
      child: Column(
        children: [
          const Text(
            'Sevgi Paneli',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildVibeButton(
                  context,
                  ref,
                  'Seni Özledim',
                  Icons.favorite_rounded,
                  'vibe_miss_you',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVibeButton(
                  context,
                  ref,
                  'Öpücük',
                  Icons.emoji_emotions_rounded,
                  'vibe_kiss',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVibeButton(BuildContext context, WidgetRef ref, String label, IconData icon, String vibeType) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withAlpha(20),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: () {
        ref.read(vibeNotifierProvider.notifier).sendVibe(vibeType);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label gönderildi!'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
          ),
        );
      },
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
