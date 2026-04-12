// ═══════════════════════════════════════════════════════════════════════════════
// DrawGameNotifier — State management for the real-time drawing game
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../chat/data/signalr_service.dart';
import 'draw_game_model.dart';
import '../../../core/config/app_config.dart';

final drawGameNotifierProvider =
    StateNotifierProvider<DrawGameNotifier, DrawGameState>((ref) {
  final auth    = ref.watch(authNotifierProvider);
  final signalR = ref.watch(signalRServiceProvider);
  final dio     = ref.watch(dioProvider);

  return DrawGameNotifier(
    myId:      auth.userId ?? '',
    partnerId: auth.partnerId ?? '',
    signalR:   signalR,
    dio:       dio,
  );
});

class DrawGameNotifier extends StateNotifier<DrawGameState> {
  DrawGameNotifier({
    required this.myId,
    required this.partnerId,
    required this.signalR,
    required this.dio,
  }) : super(const DrawGameState()) {
    _initSignalR();
  }

  final String myId;
  final String partnerId;
  final SignalRService signalR;
  final Dio dio;

  Timer? _countdownTimer;
  Timer? _strokeSyncTimer;
  final List<DrawStroke> _unsyncedStrokes = [];

  void _initSignalR() {
    signalR.onDrawStrokeReceived = _onStrokeReceived;
    signalR.onDrawCleared = _onDrawCleared;
    signalR.onDrawGuessResult = _onDrawGuessResult;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _strokeSyncTimer?.cancel();
    super.dispose();
  }

  // ── Word Selection (Drawer) ────────────────────────────────────────────────

  Future<void> fetchWordOptions({int? difficulty}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final queryParams = difficulty != null ? {'difficulty': difficulty} : null;
      final response = await dio.get('/api/games/draw/words', queryParameters: queryParams);
      final list = (response.data as List).cast<Map<String, dynamic>>();
      
      final options = list.map((m) => DrawWordOption.fromMap(m)).toList();
      state = state.copyWith(
        phase: DrawPhase.wordSelection,
        role: DrawRole.drawer,
        wordOptions: options,
        isLoading: false,
      );
    } on DioException catch(e) {
      state = state.copyWith(isLoading: false, error: 'Kelimeler alınamadı: ${e.message}');
    }
  }

  Future<void> selectWord(String wordId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await dio.post('/api/games/draw/start', data: {
        'guesserId': partnerId,
        'wordId': wordId,
      });
      
      final data = response.data;
      state = state.copyWith(
        phase: DrawPhase.drawing,
        sessionId: data['id'],
        secretWord: data['word'],
        isLoading: false,
      );
      
      _startCountdown();
      _startStrokeSyncTimer();
    } on DioException catch(e) {
      state = state.copyWith(isLoading: false, error: 'Oyun başlatılamadı: ${e.message}');
    }
  }

  // ── Drawing Actions (Drawer) ────────────────────────────────────────────────

  void setColor(Color color) {
    state = state.copyWith(selectedColor: color, isEraser: false);
  }

  void setStrokeWidth(double width) {
    state = state.copyWith(strokeWidth: width);
  }

  void setEraser(bool isEraser) {
    state = state.copyWith(isEraser: isEraser);
  }

  void addStroke(DrawStroke stroke) {
    if (state.phase != DrawPhase.drawing || state.role != DrawRole.drawer) return;
    
    state = state.copyWith(localStrokes: [...state.localStrokes, stroke]);
    _unsyncedStrokes.add(stroke);
  }

  void clearCanvas() {
    if (state.phase != DrawPhase.drawing || state.role != DrawRole.drawer) return;
    
    state = state.copyWith(localStrokes: [], remoteStrokes: []);
    _unsyncedStrokes.clear();
    
    // Notify guesser to clear
    if (state.sessionId != null) {
      signalR.sendDrawClear(partnerId, state.sessionId!);
    }
  }

  // Sync strokes every 100ms
  void _startStrokeSyncTimer() {
    _strokeSyncTimer?.cancel();
    _strokeSyncTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_unsyncedStrokes.isNotEmpty && state.sessionId != null) {
        _syncStrokesBatch(List.from(_unsyncedStrokes));
        _unsyncedStrokes.clear();
      }
    });
  }

  Future<void> _syncStrokesBatch(List<DrawStroke> batch) async {
    for (var stroke in batch) {
       final dto = {
        'sessionId': state.sessionId,
        'points': stroke.points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'color': stroke.color.value.toRadixString(16), // Convert color to string
        'strokeWidth': stroke.strokeWidth,
        'isEraser': stroke.isEraser,
      };
      await signalR.sendDrawStroke(partnerId, dto);
    }
  }

  // ── Guessing Actions (Guesser) ──────────────────────────────────────────────

  void updateGuessText(String text) {
    state = state.copyWith(guessText: text);
  }

  Future<void> submitGuess() async {
    if (state.guessText.trim().isEmpty || state.sessionId == null) return;
    
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await dio.post('/api/games/draw/guess', data: {
        'sessionId': state.sessionId,
        'guess': state.guessText,
      });
      
      final data = response.data;
      if (data['correct'] == true) {
        _countdownTimer?.cancel();
        state = state.copyWith(
          phase: DrawPhase.guessed,
          secretWord: data['word'],
          scoreAwarded: data['score'],
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Yanlış tahmin! Denemeye devam et.',
          guessText: '', // Clear text field on wrong guess
        );
      }
    } on DioException catch(e) {
      state = state.copyWith(isLoading: false, error: 'Tahmin gönderilemedi: ${e.message}');
    }
  }

  // ── Handlers for SignalR Events ─────────────────────────────────────────────

  // Called when receiving strokes from the drawer
  void _onStrokeReceived(Map<String, dynamic> dto) {
    if (state.sessionId != dto['sessionId']) {
      // Possible scenario: Guesser hasn't officially started the session locally yet.
      // E.g., The drawer started drawing before the guesser opened the screen.
      // We should smoothly transition the guesser into drawing phase.
      state = state.copyWith(
        phase: DrawPhase.drawing,
        role: DrawRole.guesser,
        sessionId: dto['sessionId'],
        remoteStrokes: [], // Clear previous
      );
      _startCountdown(); 
    }

    final colorInt = int.tryParse(dto['color'], radix: 16) ?? 0xFFFFFFFF;
    final pointsData = (dto['points'] as List).cast<Map<String, dynamic>>();
    final points = pointsData.map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble())).toList();

    final newStroke = DrawStroke(
      points: points,
      color: Color(colorInt),
      strokeWidth: (dto['strokeWidth'] as num?)?.toDouble() ?? 5.0,
      isEraser: dto['isEraser'] as bool? ?? false,
    );

    state = state.copyWith(
      remoteStrokes: [...state.remoteStrokes, newStroke]
    );
  }

  // Called when drawer clears canvas
  void _onDrawCleared(Map<String, dynamic> dto) {
    if (state.sessionId == dto['sessionId']) {
      state = state.copyWith(remoteStrokes: []);
    }
  }

  // Called by SignalR when guesser wins (drawer receives this)
  void _onDrawGuessResult(Map<String, dynamic> dto) {
    if (state.sessionId == dto['sessionId']) {
       _countdownTimer?.cancel();
       _strokeSyncTimer?.cancel();
       state = state.copyWith(
         phase: DrawPhase.guessed,
         scoreAwarded: dto['score'],
       );
    }
  }

  // ── Timer Logic ─────────────────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    state = state.copyWith(secondsLeft: 60);
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.secondsLeft > 0) {
        state = state.copyWith(secondsLeft: state.secondsLeft - 1);
      } else {
        timer.cancel();
        _handleTimeUp();
      }
    });
  }

  Future<void> _handleTimeUp() async {
    state = state.copyWith(phase: DrawPhase.timeUp);
    _strokeSyncTimer?.cancel();

    // The drawer informs the server about the timeout
    if (state.role == DrawRole.drawer && state.sessionId != null) {
      try {
        await dio.post('/api/games/draw/timeout', data: {
          'sessionId': state.sessionId,
        });
      } catch (e) {
        // Log error
      }
    }
  }
  
  // Method to reset the game state
   void resetGame() {
    _countdownTimer?.cancel();
    _strokeSyncTimer?.cancel();
    state = const DrawGameState();
  }
}
