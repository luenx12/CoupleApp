// ═══════════════════════════════════════════════════════════════════════════════
// FantasyBoardBubble — Chat akışına inline düşen Fantezi Masası widget'ı
// Koyu tema, altın kenarlık, canlı avatar oylama, flutter_animate kilit animasyonu
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_notifier.dart';
import '../domain/fantasy_board_model.dart';
import '../domain/fantasy_board_notifier.dart';

// ── Renkler ───────────────────────────────────────────────────────────────────

const _kGold       = Color(0xFFC9A84C);
const _kGoldLight  = Color(0xFFE8C96B);
const _kDark       = Color(0xFF0D0D0D);
const _kCard       = Color(0xFF1A1A1A);
const _kCardBorder = Color(0xFF2E2E2E);
const _kAvatarSize = 34.0;
const _kCardGap    = 8.0;

// ── Main Widget ───────────────────────────────────────────────────────────────

class FantasyBoardBubble extends ConsumerWidget {
  const FantasyBoardBubble({
    super.key,
    required this.boardId,
    required this.payloadJson,
  });

  final String boardId;
  final String payloadJson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = FantasyBoardPayload.tryParseJson(payloadJson);
    if (payload == null) return const SizedBox.shrink();

    final boardState = ref.watch(fantasyBoardProvider(boardId));
    final auth       = ref.watch(authNotifierProvider);
    final myInitial  = (auth.username ?? '?')[0].toUpperCase();
    final pInitial   = (auth.partnerName ?? '?')[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: _kDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kGold, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _kGold.withAlpha(40),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _BoardHeader(isMatched: boardState.isMatched),
            const SizedBox(height: 4),
            // ── Cards + Avatar overlay ───────────────────────────────────────
            LayoutBuilder(builder: (ctx, constraints) {
              return _CardArea(
                payload:    payload,
                boardState: boardState,
                totalWidth: constraints.maxWidth,
                boardId:    boardId,
                myInitial:  myInitial,
                pInitial:   pInitial,
                ref:        ref,
              );
            }),
            // ── Footer ──────────────────────────────────────────────────────
            _BoardFooter(boardState: boardState, myInitial: myInitial),
            const SizedBox(height: 12),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _BoardHeader extends StatelessWidget {
  const _BoardHeader({required this.isMatched});
  final bool isMatched;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kCardBorder)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fantezi Masası',
                  style: TextStyle(
                    color: _kGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  isMatched ? 'Görev kilitlendi! 🔒' : 'Görev zarflarından birini seç…',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Altın dekoratif ikon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kGold, width: 1),
            ),
            child: const Icon(Icons.stars_rounded, color: _kGold, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Card Area with Avatar Overlay ─────────────────────────────────────────────

class _CardArea extends StatelessWidget {
  const _CardArea({
    required this.payload,
    required this.boardState,
    required this.totalWidth,
    required this.boardId,
    required this.myInitial,
    required this.pInitial,
    required this.ref,
  });

  final FantasyBoardPayload payload;
  final BoardState boardState;
  final double totalWidth;
  final String boardId;
  final String myInitial;
  final String pInitial;
  final WidgetRef ref;

  // Horizontal padding inside the container
  static const _hPad = 12.0;
  // cardH is now dynamic — removed fixed height

  double _cardWidth() {
    final available = totalWidth - _hPad * 2 - _kCardGap * 2;
    return available / 3;
  }

  // X center of card at index i (absolute in stack)
  double _cardCenterX(int i) {
    final cw = _cardWidth();
    return _hPad + i * (cw + _kCardGap) + cw / 2;
  }

  // Convert centerX to left for a circle of size _kAvatarSize
  double _toLeft(double centerX) => centerX - _kAvatarSize / 2;


  // Neutral position (center of stack, no vote)
  double get _neutralLeft => totalWidth / 2 - _kAvatarSize / 2;

  double _myLeft() {
    if (boardState.myVoteCardId == null) return _neutralLeft;
    final idx = payload.cards.indexWhere((c) => c.id == boardState.myVoteCardId);
    return idx < 0 ? _neutralLeft : _toLeft(_cardCenterX(idx));
  }

  double _partLeft() {
    if (boardState.partnerVoteCardId == null) return _neutralLeft;
    final idx = payload.cards.indexWhere((c) => c.id == boardState.partnerVoteCardId);
    return idx < 0 ? _neutralLeft : _toLeft(_cardCenterX(idx));
  }

  @override
  Widget build(BuildContext context) {
    final cw = _cardWidth();

    return Column(
      children: [
        // ── Partner avatar row (top) ──────────────────────────────────────
        SizedBox(
          height: _kAvatarSize,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                top: 0,
                left: _partLeft(),
                child: _AvatarChip(
                  initial: pInitial,
                  color:   const Color(0xFFE8405A),
                  label:   'O',
                  hasVoted: boardState.partnerVoteCardId != null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // ── Cards row ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _hPad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < payload.cards.length; i++) ...[
                if (i > 0) const SizedBox(width: _kCardGap),
                Expanded(
                  child: _FantasyCardWidget(
                    card:       payload.cards[i],
                    boardState: boardState,
                    boardId:    boardId,
                    ref:        ref,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        // ── My avatar row (bottom) ───────────────────────────────────────
        SizedBox(
          height: _kAvatarSize,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                top: 0,
                left: _myLeft(),
                child: _AvatarChip(
                  initial: myInitial,
                  color:   const Color(0xFF3A86FF),
                  label:   'Ben',
                  hasVoted: boardState.myVoteCardId != null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Single Card Widget ────────────────────────────────────────────────────────

class _FantasyCardWidget extends StatelessWidget {
  const _FantasyCardWidget({
    required this.card,
    required this.boardState,
    required this.boardId,
    required this.ref,
  });

  final FantasyCard    card;
  final BoardState     boardState;
  final String         boardId;
  final WidgetRef      ref;

  bool get _isMyVote      => boardState.myVoteCardId == card.id;
  bool get _isPartVote    => boardState.partnerVoteCardId == card.id;
  bool get _isMatched     => boardState.isMatched && boardState.matchedCardId == card.id;
  bool get _isOtherLocked => boardState.isMatched && !_isMatched;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: boardState.isMatched
          ? null
          : () {
              HapticFeedback.mediumImpact();
              ref.read(fantasyBoardProvider(boardId).notifier).vote(card.id);
            },
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final base = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: _isMatched
            ? const Color(0xFF1F1800)
            : _isMyVote || _isPartVote
                ? const Color(0xFF1A1500)
                : _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isMatched
              ? _kGold
              : _isMyVote || _isPartVote
                  ? _kGold.withAlpha(140)
                  : _kCardBorder,
          width: _isMatched ? 2 : 1,
        ),
        boxShadow: _isMatched
            ? [
                BoxShadow(
                  color: _kGold.withAlpha(120),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Stack(
        children: [
          // ── Card content ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kGold.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kGold.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(card.category.emoji, style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 3),
                      Text(
                        card.category.label,
                        style: const TextStyle(
                          color: _kGoldLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Task text — dynamic height, fully visible
                Text(
                  card.taskText,
                  style: TextStyle(
                    color: _isOtherLocked
                        ? Colors.white.withAlpha(60)
                        : Colors.white.withAlpha(210),
                    fontSize: 10,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Vote indicators
                if (_isMyVote || _isPartVote)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_isPartVote)
                          const Padding(
                            padding: EdgeInsets.only(right: 3),
                            child: CircleAvatar(
                              radius: 5,
                              backgroundColor: Color(0xFFE8405A),
                            ),
                          ),
                        if (_isMyVote)
                          const CircleAvatar(
                            radius: 5,
                            backgroundColor: Color(0xFF3A86FF),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── KİLİTLENDİ overlay ───────────────────────────────────────────
          if (_isMatched)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(160),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🔒', style: TextStyle(fontSize: 28)),
                    SizedBox(height: 4),
                    Text(
                      'KİLİTLENDİ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _kGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
            ),
        ],
      ),
    );

    // ── Match animation (scale + glow) ────────────────────────────────────
    if (_isMatched) {
      return base
          .animate()
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.06, 1.06),
            duration: 600.ms,
            curve: Curves.elasticOut,
          );
    }

    // ── Other cards fade out when matched ─────────────────────────────────
    if (_isOtherLocked) {
      return Opacity(
        opacity: 0.28,
        child: base,
      );
    }

    return base;
  }
}

// ── Avatar Chip ───────────────────────────────────────────────────────────────

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({
    required this.initial,
    required this.color,
    required this.label,
    required this.hasVoted,
  });

  final String initial;
  final Color  color;
  final String label;
  final bool   hasVoted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _kAvatarSize,
      height: _kAvatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: hasVoted ? _kGold : Colors.white24,
          width: hasVoted ? 2 : 1,
        ),
        boxShadow: hasVoted
            ? [BoxShadow(color: color.withAlpha(120), blurRadius: 8, spreadRadius: 1)]
            : [],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _BoardFooter extends StatelessWidget {
  const _BoardFooter({required this.boardState, required this.myInitial});
  final BoardState boardState;
  final String myInitial;

  @override
  Widget build(BuildContext context) {
    if (boardState.isMatched) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A1F00), Color(0xFF1F1800)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGold.withAlpha(80)),
          ),
          child: const Column(
            children: [
              Text(
                '✨ Görev kilitlendi!',
                style: TextStyle(
                  color: _kGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Klavyeye dön ve görevi tamamla 💬',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 800.ms).slideY(begin: 0.2),
      );
    }

    final myVoted  = boardState.myVoteCardId != null;
    final prtVoted = boardState.partnerVoteCardId != null;

    String statusText;
    if (!myVoted && !prtVoted) {
      statusText = 'İkisi de henüz seçmedi';
    } else if (myVoted && !prtVoted) {
      statusText = 'Sen seçtin — partner bekleniyor…';
    } else if (!myVoted && prtVoted) {
      statusText = 'Partner seçti — sıra sende!';
    } else {
      statusText = 'İkisi de seçti — oy sayılıyor…';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.how_to_vote_rounded, color: _kGold, size: 13),
          const SizedBox(width: 5),
          Text(
            statusText,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
