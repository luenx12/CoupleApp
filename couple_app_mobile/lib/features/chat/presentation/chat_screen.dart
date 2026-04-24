// ═══════════════════════════════════════════════════════════════════════════════
// ChatScreen — iMessage-style encrypted messaging UI
// v3: Connection status indicator
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../location/domain/location_notifier.dart';
import '../data/signalr_service.dart';
import '../domain/chat_notifier.dart';
import '../domain/message_model.dart';
import 'fantasy_board_bubble.dart';
import 'message_bubble.dart';
import 'media_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _controller    = TextEditingController();
  final _scrollCtrl    = ScrollController();
  final _focusNode     = FocusNode();
  final _imagePicker   = ImagePicker();
  Timer? _typingTimer;
  bool _showScrollBtn  = false;
  bool _isTyping       = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Klavye açılınca en alta kaydır
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onScroll() {
    final atBottom = _scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 80;
    if (atBottom != !_showScrollBtn) {
      setState(() => _showScrollBtn = !atBottom);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ── Typing detection ──────────────────────────────────────────────────────

  void _onTextChanged(String text) {
    final notifier = ref.read(chatNotifierProvider.notifier);
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      notifier.sendTyping(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        notifier.sendTyping(false);
      }
    });
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    _typingTimer?.cancel();
    if (_isTyping) {
      _isTyping = false;
      ref.read(chatNotifierProvider.notifier).sendTyping(false);
    }
    HapticFeedback.lightImpact();
    await ref.read(chatNotifierProvider.notifier).sendText(text);
    _scrollToBottom();
  }

  Future<void> _pickAndSendMedia() async {
    final auth = ref.read(authNotifierProvider);
    if (auth.partnerPublicKey == null || auth.partnerPublicKey!.isEmpty) {
      _showSnack('Partner henüz kayıtlı değil.');
      return;
    }

    final source = await _showMediaSourceDialog();
    if (source == null) return;

    XFile? file;
    if (source == 'gallery') {
      file = await _imagePicker.pickMedia(imageQuality: 80);
    } else if (source == 'camera_photo') {
      file = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80);
    } else if (source == 'camera_video') {
      file = await _imagePicker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 5));
    }

    if (file == null) return;

    HapticFeedback.mediumImpact();
    await ref.read(chatNotifierProvider.notifier).sendMedia(file);
    _scrollToBottom();
  }

  Future<String?> _showMediaSourceDialog() async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MediaSourceBtn(
                icon: Icons.photo_library_rounded,
                label: 'Galeri',
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              _MediaSourceBtn(
                icon: Icons.camera_alt_rounded,
                label: 'Foto Çek',
                onTap: () => Navigator.pop(ctx, 'camera_photo'),
              ),
              _MediaSourceBtn(
                icon: Icons.videocam_rounded,
                label: 'Video Çek',
                onTap: () => Navigator.pop(ctx, 'camera_video'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Location request ──────────────────────────────────────────────────────

  void _requestLocation() {
    final auth = ref.read(authNotifierProvider);
    if (auth.partnerId == null) {
      _showSnack('Partner bulunamadı.');
      return;
    }
    ref.read(locationNotifierProvider.notifier).requestLocation(auth.partnerId!);
    _showSnack('📍 Konum isteği gönderildi…');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider);
    final auth      = ref.watch(authNotifierProvider);
    final partner   = auth.partnerName ?? 'Partner';

    // Auto-scroll on new messages
    ref.listen(chatNotifierProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    final hubStatus = ref.watch(hubStatusProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar ───────────────────────────────────────────────────
              _ChatAppBar(
                partnerName: partner,
                hubStatus:   hubStatus,
                onLocationTap: _requestLocation,
              ),
              // ── Connection status banner ──────────────────────────────────
              _ConnectionBanner(hubStatus: hubStatus),
              // ── Messages ─────────────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    if (chatState.isLoading)
                      const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    else
                      ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: chatState.messages.length +
                            (chatState.isPartnerTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (chatState.isPartnerTyping &&
                              index == chatState.messages.length) {
                            return const TypingIndicator();
                          }
                          final msg = chatState.messages[index];
                          return _buildMessageItem(msg);
                        },
                      ),
                    // Scroll-to-bottom button
                    if (_showScrollBtn)
                      Positioned(
                        bottom: 8, right: 12,
                        child: FloatingActionButton.small(
                          backgroundColor: AppColors.card,
                          onPressed: _scrollToBottom,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primary,
                          ),
                        ).animate().scale(
                          begin: const Offset(0, 0),
                          duration: 200.ms,
                          curve: Curves.elasticOut,
                        ),
                      ),
                  ],
                ),
              ),
              // ── Input bar ────────────────────────────────────────────────
              _InputBar(
                controller:     _controller,
                focusNode:      _focusNode,
                isSending:      chatState.isSending,
                onChanged:      _onTextChanged,
                onSend:         _sendText,
                onMedia:        _pickAndSendMedia,
                onFantasyBoard: () => ref.read(chatNotifierProvider.notifier).triggerFantasyBoard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(MessageModel msg) {
    if (msg.type == MsgType.fantasyBoard) {
      return FantasyBoardBubble(
        key:        ValueKey('fb_${msg.id}'),
        boardId:    msg.id,
        payloadJson: msg.plainText,
      );
    }
    if (msg.type == MsgType.image) {
      return MediaBubble(
        key:   ValueKey(msg.id),
        message: msg,
        onViewed: () => ref.read(chatNotifierProvider.notifier).onMediaViewed(msg),
        onDownloadRequest: () =>
            ref.read(chatNotifierProvider.notifier).downloadMedia(msg),
      );
    }
    return MessageBubble(key: ValueKey(msg.id), message: msg);
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  const _ChatAppBar({
    required this.partnerName,
    required this.hubStatus,
    required this.onLocationTap,
  });
  final String partnerName;
  final HubConnectionStatus hubStatus;
  final VoidCallback onLocationTap;

  @override
  Widget build(BuildContext context) {
    // Online indicator dot color based on hub status
    final (dotColor, dotTooltip) = switch (hubStatus) {
      HubConnectionStatus.connected    => (AppColors.success, 'Bağlı'),
      HubConnectionStatus.reconnecting => (Colors.amber,      'Yeniden bağlanıyor…'),
      HubConnectionStatus.connecting   => (Colors.amber,      'Bağlanıyor…'),
      _                                => (Colors.redAccent,  'Bağlantı yok'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card.withAlpha(200),
        border: const Border(
          bottom: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Row(
        children: [
          // Avatar with online dot
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              // Status dot
              Positioned(
                right: 0, bottom: 0,
                child: Tooltip(
                  message: dotTooltip,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.card, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partnerName,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.lock_rounded, size: 10, color: AppColors.success),
                    SizedBox(width: 3),
                    Text(
                      'Uçtan uca şifreli',
                      style: TextStyle(color: AppColors.success, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // "Neredesin?" butonu
          TextButton.icon(
            onPressed: onLocationTap,
            icon: const Icon(Icons.location_on_rounded, size: 16),
            label: const Text('Neredesin?', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: AppColors.primary.withAlpha(20),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Connection Banner ─────────────────────────────────────────────────────────

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.hubStatus});
  final HubConnectionStatus hubStatus;

  @override
  Widget build(BuildContext context) {
    if (hubStatus == HubConnectionStatus.connected) {
      return const SizedBox.shrink(); // no banner when connected
    }

    final (bgColor, icon, text) = switch (hubStatus) {
      HubConnectionStatus.reconnecting ||
      HubConnectionStatus.connecting   => (
          Colors.amber.shade800,
          Icons.sync_rounded,
          'Yeniden bağlanıyor… Mesajlarınız gönderilecek.',
        ),
      _ => (
          Colors.red.shade800,
          Icons.wifi_off_rounded,
          'Bağlantı yok — Mesajlar bağlantı gelince gönderilecek.',
        ),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        color: bgColor.withAlpha(220),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hubStatus == HubConnectionStatus.reconnecting ||
                hubStatus == HubConnectionStatus.connecting)
              const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white,
                ),
              )
            else
              Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 200.ms),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onChanged,
    required this.onSend,
    required this.onMedia,
    required this.onFantasyBoard,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onMedia;
  final VoidCallback onFantasyBoard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: const Border(top: BorderSide(color: AppColors.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 🔥 Fantasy Board butonu
          IconButton(
            onPressed: isSending ? null : onFantasyBoard,
            icon: const Icon(Icons.local_fire_department_rounded),
            color: const Color(0xFFC9A84C),
            tooltip: 'Fantezi Masası',
          ),
          // Media button
          IconButton(
            onPressed: isSending ? null : onMedia,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            color: AppColors.primary,
            tooltip: 'Fotoğraf gönder',
          ),
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: TextField(
                controller:  controller,
                focusNode:   focusNode,
                minLines:    1,
                maxLines:    5,
                onChanged:   onChanged,
                onSubmitted: (_) => onSend(),
                textInputAction: TextInputAction.newline,
                style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
                decoration: const InputDecoration(
                  hintText:        'Mesaj gönder…',
                  hintStyle:       TextStyle(color: AppColors.onSurfaceMuted),
                  border:          InputBorder.none,
                  contentPadding:  EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled:          false,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: isSending
              ? const SizedBox(
                  width: 44,
                  height: 44,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: onSend,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

// ── Media source button ───────────────────────────────────────────────────────

class _MediaSourceBtn extends StatelessWidget {
  const _MediaSourceBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.onSurface)),
        ],
      ),
    );
  }
}
