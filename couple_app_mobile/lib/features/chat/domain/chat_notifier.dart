// ═══════════════════════════════════════════════════════════════════════════════
// ChatNotifier — Riverpod state management for the chat screen
// v3: HubStatus listener + outbox flush on SignalR reconnect
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../crypto/crypto_provider.dart';
import '../../media/media_provider.dart';
import '../../../core/services/connectivity_service.dart';
import '../data/chat_repository.dart';
import '../data/media_api_service.dart';
import '../data/signalr_service.dart';
import '../domain/message_model.dart';


// ── State ─────────────────────────────────────────────────────────────────────

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isPartnerTyping = false,
    this.isOnline = true,
    this.hubStatus = HubConnectionStatus.disconnected,
    this.error,
  });

  final List<MessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final bool isPartnerTyping;
  final bool isOnline;
  /// Real SignalR hub connection status (more accurate than isOnline)
  final HubConnectionStatus hubStatus;
  final String? error;

  /// True only when both network is up AND SignalR is connected
  bool get isFullyOnline =>
      isOnline && hubStatus == HubConnectionStatus.connected;

  bool get isReconnecting =>
      hubStatus == HubConnectionStatus.reconnecting;

  ChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isSending,
    bool? isPartnerTyping,
    bool? isOnline,
    HubConnectionStatus? hubStatus,
    String? error,
  }) =>
      ChatState(
        messages:        messages        ?? this.messages,
        isLoading:       isLoading       ?? this.isLoading,
        isSending:       isSending       ?? this.isSending,
        isPartnerTyping: isPartnerTyping ?? this.isPartnerTyping,
        isOnline:        isOnline        ?? this.isOnline,
        hubStatus:       hubStatus       ?? this.hubStatus,
        error:           error,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final auth    = ref.watch(authNotifierProvider);
  final crypto  = ref.watch(cryptoServiceProvider);
  final media   = ref.watch(mediaStorageServiceProvider);
  final signalR = ref.watch(signalRServiceProvider);
  final dio     = ref.watch(dioProvider);

  return ChatNotifier(
    myId:               auth.userId ?? '',
    partnerId:          auth.partnerId ?? '',
    partnerName:        auth.partnerName ?? 'Partner',
    partnerPublicKeyPem: auth.partnerPublicKey ?? '',
    crypto:             crypto,
    mediaStorage:       media,
    signalR:            signalR,
    accessToken:        auth.accessToken ?? '',
    dio:                dio,
    ref:                ref,
  );
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier({
    required this.myId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerPublicKeyPem,
    required this.crypto,
    required this.mediaStorage,
    required this.signalR,
    required this.accessToken,
    required this.dio,
    required this.ref,
  }) : super(const ChatState()) {
    _init();
  }

  final String myId;
  final String partnerId;
  final String partnerName;
  final String partnerPublicKeyPem;
  final dynamic crypto;
  final dynamic mediaStorage;
  final SignalRService signalR;
  final String accessToken;
  final Dio dio;
  final Ref ref;

  late final ChatRepository _repo;
  StreamSubscription<NetworkStatus>? _connectivitySub;
  // Prevents duplicate flush calls
  bool _flushScheduled = false;

  Future<void> _init() async {
    if (myId.isEmpty || partnerId.isEmpty) return;

    _repo = ChatRepository(
      myId:               myId,
      partnerId:          partnerId,
      partnerPublicKeyPem: partnerPublicKeyPem,
      crypto:             crypto,
      mediaStorage:       mediaStorage,
      signalR:            signalR,
      mediaApi:           MediaApiService(accessToken),
      dio:                dio,
    );

    // Register SignalR callbacks
    signalR.onMessage       = _onIncomingMessage;
    signalR.onPartnerTyping = _onPartnerTyping;

    // ✅ KEY FIX: flush outbox whenever SignalR successfully connects/reconnects
    signalR.onReconnected = _onSignalRReconnected;

    // Load local messages first (instant)
    state = state.copyWith(isLoading: true);
    final local = await _repo.loadLocalMessages();
    state = state.copyWith(messages: local, isLoading: false);

    // Sync from server in background
    _syncHistory();

    // ── Connectivity izle (network layer) ───────────────────────────────
    _connectivitySub = ConnectivityService.instance.statusStream.listen(
      _onConnectivityChanged,
    );

    // İlk durumu ayarla
    final currentStatus = ConnectivityService.instance.current;
    state = state.copyWith(isOnline: currentStatus == NetworkStatus.online);

    // ── HubStatus izle (SignalR layer) ───────────────────────────────────
    // Watch hubStatusProvider changes to update UI and trigger flush
    ref.listen<HubConnectionStatus>(hubStatusProvider, (prev, next) {
      if (!mounted) return;
      state = state.copyWith(hubStatus: next);

      if (next == HubConnectionStatus.connected && prev != HubConnectionStatus.connected) {
        // SignalR just connected/reconnected → flush pending messages
        _triggerFlush();
      }
    });

    // Set initial hub status
    state = state.copyWith(hubStatus: ref.read(hubStatusProvider));
  }

  /// Called by SignalRService when hub reconnects successfully.
  void _onSignalRReconnected() {
    if (!mounted) return;
    _triggerFlush();
  }

  /// Debounced flush trigger — prevents multiple concurrent flushes.
  Future<void> _triggerFlush() async {
    if (_flushScheduled) return;
    _flushScheduled = true;
    // Small delay to let state settle
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      await _flushOutbox();
    }
    _flushScheduled = false;
  }

  void _onConnectivityChanged(NetworkStatus status) {
    if (!mounted) return;
    final isOnline = status == NetworkStatus.online;
    state = state.copyWith(isOnline: isOnline);

    if (isOnline && signalR.isConnected) {
      // Both network and SignalR are up → flush
      _triggerFlush();
    }
  }

  Future<void> _syncHistory() async {
    final synced = await _repo.fetchAndSyncHistory();
    if (mounted) {
      state = state.copyWith(messages: synced);
    }
  }

  // ── Outbox Flush ──────────────────────────────────────────────────────────

  Future<void> _flushOutbox() async {
    await _repo.flushOutbox(onStatusChanged: _onOutboxStatusChanged);
  }

  void _onOutboxStatusChanged(String localId, SendStatus status) {
    if (!mounted) return;
    final updated = state.messages.map((m) {
      if (m.id == localId) return m.copyWith(sendStatus: status);
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  // ── Send Text ─────────────────────────────────────────────────────────────

  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;
    state = state.copyWith(isSending: true);
    try {
      final msg = await _repo.sendTextMessage(text.trim());
      state = state.copyWith(
        messages:  [...state.messages, msg],
        isSending: false,
      );

      // Hemen flush: SignalR bağlıysa anında gider, değilse outbox'ta bekler
      _triggerFlush();
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  // ── Send Media ────────────────────────────────────────────────────────────

  Future<void> sendMedia(XFile file) async {
    if (partnerPublicKeyPem.isEmpty) {
      state = state.copyWith(error: 'Partner public key bulunamadı.');
      return;
    }
    state = state.copyWith(isSending: true);
    try {
      final msg = await _repo.sendMediaMessage(file);
      state = state.copyWith(
        messages:  [...state.messages, msg],
        isSending: false,
      );
      _triggerFlush();
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  // ── Incoming Message ──────────────────────────────────────────────────────

  Future<void> _onIncomingMessage(Map<String, dynamic> dto) async {
    final msg = await _repo.handleIncoming(dto);
    if (msg != null && mounted) {
      state = state.copyWith(messages: [...state.messages, msg]);
    }
  }

  // ── Typing ────────────────────────────────────────────────────────────────

  void _onPartnerTyping(String senderId, bool isTyping) {
    if (senderId == partnerId && mounted) {
      state = state.copyWith(isPartnerTyping: isTyping);
    }
  }

  Future<void> sendTyping(bool isTyping) async {
    await signalR.sendTyping(partnerId, isTyping);
  }

  // ── Media Viewed → Self-Destruct ─────────────────────────────────────────

  Future<void> onMediaViewed(MessageModel msg) async {
    if (msg.remoteMediaId == null || msg.mediaDeleted) return;
    await _repo.notifyMediaViewed(msg.id, msg.remoteMediaId!);
    if (mounted) {
      final updated = state.messages.map((m) {
        return m.id == msg.id ? m.copyWith(mediaDeleted: true) : m;
      }).toList();
      state = state.copyWith(messages: updated);
    }
  }

  // ── Download Media ────────────────────────────────────────────────────────

  Future<String?> downloadMedia(MessageModel msg) async {
    if (msg.remoteMediaId == null) return null;
    final path = await _repo.downloadAndSaveMedia(
      messageId: msg.id,
      mediaId:   msg.remoteMediaId!,
    );
    if (path != null && mounted) {
      final updated = state.messages.map((m) {
        return m.id == msg.id ? m.copyWith(localMediaPath: path) : m;
      }).toList();
      state = state.copyWith(messages: updated);
    }
    return path;
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
