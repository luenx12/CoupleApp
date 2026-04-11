import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/water_widget.dart';
import 'widgets/love_panel.dart';

class VibeDashboardScreen extends StatelessWidget {
  const VibeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Günaydın 💖',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bugün partnerinle etkileşime geç.',
              style: TextStyle(color: AppColors.onSurfaceMuted),
            ),
            const SizedBox(height: 32),
            const WaterWidget(),
            const SizedBox(height: 20),
            const LovePanel(),
          ],
        ),
      ),
    );
  }
}
