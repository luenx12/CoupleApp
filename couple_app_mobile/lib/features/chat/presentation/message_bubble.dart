// ═══════════════════════════════════════════════════════════════════════════════
// MessageBubble — iMessage-style animated chat bubble
// v2: Optimistic UI — pending (saat ikonu), failed (kırmızı ünlem) durumları
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/message_model.dart';
import '../../../core/theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.showTime = true,
  });

  final MessageModel message;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left:   message.isMine ? 64 : 12,
          right:  message.isMine ? 12 : 64,
          top:    2,
          bottom: 2,
        ),
        child: Opacity(
          // Pending mesajlar biraz saydam görünür
          opacity: message.sendStatus == SendStatus.pending ? 0.65 : 1.0,
          child: Column(
            crossAxisAlignment: message.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              _BubbleBody(message: message),
              if (showTime) const SizedBox(height: 2),
              if (showTime) _TimeRow(message: message),
            ],
          ),
        ),
      ),
    )
    .animate()
    .slideX(
      begin: message.isMine ? 0.3 : -0.3,
      duration: 280.ms,
      curve: Curves.easeOutCubic,
    )
    .fadeIn(duration: 200.ms);
  }
}

// ── Bubble body ───────────────────────────────────────────────────────────────

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({required this.message});
  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    // Failed mesajlar için kırmızı kenarlık
    final isFailed  = message.sendStatus == SendStatus.failed;
    final isPending = message.sendStatus == SendStatus.pending;

    if (message.isMine) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isFailed
              ? null
              : const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isFailed ? AppColors.card : null,
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(18),
            topRight:    Radius.circular(18),
            bottomLeft:  Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          border: isFailed
              ? Border.all(color: Colors.redAccent.withAlpha(180), width: 1.5)
              : isPending
                  ? Border.all(color: AppColors.primary.withAlpha(80), width: 1)
                  : null,
          boxShadow: isFailed
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          message.plainText,
          style: TextStyle(
            color: isFailed ? AppColors.onSurfaceMuted : Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.only(
          topLeft:     Radius.circular(4),
          topRight:    Radius.circular(18),
          bottomLeft:  Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Text(
        message.plainText,
        style: const TextStyle(
          color: AppColors.onSurface,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }
}

// ── Time & status row ─────────────────────────────────────────────────────────

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.message});
  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    final hour   = message.sentAt.hour.toString().padLeft(2, '0');
    final minute = message.sentAt.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeStr,
          style: const TextStyle(
            color:    AppColors.onSurfaceMuted,
            fontSize: 11,
          ),
        ),
        if (message.isMine) ...[ 
          const SizedBox(width: 4),
          _StatusIcon(status: message.sendStatus, isRead: message.isRead),
        ],
      ],
    );
  }
}

// ── Status icon ───────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.isRead});
  final SendStatus status;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SendStatus.pending:
        // Saat ikonu — gönderilmeyi bekliyor
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.onSurfaceMuted),
          ),
        );

      case SendStatus.failed:
        // Kırmızı ünlem — gönderilemedi
        return const Icon(
          Icons.error_outline_rounded,
          size:  14,
          color: Colors.redAccent,
        );

      case SendStatus.sent:
        // Çift tik (okundu/iletildi)
        return Icon(
          isRead ? Icons.done_all_rounded : Icons.done_all_rounded,
          size:  14,
          color: isRead ? AppColors.primary : AppColors.onSurfaceMuted,
        );
    }
  }
}

// ── Typing indicator ─────────────────────────────────────────────────────────

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final offset = (i / 3.0);
                final bounce = ((_anim.value + offset) % 1.0);
                final t = bounce < 0.5 ? bounce * 2 : (1 - bounce) * 2;
                return Transform.translate(
                  offset: Offset(0, -4 * t),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.onSurfaceMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
