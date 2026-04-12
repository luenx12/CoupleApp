import 'package:flutter/material.dart';
import '../../../domain/wordle_notifier.dart';

class WordleKeyboard extends StatelessWidget {
  final Map<String, LetterState> letterStates;
  final Function(String) onLetterTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onEnterTap;

  const WordleKeyboard({
    super.key,
    required this.letterStates,
    required this.onLetterTap,
    required this.onDeleteTap,
    required this.onEnterTap,
  });

  @override
  Widget build(BuildContext context) {
    const layout = [
      ["E", "R", "T", "Y", "U", "I", "O", "P", "Ğ", "Ü"],
      ["A", "S", "D", "F", "G", "H", "J", "K", "L", "Ş", "İ"],
      ["ENT", "Z", "C", "V", "B", "N", "M", "Ö", "Ç", "DEL"]
    ];

    return Column(
      children: layout.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((letter) {
            if (letter == "ENT") return _buildActionButton("GİR", onEnterTap);
            if (letter == "DEL") return _buildActionButton("SİL", onDeleteTap);
            return _buildKey(letter);
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildKey(String letter) {
    final state = letterStates[letter] ?? LetterState.initial;
    Color bgColor = Colors.grey.shade800;
    Color fgColor = Colors.white;

    if (state == LetterState.correct) {
      bgColor = Colors.green;
    } else if (state == LetterState.present) {
      bgColor = Colors.amber;
    } else if (state == LetterState.absent) {
      bgColor = Colors.grey.shade900;
      fgColor = Colors.white54;
    }

    return Expanded(
      flex: 10, // to balance width easily
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: () => onLetterTap(letter),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  color: fgColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return Expanded(
      flex: 15,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Material(
          color: Colors.grey.shade700,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
