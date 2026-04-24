import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/games_notifier.dart';

class SpicyTruthDareWidget extends ConsumerStatefulWidget {
  const SpicyTruthDareWidget({super.key});

  @override
  ConsumerState<SpicyTruthDareWidget> createState() => _SpicyTruthDareWidgetState();
}

class _SpicyTruthDareWidgetState extends ConsumerState<SpicyTruthDareWidget> {
  bool _isTruth = true;
  int _currentIndex = 0;

  final List<String> _truths = [
    "Partnerinle ilgili en vahşi hayalin nedir? 🔥",
    "Onunlayken kendini en seksi hissettiğin an hangisiydi?",
    "Partnerinin vücudunda en çok nereye dokunulmasını seviyorsun?",
    "İlk tanıştığınızda onunla ilgili aklından geçen en yaramaz düşünce neydi?",
    "Partnerinin seninle ilgili bilmediği gizli bir tutkun var mı? 🤫",
  ];

  final List<String> _dares = [
    "Partnerinin en sevdiğin yerini öperken 5 saniyelik bir video çek. 😘",
    "Şu an üzerinde sadece bir parça kıyafet kalana kadar soyun ve fotoğraf at. 👙",
    "Kamerayı vücudunda yavaşça gezdirerek partnerine bir 'tur' yaptır. 😉",
    "Partnerine en seksi fısıltınla bir ses kaydı gönder. 🎤",
    "Ayna karşısında partnerinle paylaştığın en sevdiğin anıyı canlandır.",
    "Partnerinin en sevdiğin yerini öperken 5 saniyelik bir video çek. 😘",
    "Masturbasyon yaparken partnerine bir video gönder. 🍆",
    "Partnerine en seksi fısıltınla bir ses kaydı gönder. 🎤",
    "Ayna karşısında partnerinle paylaştığın en sevdiğin anıyı canlandır.",
    "Parmağına sakso çek 10 saniye ",
    
    
  ];

  void _generateNew() {
    setState(() {
      _currentIndex = Random().nextInt(_isTruth ? _truths.length : _dares.length);
    });
    // In a full implementation, notify partner that a challenge was selected
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0000), // Very dark red
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.redAccent.withAlpha(50)),
      ),
      child: Column(
        children: [
          const Text(
            "Doğruluk mu Cesaret mi?",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTypeToggle("DOĞRULUK", _isTruth, () => setState(() => _isTruth = true)),
              const SizedBox(width: 12),
              _buildTypeToggle("CESARET", !_isTruth, () => setState(() => _isTruth = false)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isTruth ? _truths[_currentIndex] : _dares[_currentIndex],
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _generateNew,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("YENİSİNİ GETİR"),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.redAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
