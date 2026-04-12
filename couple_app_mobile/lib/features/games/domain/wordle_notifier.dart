import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'games_notifier.dart';
import '../../crypto/crypto_service.dart';
import '../../crypto/crypto_provider.dart';

// Very small fallback list if we run out. Ideally more would be generated.
const _dailyWords = [
  "AŞKIM", "SEVDA", "KALBİ", "HAYAT", "GÜNEŞ", "BAHAR", "DENİZ", "YILDI", // 'YILDIZ' var ama 6 harf, YILDI yapalım 5 için
  "UMUTL", "MELEK", "ÇİÇEK", "TATLI", "GÜLÜŞ", "ROMAN", "ÖZLEM"
];

enum LetterState { initial, absent, present, correct }

class WordleState {
  final List<List<String>> board;
  final List<List<LetterState>> boardStates;
  final Map<String, LetterState> keyboardStates;
  final int currentRow;
  final int currentCol;
  final String targetWord;
  final bool isGameOver;
  final bool isWin;
  final bool isDaily; // If false, it's a partner challenge

  WordleState({
    required this.board,
    required this.boardStates,
    required this.keyboardStates,
    required this.currentRow,
    required this.currentCol,
    required this.targetWord,
    this.isGameOver = false,
    this.isWin = false,
    this.isDaily = true,
  });

  WordleState copyWith({
    List<List<String>>? board,
    List<List<LetterState>>? boardStates,
    Map<String, LetterState>? keyboardStates,
    int? currentRow,
    int? currentCol,
    bool? isGameOver,
    bool? isWin,
  }) {
    return WordleState(
      board: board ?? this.board,
      boardStates: boardStates ?? this.boardStates,
      keyboardStates: keyboardStates ?? this.keyboardStates,
      currentRow: currentRow ?? this.currentRow,
      currentCol: currentCol ?? this.currentCol,
      targetWord: this.targetWord,
      isGameOver: isGameOver ?? this.isGameOver,
      isWin: isWin ?? this.isWin,
      isDaily: this.isDaily,
    );
  }
}

final wordleNotifierProvider = StateNotifierProvider.family<WordleNotifier, WordleState, String?>((ref, challengeWord) {
  return WordleNotifier(ref, challengeWord);
});

class WordleNotifier extends StateNotifier<WordleState> {
  final Ref ref;

  WordleNotifier(this.ref, String? challengeWord) : super(_createInitialState(challengeWord));

  static WordleState _createInitialState(String? challengeWord) {
    String target = challengeWord?.toUpperCase() ?? _getDailyWord();
    return WordleState(
      board: List.generate(6, (_) => List.filled(5, '')),
      boardStates: List.generate(6, (_) => List.filled(5, LetterState.initial)),
      keyboardStates: {},
      currentRow: 0,
      currentCol: 0,
      targetWord: target,
      isDaily: challengeWord == null,
    );
  }

  static String _getDailyWord() {
    final now = DateTime.now().toUtc();
    final epoch = DateTime.utc(2024, 1, 1);
    final days = now.difference(epoch).inDays;
    return _dailyWords[max(0, days) % _dailyWords.length].toUpperCase();
  }

  void typeLetter(String uppercaseLetter) {
    if (state.isGameOver) return;
    if (state.currentCol < 5) {
      final newBoard = List<List<String>>.from(state.board.map((r) => List<String>.from(r)));
      newBoard[state.currentRow][state.currentCol] = uppercaseLetter;
      state = state.copyWith(
        board: newBoard,
        currentCol: state.currentCol + 1,
      );
    }
  }

  void deleteLetter() {
    if (state.isGameOver) return;
    if (state.currentCol > 0) {
      final newBoard = List<List<String>>.from(state.board.map((r) => List<String>.from(r)));
      newBoard[state.currentRow][state.currentCol - 1] = '';
      state = state.copyWith(
        board: newBoard,
        currentCol: state.currentCol - 1,
      );
    }
  }

  Future<void> submitGuess() async {
    if (state.isGameOver || state.currentCol != 5) return;

    final guess = state.board[state.currentRow].join('');
    final target = state.targetWord;

    final newBoardStates = List<List<LetterState>>.from(state.boardStates.map((r) => List<LetterState>.from(r)));
    final newKeyboardStates = Map<String, LetterState>.from(state.keyboardStates);

    var targetChars = target.split('');
    var guessChars = guess.split('');
    var rowStates = List.filled(5, LetterState.absent);

    // Pass 1: find correct (green)
    for (int i = 0; i < 5; i++) {
      if (guessChars[i] == targetChars[i]) {
        rowStates[i] = LetterState.correct;
        targetChars[i] = '_'; // mark as used
        _updateKeyboard(newKeyboardStates, guessChars[i], LetterState.correct);
      }
    }

    // Pass 2: find present (yellow)
    for (int i = 0; i < 5; i++) {
      if (rowStates[i] == LetterState.correct) continue;
      
      final indexInTarget = targetChars.indexOf(guessChars[i]);
      if (indexInTarget != -1) {
        rowStates[i] = LetterState.present;
        targetChars[indexInTarget] = '_';
        _updateKeyboard(newKeyboardStates, guessChars[i], LetterState.present);
      } else {
        _updateKeyboard(newKeyboardStates, guessChars[i], LetterState.absent);
      }
    }

    newBoardStates[state.currentRow] = rowStates;
    bool isWin = guess == target;
    bool isGameEnd = isWin || state.currentRow == 5;

    state = state.copyWith(
      boardStates: newBoardStates,
      keyboardStates: newKeyboardStates,
      currentRow: state.currentRow + 1,
      currentCol: 0,
      isWin: isWin,
      isGameOver: isGameEnd,
    );

    if (isGameEnd) {
      // Broadcast to partner
      await ref.read(gamesNotifierProvider.notifier).sendWordleResult(state.currentRow, state.isDaily);
    }
  }

  void _updateKeyboard(Map<String, LetterState> kb, String letter, LetterState newState) {
    final current = kb[letter] ?? LetterState.initial;
    if (newState == LetterState.correct) {
      kb[letter] = LetterState.correct;
    } else if (newState == LetterState.present && current != LetterState.correct) {
      kb[letter] = LetterState.present;
    } else if (newState == LetterState.absent && current == LetterState.initial) {
      kb[letter] = LetterState.absent;
    }
  }
}
