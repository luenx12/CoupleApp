// ═══════════════════════════════════════════════════════════════════════════════
// DrawGame domain models — state, stroke data, word options
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:ui';

// ── Stroke ════════════════════════════════════════════════════════════════════

class DrawStroke {
  const DrawStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });

  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isEraser;
}

// ── Word option ───────────────────────────────────────────────────────────────

class DrawWordOption {
  const DrawWordOption({
    required this.id,
    required this.word,
    required this.category,
    required this.difficulty,
  });

  final String id;
  final String word;
  final String category;
  final int difficulty;

  factory DrawWordOption.fromMap(Map<String, dynamic> m) => DrawWordOption(
    id:         m['id'] as String,
    word:       m['word'] as String,
    category:   m['category'] as String? ?? 'Genel',
    difficulty: m['difficulty'] as int? ?? 0,
  );
}

// ── Game phase ────────────────────────────────────────────────────────────────

enum DrawPhase {
  idle,           // Not started
  wordSelection,  // Drawer choosing a word
  drawing,        // Active game
  guessed,        // Guesser won
  timeUp,         // Nobody won
}

// ── Role ──────────────────────────────────────────────────────────────────────

enum DrawRole { drawer, guesser }

// ── State ─────────────────────────────────────────────────────────────────────

class DrawGameState {
  const DrawGameState({
    this.phase       = DrawPhase.idle,
    this.role        = DrawRole.drawer,
    this.sessionId,
    this.secretWord,           // Only set for drawer
    this.wordOptions   = const [],
    this.localStrokes  = const [],
    this.remoteStrokes = const [],
    this.selectedColor = const Color(0xFFFFFFFF),
    this.strokeWidth   = 5.0,
    this.isEraser      = false,
    this.secondsLeft   = 60,
    this.scoreAwarded  = 0,
    this.guessText     = '',
    this.isLoading     = false,
    this.error,
  });

  final DrawPhase  phase;
  final DrawRole   role;
  final String?    sessionId;
  final String?    secretWord;
  final List<DrawWordOption> wordOptions;
  final List<DrawStroke> localStrokes;
  final List<DrawStroke> remoteStrokes;
  final Color    selectedColor;
  final double   strokeWidth;
  final bool     isEraser;
  final int      secondsLeft;
  final int      scoreAwarded;
  final String   guessText;
  final bool     isLoading;
  final String?  error;

  DrawGameState copyWith({
    DrawPhase? phase,
    DrawRole? role,
    String? sessionId,
    String? secretWord,
    List<DrawWordOption>? wordOptions,
    List<DrawStroke>? localStrokes,
    List<DrawStroke>? remoteStrokes,
    Color? selectedColor,
    double? strokeWidth,
    bool? isEraser,
    int? secondsLeft,
    int? scoreAwarded,
    String? guessText,
    bool? isLoading,
    String? error,
  }) =>
      DrawGameState(
        phase:          phase          ?? this.phase,
        role:           role           ?? this.role,
        sessionId:      sessionId      ?? this.sessionId,
        secretWord:     secretWord     ?? this.secretWord,
        wordOptions:    wordOptions    ?? this.wordOptions,
        localStrokes:   localStrokes   ?? this.localStrokes,
        remoteStrokes:  remoteStrokes  ?? this.remoteStrokes,
        selectedColor:  selectedColor  ?? this.selectedColor,
        strokeWidth:    strokeWidth    ?? this.strokeWidth,
        isEraser:       isEraser       ?? this.isEraser,
        secondsLeft:    secondsLeft    ?? this.secondsLeft,
        scoreAwarded:   scoreAwarded   ?? this.scoreAwarded,
        guessText:      guessText      ?? this.guessText,
        isLoading:      isLoading      ?? this.isLoading,
        error:          error,
      );
}
