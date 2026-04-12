import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wordle_grid.dart';
import 'wordle_keyboard.dart';
import '../../../domain/wordle_notifier.dart';
import '../../../domain/games_notifier.dart';
import '../../../../auth/domain/auth_notifier.dart';

class WordleWidget extends ConsumerStatefulWidget {
  const WordleWidget({super.key});

  @override
  ConsumerState<WordleWidget> createState() => _WordleWidgetState();
}

class _WordleWidgetState extends ConsumerState<WordleWidget> {
  String? _challengeWord; // if null, playing daily.

  Widget _buildChallengeConfig() {
    final tc = TextEditingController();
    return AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Text("Partnerine Kelime Gönder!", style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: tc,
        maxLength: 5,
        style: const TextStyle(color: Colors.white),
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          hintText: "5 Harfli Kelime",
          hintStyle: TextStyle(color: Colors.white54),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("İptal"),
        ),
        ElevatedButton(
          onPressed: () {
            if (tc.text.length == 5) {
              ref.read(gamesNotifierProvider.notifier).sendWordleChallenge(tc.text.toUpperCase());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Kelimen Partnerine Uçuruldu! 🤫")),
              );
            }
          },
          child: const Text("GÖNDER"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to partner's incoming challenges
    ref.listen<GamesState>(gamesNotifierProvider, (prev, next) {
      if (next.wordleChallengeWord != null && (prev?.wordleChallengeWord != next.wordleChallengeWord)) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: const Text("Partnerin sana yeni bir kelime meydan okuması gönderdi!"),
             action: SnackBarAction(
               label: "KABUL ET",
               onPressed: () {
                 setState(() => _challengeWord = next.wordleChallengeWord);
                 ref.read(gamesNotifierProvider.notifier).clearIncomingWordleChallenge();
               },
             ),
           )
        );
      }
      
      if (next.wordlePartnerAttempts != null && (prev?.wordlePartnerAttempts != next.wordlePartnerAttempts)) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: const Text("Wordle Sonucu 🎉", style: TextStyle(color: Colors.white)),
            content: Text(
              "Partnerin az önce kelimeyi ${next.wordlePartnerAttempts} denemede buldu!",
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("TAMAM"))
            ],
          )
        );
      }
    });

    final wordleProv = wordleNotifierProvider(_challengeWord);
    final state = ref.watch(wordleProv);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121213),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Wordle", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  if (_challengeWord != null) ...[
                    const Icon(Icons.flash_on, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    const Text("Meydan Okuma", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                  ],
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.purpleAccent),
                    onPressed: () => showDialog(context: context, builder: (_) => _buildChallengeConfig()),
                  ),
                ],
              )
            ],
          ),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          WordleGrid(state: state),
          const SizedBox(height: 32),
          if (state.isGameOver) ...[
            Text(
              state.isWin ? "Tebrikler! Kelimetik'i Buldun 🎉" : "Maalesef Bilemedin. Kelime: ${state.targetWord}",
              style: TextStyle(
                color: state.isWin ? Colors.greenAccent : Colors.redAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_challengeWord != null) ...[
               const SizedBox(height: 12),
               ElevatedButton(
                 onPressed: () => setState(() => _challengeWord = null),
                 child: const Text("GÜNLÜK OYUNA DÖN"),
               )
            ]
          ] else ...[
            WordleKeyboard(
              letterStates: state.keyboardStates,
              onLetterTap: (letter) => ref.read(wordleProv.notifier).typeLetter(letter),
              onDeleteTap: () => ref.read(wordleProv.notifier).deleteLetter(),
              onEnterTap: () => ref.read(wordleProv.notifier).submitGuess(),
            ),
          ]
        ],
      ),
    );
  }
}
