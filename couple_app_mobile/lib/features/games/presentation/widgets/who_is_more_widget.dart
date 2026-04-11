import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/games_notifier.dart';

class WhoIsMoreWidget extends ConsumerStatefulWidget {
  const WhoIsMoreWidget({super.key});

  @override
  ConsumerState<WhoIsMoreWidget> createState() => _WhoIsMoreWidgetState();
}

class _WhoIsMoreWidgetState extends ConsumerState<WhoIsMoreWidget> {
  late ConfettiController _confettiController;
  int _currentQuestionIndex = 0;
  bool _answered = false;

  final List<String> _questions = [
    "Kim daha çok uyur?",
    "Kim daha iyi yemek yapar?",
    "Kim daha sakardır?",
    "Kim daha romantiktir?",
    "Kim daha çok para harcar?",
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _handleAnswer(String answer) {
    if (_answered) return;
    setState(() => _answered = true);
    
    // Send to partner via SignalR
    ref.read(gamesNotifierProvider.notifier).sendWhoIsMoreAnswer(
      "q_$_currentQuestionIndex", 
      answer
    );

    // For demo: if we answer, simulate a match after 1 second or just pop confetti
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _confettiController.play();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Eşleştiniz! 🎉"),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      _currentQuestionIndex = (_currentQuestionIndex + 1) % _questions.length;
      _answered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.secondary.withAlpha(50)),
          ),
          child: Column(
            children: [
              const Text(
                "Kim Daha?",
                style: TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _questions[_currentQuestionIndex],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              if (!_answered)
                Row(
                  children: [
                    Expanded(
                      child: _buildAnswerButton("BEN", AppColors.primary, () => _handleAnswer("me")),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAnswerButton("PARTNERİM", AppColors.secondary, () => _handleAnswer("partner")),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    const Text(
                      "Cevap verildi, partnerin bekleniyor...",
                      style: TextStyle(color: AppColors.onSurfaceMuted),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _nextQuestion,
                      child: const Text("Sıradaki Soru →"),
                    ),
                  ],
                ),
            ],
          ),
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: pi / 2,
          colors: const [Colors.pink, Colors.purple, Colors.orange, Colors.yellow],
          shouldLoop: false,
        ),
      ],
    );
  }

  Widget _buildAnswerButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withAlpha(40),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withAlpha(100)),
        ),
        elevation: 0,
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
