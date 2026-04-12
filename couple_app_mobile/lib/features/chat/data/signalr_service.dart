// ═══════════════════════════════════════════════════════════════════════════════
// SignalRService — Real-time hub connection
// Handles: messages, typing, location events
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../../../core/config/app_config.dart';

export 'signalr_service.dart' show HubConnectionStatus, hubStatusProvider, signalRServiceProvider;

enum HubConnectionStatus { disconnected, connecting, connected, reconnecting }

final hubStatusProvider = StateProvider<HubConnectionStatus>(
  (_) => HubConnectionStatus.disconnected,
);

final signalRServiceProvider = Provider<SignalRService>((ref) {
  final svc = SignalRService(ref);
  ref.onDispose(svc.dispose);
  return svc;
});

// Incoming message callback type
typedef MessageHandler  = void Function(Map<String, dynamic> dto);
typedef TypingHandler   = void Function(String senderId, bool isTyping);
typedef LocationHandler = void Function(Map<String, dynamic> payload);
typedef WaterSyncHandler = void Function(String senderId, int count);
typedef VibeHandler = void Function(String senderId, String vibeType);

typedef WhoIsMoreHandler = void Function(String senderId, String questionId, String answer);
typedef FlameLevelHandler = void Function(String senderId, double level);
typedef RedRoomMediaHandler = void Function(String senderId, String mediaId, int timeoutSeconds);

// Wordle handlers
typedef WordleChallengeHandler = void Function(String senderId, String encryptedWord);
typedef WordleResultHandler = void Function(String senderId, int attempts, bool isDaily);

// DrawGame handlers
typedef DrawStrokeHandler = void Function(Map<String, dynamic> dto);
typedef DrawClearHandler = void Function(Map<String, dynamic> dto);
typedef DrawGuessResultHandler = void Function(Map<String, dynamic> dto);

class SignalRService {
  SignalRService(this._ref);

  final Ref _ref;
  HubConnection? _hub;
  bool _disposed = false;

  // Callbacks registered by ChatNotifier / LocationNotifier
  MessageHandler?  onMessage;
  TypingHandler?   onPartnerTyping;
  LocationHandler? onLocationRequested;
  LocationHandler? onLocationShared;
  LocationHandler? onLocationDenied;

  WaterSyncHandler? onWaterSynced;
  VibeHandler? onVibeReceived;
  WhoIsMoreHandler? onWhoIsMoreAnswered;
  FlameLevelHandler? onFlameLevelChanged;
  RedRoomMediaHandler? onRedRoomMediaReceived;
  WordleChallengeHandler? onWordleChallengeReceived;
  WordleResultHandler? onWordleResultReceived;
  
  // DrawGame Callbacks
  DrawStrokeHandler? onDrawStrokeReceived;
  DrawClearHandler? onDrawCleared;
  DrawGuessResultHandler? onDrawGuessResult;

  // ── Connect ───────────────────────────────────────────────────────────────

  Future<void> connect(String accessToken) async {
    if (_hub != null) return;
    _setStatus(HubConnectionStatus.connecting);

    _hub = HubConnectionBuilder()
      .withUrl(
        AppConfig.hubUrl,
        options: HttpConnectionOptions(
          accessTokenFactory: () async => accessToken,
          transport: kIsWeb ? null : HttpTransportType.WebSockets,
          skipNegotiation: kIsWeb ? false : true,
        ),
      )
      .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000])
      .build();

    _hub!.onclose(({error}) {
      if (!_disposed) _setStatus(HubConnectionStatus.disconnected);
    });
    _hub!.onreconnecting(({error}) {
      if (!_disposed) _setStatus(HubConnectionStatus.reconnecting);
    });
    _hub!.onreconnected(({connectionId}) {
      if (!_disposed) _setStatus(HubConnectionStatus.connected);
    });

    // ── Event Handlers ──────────────────────────────────────────────────

    _hub!.on('ReceiveMessage', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      final dto = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      onMessage?.call(dto);
    });

    _hub!.on('PartnerTyping', (args) {
      if (args == null || args.isEmpty) return;
      final raw      = args[0] as Map?;
      final senderId = raw?['senderId']?.toString() ?? '';
      final isTyping = raw?['isTyping'] as bool? ?? false;
      onPartnerTyping?.call(senderId, isTyping);
    });

    _hub!.on('MessageSent', (args) {
      // Sender acknowledgment — can update delivery status
    });

    _hub!.on('MessageRead', (args) {
      // Partner read the message
    });

    _hub!.on('Error', (args) {
      final msg = args?.isNotEmpty == true ? args![0]?.toString() : 'Unknown error';
      // ignore: avoid_print
      print('[SignalR] Error: $msg');
    });

    // ── Location Events ──────────────────────────────────────────────────

    _hub!.on('LocationRequested', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      final dto = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      onLocationRequested?.call(dto);
    });

    _hub!.on('LocationShared', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      final dto = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      onLocationShared?.call(dto);
    });

    _hub!.on('LocationDenied', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      final dto = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      onLocationDenied?.call(dto);
    });

    // ── Vibe & Sync Events ──────────────────────────────────────────────────

    _hub!.on('WaterSynced', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0] as Map?;
      final senderId = raw?['senderId']?.toString() ?? '';
      final count = raw?['waterCount'] as int? ?? 0;
      onWaterSynced?.call(senderId, count);
    });

    _hub!.on('VibeReceived', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0] as Map?;
      final senderId = raw?['senderId']?.toString() ?? '';
      final vibeType = raw?['vibeType']?.toString() ?? '';
      onVibeReceived?.call(senderId, vibeType);
    });

    // ── Games & Red Room Events ─────────────────────────────────────────────

    _hub!.on('WhoIsMoreAnswered', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0] as Map?;
      final senderId = raw?['senderId']?.toString() ?? '';
      final questionId = raw?['questionId']?.toString() ?? '';
      final answer = raw?['answer']?.toString() ?? '';
      onWhoIsMoreAnswered?.call(senderId, questionId, answer);
    });

    _hub!.on('FlameLevelChanged', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0] as Map?;
      final senderId = raw?['senderId']?.toString() ?? '';
      final level = (raw?['level'] as num?)?.toDouble() ?? 0.0;
      onFlameLevelChanged?.call(senderId, level);
    });

    _hub!.on('RedRoomMediaReceived', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0] as Map?;
      final senderId = raw?['senderId']?.toString() ?? '';
      final mediaId = raw?['mediaId']?.toString() ?? '';
      final timeoutSeconds = raw?['timeoutSeconds'] as int? ?? 10;
      onRedRoomMediaReceived?.call(senderId, mediaId, timeoutSeconds);
    });
    
    _hub!.on('WordleChallengeReceived', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0] as Map?;
      final senderId = raw?['senderId']?.toString() ?? '';
      final word = raw?['encryptedWord']?.toString() ?? '';
      onWordleChallengeReceived?.call(senderId, word);
    });

    _hub!.on('WordleResultReceived', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0] as Map?;
      final senderId = raw?['senderId']?.toString() ?? '';
      final attempts = raw?['attempts'] as int? ?? 0;
      final isDaily = raw?['isDaily'] as bool? ?? true;
      onWordleResultReceived?.call(senderId, attempts, isDaily);
    });
    
    // ── DrawGame Events ─────────────────────────────────────────────────────
    
    _hub!.on('DrawStrokeReceived', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      final dto = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      onDrawStrokeReceived?.call(dto);
    });

    _hub!.on('DrawCleared', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      final dto = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      onDrawCleared?.call(dto);
    });

    _hub!.on('DrawGuessResult', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      final dto = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      onDrawGuessResult?.call(dto);
    });

    // ── Start ────────────────────────────────────────────────────────────

    try {
      await _hub!.start();
      _setStatus(HubConnectionStatus.connected);
    } catch (e) {
      _setStatus(HubConnectionStatus.disconnected);
      _scheduleRetry(accessToken);
    }
  }

  // ── Send Methods ──────────────────────────────────────────────────────────

  Future<void> sendMessage({
    required String receiverId,
    required String encryptedText,
    String? encryptedTextForSender,
    String? iv,
    String? mediaId,
    int type = 0,
  }) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SendMessageAsync', args: [
      {
        'receiverId':            receiverId,
        'encryptedText':         encryptedText,
        'encryptedTextForSender': encryptedTextForSender,
        'iV':                    iv,
        'mediaId':               mediaId,
        'type':                  type,
      }
    ]);
  }

  Future<void> sendTyping(String partnerId, bool isTyping) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SendTypingAsync', args: [partnerId, isTyping]);
  }

  Future<void> requestLocation(String partnerId) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('RequestLocationAsync', args: [partnerId]);
  }

  Future<void> shareLocation(String requesterId, String encryptedPayload) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('ShareLocationAsync', args: [requesterId, encryptedPayload]);
  }

  Future<void> denyLocation(String requesterId) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('DenyLocationAsync', args: [requesterId]);
  }

  // ── Vibe & Sync Sends ─────────────────────────────────────────────────────

  Future<void> syncWater(String partnerId, int waterCount) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SyncWaterAsync', args: [partnerId, waterCount]);
  }

  Future<void> sendVibe(String partnerId, String vibeType) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SendVibeAsync', args: [partnerId, vibeType]);
  }

  // ── Games & Red Room Sends ────────────────────────────────────────────────

  Future<void> sendWhoIsMoreAnswer(String partnerId, String questionId, String answer) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SendWhoIsMoreAnswerAsync', args: [partnerId, questionId, answer]);
  }

  Future<void> sendFlameLevel(String partnerId, double level) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SendFlameLevelAsync', args: [partnerId, level]);
  }

  Future<void> sendRedRoomMedia(String partnerId, String mediaId, int timeoutSeconds) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SendRedRoomMediaAsync', args: [partnerId, mediaId, timeoutSeconds]);
  }

  Future<void> sendWordleChallenge(String partnerId, String encryptedWord) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SendWordleChallengeAsync', args: [partnerId, encryptedWord]);
  }

  Future<void> sendWordleResult(String partnerId, int attempts, bool isDaily) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SendWordleResultAsync', args: [partnerId, attempts, isDaily]);
  }

  // ── DrawGame Sends ────────────────────────────────────────────────────────

  Future<void> sendDrawStroke(String partnerId, Map<String, dynamic> dto) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('DrawStrokeAsync', args: [partnerId, dto]);
  }

  Future<void> sendDrawClear(String partnerId, String sessionId) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('DrawClearAsync', args: [partnerId, sessionId]);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    await _hub?.stop();
    _hub = null;
    _setStatus(HubConnectionStatus.disconnected);
  }

  void dispose() {
    _disposed = true;
    _hub?.stop();
  }

  void _setStatus(HubConnectionStatus s) =>
      _ref.read(hubStatusProvider.notifier).state = s;

  void _scheduleRetry(String token) {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_disposed && _hub?.state != HubConnectionState.Connected) {
        _hub = null;
        connect(token);
      }
    });
  }
}
