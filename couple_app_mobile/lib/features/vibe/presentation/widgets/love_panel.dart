import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/vibe_notifier.dart';

class LovePanel extends ConsumerStatefulWidget {
  const LovePanel({super.key});

  @override
  ConsumerState<LovePanel> createState() => _LovePanelState();
}

class _LovePanelState extends ConsumerState<LovePanel> {
  Map<String, dynamic>? _wordleStats;

  @override
  void initState() {
    super.initState();
    _fetchWordleStats();
  }

  Future<void> _fetchWordleStats() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/MiniGames/wordle-stats'),
        headers: {'Authorization': 'Bearer MOCK_TOKEN'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _wordleStats = jsonDecode(response.body);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 16),
          if (_wordleStats != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text("Wordle İstatistiklerin", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn("Oynanan", _wordleStats!['total'].toString()),
                      _buildStatColumn("Ortalama", (_wordleStats!['avg'] as num).toStringAsFixed(1)),
                      _buildStatColumn("Seri(Max)", "${_wordleStats!['currentStreak']}(${_wordleStats!['maxStreak']})"),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
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
