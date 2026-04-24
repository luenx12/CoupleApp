// ═══════════════════════════════════════════════════════════════════════════════
// FantasyBoardNotifier — Riverpod state for a single Fantasy Board session
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/signalr_service.dart';
import '../../auth/domain/auth_notifier.dart';
import 'fantasy_board_model.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class BoardState {
  const BoardState({
    this.myVoteCardId,
    this.partnerVoteCardId,
    this.isMatched = false,
    this.matchedCardId,
  });

  /// Benim oyladığım kartın ID'si (null = henüz oy verilmedi)
  final String? myVoteCardId;

  /// Partner'ın oyladığı kartın ID'si
  final String? partnerVoteCardId;

  /// İki oy aynı karta düştüğünde true olur
  final bool isMatched;

  /// Kilit vurulan kartın ID'si
  final String? matchedCardId;

  BoardState copyWith({
    String? myVoteCardId,
    String? partnerVoteCardId,
    bool?   isMatched,
    String? matchedCardId,
    bool clearMyVote        = false,
    bool clearPartnerVote   = false,
  }) =>
      BoardState(
        myVoteCardId:      clearMyVote     ? null : myVoteCardId      ?? this.myVoteCardId,
        partnerVoteCardId: clearPartnerVote ? null : partnerVoteCardId ?? this.partnerVoteCardId,
        isMatched:         isMatched        ?? this.isMatched,
        matchedCardId:     matchedCardId    ?? this.matchedCardId,
      );
}

// ── Provider (family — her board session için ayrı instance) ──────────────────

/// boardId'ye göre izole notifier. ChatNotifier tarafından event'ler iletilir.
final fantasyBoardProvider =
    StateNotifierProvider.family<FantasyBoardNotifier, BoardState, String>(
  (ref, boardId) => FantasyBoardNotifier(boardId, ref),
);

// ── Notifier ──────────────────────────────────────────────────────────────────

class FantasyBoardNotifier extends StateNotifier<BoardState> {
  FantasyBoardNotifier(this.boardId, this._ref) : super(const BoardState());

  final String boardId;
  final Ref    _ref;

  // ── Voting ──────────────────────────────────────────────────────────────────

  /// Kullanıcı bir karta tıkladığında çağrılır.
  Future<void> vote(String cardId) async {
    if (state.isMatched) return; // Zaten kilitli
    if (state.myVoteCardId == cardId) return; // Aynı kart

    // Önce local state güncelle (optimistic)
    state = state.copyWith(myVoteCardId: cardId);

    // SignalR'a gönder
    final signalR   = _ref.read(signalRServiceProvider);
    final auth      = _ref.read(authNotifierProvider);
    final partnerId = auth.partnerId ?? '';
    if (partnerId.isEmpty) return;

    try {
      await signalR.voteFantasyCard(partnerId, boardId, cardId);
    } catch (_) {
      // Sessizce geç — partner çevrimdışı olabilir, local state korunur
    }
  }

  // ── Incoming events (ChatNotifier tarafından çağrılır) ───────────────────────

  /// Partner oy verdiğinde ChatNotifier bu metodu çağırır.
  void onPartnerVote(String cardId) {
    if (!mounted) return;
    state = state.copyWith(partnerVoteCardId: cardId);

    // Local match kontrolü (sunucu da kontrol eder, ama UI anında tepki verir)
    if (state.myVoteCardId == cardId && !state.isMatched) {
      state = state.copyWith(isMatched: true, matchedCardId: cardId);
    }
  }

  /// Sunucu match onayladığında ChatNotifier bu metodu çağırır.
  void onMatch(String cardId) {
    if (!mounted) return;
    state = state.copyWith(
      isMatched:     true,
      matchedCardId: cardId,
    );
  }
}
