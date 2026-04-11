import 'package:flutter/material.dart';
import 'package:scratcher/scratcher.dart';
import '../../../../core/theme/app_theme.dart';

class KazikazanWidget extends StatefulWidget {
  const KazikazanWidget({super.key});

  @override
  State<KazikazanWidget> createState() => _KazikazanWidgetState();
}

class _KazikazanWidgetState extends State<KazikazanWidget> {
  bool _isFinished = false;
  final String _mockTask = "Bugün partnerine en sevdiği kahveyi ısmarla! ☕";

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Günün Tatlı Görevi",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Scratcher(
              brushSize: 40,
              threshold: 50,
              color: Colors.grey[400]!,
              image: Image.network(
                "https://images.unsplash.com/photo-1614850523296-d8c1af93d400?q=80&w=500&auto=format&fit=crop",
                fit: BoxFit.cover,
              ),
              onChange: (value) => debugPrint("Scratch progress: $value%"),
              onThreshold: () => setState(() => _isFinished = true),
              child: Container(
                height: 150,
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(20),
                color: AppColors.primary.withAlpha(20),
                child: Text(
                  _mockTask,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isFinished ? AppColors.accent : Colors.transparent,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (_isFinished)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Save task to backend
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Görevi Kabul Et"),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                "Görevi görmek için kazı!",
                style: TextStyle(color: AppColors.onSurfaceMuted),
              ),
            ),
        ],
      ),
    );
  }
}
