import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SpicyNeverEverWidget extends StatefulWidget {
  const SpicyNeverEverWidget({super.key});

  @override
  State<SpicyNeverEverWidget> createState() => _SpicyNeverEverWidgetState();
}

class _SpicyNeverEverWidgetState extends State<SpicyNeverEverWidget> {
  int _currentIndex = 0;
  bool _revealed = false;

  final List<String> _statements = [
    "Ben hiç... partnerimin yanında çıplak uyumadım. 🛏️",
    "Ben hiç... toplum içinde partnerime kaçamak bir öpücük vermedim. 💋",
    "Ben hiç... partnerimle aynı anda duş almadım. 🚿",
    "Ben hiç... partnerimin kıyafetlerini gizlice denemedim. 👔👗",
    "Ben hiç... partnerime seksi bir fotoğraf çekip göndermedim. 📸",
    "Ben hiç... asansörde partnerimle yakınlaşmadım. 🏢",
    "Ben hiç... partnerimin en sevdiği fantezisini gerçekleştirmedim. ✨",
    "Ben hiç... partnerimle birlikte uyandığımda ona hemen sarılmadım. ❤️",
  ];

  void _next() {
    setState(() {
      _currentIndex = Random().nextInt(_statements.length);
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D001A), // Very dark purple
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.purpleAccent.withAlpha(50)),
      ),
      child: Column(
        children: [
          const Text(
            "Ben Hiç... (Couple Edition)",
            style: TextStyle(
              color: Colors.purpleAccent,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Yaptıysan bir yudum al!",
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Container(
            height: 120,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statements[_currentIndex],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _next,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purpleAccent,
                    side: const BorderSide(color: Colors.purpleAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("SIRADAKİ"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Logic to notify partner via SignalR (e.g. "Partner is drinking!")
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("YAPTIM! 🔥"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
