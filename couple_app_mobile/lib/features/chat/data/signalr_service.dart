// ═══════════════════════════════════════════════════════════════════════════════
// SignalRService — Real-time hub connection
// v3: Robust reconnect + onReconnected callback for outbox flush
// Handles: messages, typing, location events
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:signalr_netcore/ihub_protocol.dart';
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
typedef MessageHandler    = void Function(Map<String, dynamic> dto);
typedef TypingHandler     = void Function(String senderId, bool isTyping);
typedef LocationHandler   = void Function(Map<String, dynamic> payload);
typedef WaterSyncHandler  = void Function(String senderId, int count);
typedef VibeHandler       = void Function(String senderId, String vibeType);
typedef ReconnectedHandler = void Function();

typedef WhoIsMoreHandler      = void Function(String senderId, String questionId, String answer);
typedef FlameLevelHandler     = void Function(String senderId, double level);
typedef RedRoomMediaHandler   = void Function(String senderId, String mediaId, int timeoutSeconds);

// Wordle handlers
typedef WordleChallengeHandler = void Function(String senderId, String encryptedWord);
typedef WordleResultHandler    = void Function(String senderId, int attempts, bool isDaily);

// DrawGame handlers
typedef DrawStrokeHandler      = void Function(Map<String, dynamic> dto);
typedef DrawClearHandler       = void Function(Map<String, dynamic> dto);
typedef DrawGuessResultHandler = void Function(Map<String, dynamic> dto);

// ── Red Room handlers ──────────────────────────────────────────────────────
typedef DiceResultHandler       = void Function(Map<String, dynamic> result);
typedef PartnerSwipedHandler    = void Function(String senderId, String itemId, String direction);
typedef RedMatchHandler         = void Function(String itemId, DateTime matchedAt);
typedef RoleplayHandler         = void Function(Map<String, dynamic> result);
typedef BodyMapHandler          = void Function(String senderId, String pointsJson);
typedef RouletteResultHandler   = void Function(Map<String, dynamic> result);
typedef SafeWordHandler         = void Function(String senderId);
typedef DarkRoomHandler         = void Function(Map<String, dynamic> payload);
typedef SpotlightMovedHandler   = void Function(double x, double y, int ts);
typedef HeatmapUpdatedHandler   = void Function(String heatmapJson);

class SignalRService {
  SignalRService(this._ref);

  final Ref _ref;
  HubConnection? _hub;
  bool _disposed = false;

  // Stored token for manual retry
  String _lastToken = '';

  // Retry state for manual reconnect loop
  int _manualRetryCount = 0;
  static const _manualRetryDelays = [5000, 15000, 30000, 60000];
  Timer? _retryTimer;

  // Callbacks registered by ChatNotifier / LocationNotifier
  MessageHandler?     onMessage;
  TypingHandler?      onPartnerTyping;
  LocationHandler?    onLocationRequested;
  LocationHandler?    onLocationShared;
  LocationHandler?    onLocationDenied;

  /// Called when SignalR successfully reconnects (after a drop).
  /// ChatNotifier uses this to trigger outbox flush.
  ReconnectedHandler? onReconnected;

  WaterSyncHandler?  onWaterSynced;
  VibeHandler?       onVibeReceived;
  WhoIsMoreHandler?  onWhoIsMoreAnswered;
  FlameLevelHandler? onFlameLevelChanged;
  RedRoomMediaHandler? onRedRoomMediaReceived;
  WordleChallengeHandler? onWordleChallengeReceived;
  WordleResultHandler?    onWordleResultReceived;
  
  // DrawGame Callbacks
  DrawStrokeHandler?      onDrawStrokeReceived;
  DrawClearHandler?       onDrawCleared;
  DrawGuessResultHandler? onDrawGuessResult;

  // ── Red Room Callbacks ─────────────────────────────────────────────────
  DiceResultHandler?     onDiceResult;
  PartnerSwipedHandler?  onPartnerSwiped;
  RedMatchHandler?       onRedMatch;
  RoleplayHandler?       onRoleplayGenerated;
  BodyMapHandler?        onBodyMapUpdated;
  RouletteResultHandler? onRouletteResult;
  SafeWordHandler?       onSafeWordTriggered;
  DarkRoomHandler?       onDarkRoomStarted;
  SpotlightMovedHandler? onSpotlightMoved;
  HeatmapUpdatedHandler? onHeatmapUpdated;

  // ── Current connection status (publicly readable) ─────────────────────
  HubConnectionStatus get status =>
      _ref.read(hubStatusProvider);

  bool get isConnected =>
      _hub?.state == HubConnectionState.Connected;

  // ── Connect ───────────────────────────────────────────────────────────────

  Future<void> connect(String accessToken) async {
    if (_disposed) return;
    if (_hub != null && _hub!.state == HubConnectionState.Connected) return;

    _lastToken = accessToken;

    // If hub already exists but not connected, stop it first
    if (_hub != null) {
      try { await _hub!.stop(); } catch (_) {}
      _hub = null;
    }

    _setStatus(HubConnectionStatus.connecting);

    // Always read the latest token from storage (handles token refresh)
    const storage = FlutterSecureStorage();
    final latestToken =
        await storage.read(key: 'access_token') ?? accessToken;

    _hub = HubConnectionBuilder()
      .withUrl(
        AppConfig.hubUrl,
        options: HttpConnectionOptions(
          accessTokenFactory: () async {
            // Always read fresh token from secure storage on each call
            return await storage.read(key: 'access_token') ?? latestToken;
          },
          // Do NOT skip negotiation — the negotiate endpoint validates JWT
          // and selects the best transport. skipNegotiation=true only works
          // when you can guarantee a direct WebSocket path, which Nginx
          // requires special handling for.
          skipNegotiation: false,
          // Allow all transports; SignalR will negotiate best one
          transport: null,
          headers: MessageHeaders()..setHeaderValue('Authorization', 'Bearer $latestToken'),
        ),
      )
      .withAutomaticReconnect(retryDelays: AppConfig.reconnectDelaysMs)
      .build();

    _hub!.onclose(({error}) {
      if (_disposed) return;
      _setStatus(HubConnectionStatus.disconnected);
      // Automatic reconnect exhausted all delays → start manual retry loop
      _startManualRetryLoop();
    });

    _hub!.onreconnecting(({error}) {
      if (!_disposed) _setStatus(HubConnectionStatus.reconnecting);
    });

    _hub!.onreconnected(({connectionId}) {
      if (_disposed) return;
      _manualRetryCount = 0;
      _retryTimer?.cancel();
      _setStatus(HubConnectionStatus.connected);
      // ✅ KEY FIX: notify ChatNotifier to flush pending outbox messages
      onReconnected?.call();
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
      final senderId   = raw?['senderId']?.toString() ?? '';
      final questionId = raw?['questionId']?.toString() ?? '';
      final answer     = raw?['answer']?.toString() ?? '';
      onWhoIsMoreAnswered?.call(senderId, questionId, answer);
    });

    _hub!.on('FlameLevelChanged', (args) {
      if (args == null || args.isEmpty) return;
      final raw      = args[0] as Map?;
      final senderId = raw?['senderId']?.toString() ?? '';
      final level    = (raw?['level'] as num?)?.toDouble() ?? 0.0;
      onFlameLevelChanged?.call(senderId, level);
    });

    _hub!.on('RedRoomMediaReceived', (args) {
      if (args == null || args.isEmpty) return;
      final raw            = args[0] as Map?;
      final senderId       = raw?['senderId']?.toString() ?? '';
      final mediaId        = raw?['mediaId']?.toString() ?? '';
      final timeoutSeconds = raw?['timeoutSeconds'] as int? ?? 10;
      onRedRoomMediaReceived?.call(senderId, mediaId, timeoutSeconds);
    });
    
    _hub!.on('WordleChallengeReceived', (args) {
      if (args == null || args.isEmpty) return;
      final raw      = args[0] as Map?;
      final senderId = raw?['senderId']?.toString() ?? '';
      final word     = raw?['encryptedWord']?.toString() ?? '';
      onWordleChallengeReceived?.call(senderId, word);
    });

    _hub!.on('WordleResultReceived', (args) {
      if (args == null || args.isEmpty) return;
      final raw      = args[0] as Map?;
      final senderId = raw?['senderId']?.toString() ?? '';
      final attempts = raw?['attempts'] as int? ?? 0;
      final isDaily  = raw?['isDaily'] as bool? ?? true;
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

    // ── Red Room Events ───────────────────────────────────────────────────

    _hub!.on('DiceResult', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      final dto = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      onDiceResult?.call(dto);
    });

    _hub!.on('PartnerSwiped', (args) {
      if (args == null || args.isEmpty) return;
      final raw       = args[0] as Map?;
      final senderId  = raw?['senderId']?.toString() ?? '';
      final itemId    = raw?['itemId']?.toString() ?? '';
      final direction = raw?['direction']?.toString() ?? '';
      onPartnerSwiped?.call(senderId, itemId, direction);
    });

    _hub!.on('RedMatch', (args) {
      if (args == null || args.isEmpty) return;
      final raw       = args[0] as Map?;
      final itemId    = raw?['itemId']?.toString() ?? '';
      final matchedAt = DateTime.tryParse(raw?['matchedAt']?.toString() ?? '') ?? DateTime.now();
      onRedMatch?.call(itemId, matchedAt);
    });

    _hub!.on('RoleplayGenerated', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      final dto = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      onRoleplayGenerated?.call(dto);
    });

    _hub!.on('BodyMapUpdated', (args) {
      if (args == null || args.isEmpty) return;
      final raw        = args[0] as Map?;
      final senderId   = raw?['senderId']?.toString() ?? '';
      final pointsJson = raw?['pointsJson']?.toString() ?? '';
      onBodyMapUpdated?.call(senderId, pointsJson);
    });

    _hub!.on('RouletteResult', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      final dto = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      onRouletteResult?.call(dto);
    });

    _hub!.on('SafeWordTriggered', (args) {
      if (args == null || args.isEmpty) return;
      final raw      = args[0] as Map?;
      final senderId = raw?['senderId']?.toString() ?? '';
      onSafeWordTriggered?.call(senderId);
    });

    _hub!.on('DarkRoomStarted', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0];
      final dto = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      onDarkRoomStarted?.call(dto);
    });

    _hub!.on('SpotlightMoved', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args[0] as Map?;
      final x   = (raw?['x'] as num?)?.toDouble() ?? 0.0;
      final y   = (raw?['y'] as num?)?.toDouble() ?? 0.0;
      final ts  = raw?['ts'] as int? ?? 0;
      onSpotlightMoved?.call(x, y, ts);
    });

    _hub!.on('HeatmapUpdated', (args) {
      if (args == null || args.isEmpty) return;
      final raw         = args[0] as Map?;
      final heatmapJson = raw?['heatmapJson']?.toString() ?? '';
      onHeatmapUpdated?.call(heatmapJson);
    });

    // ── Start ────────────────────────────────────────────────────────────

    try {
      await _hub!.start();
      _manualRetryCount = 0;
      _retryTimer?.cancel();
      _setStatus(HubConnectionStatus.connected);
      // Connected fresh (not reconnect) → also notify to flush outbox
      onReconnected?.call();
    } catch (e) {
      _setStatus(HubConnectionStatus.disconnected);
      _startManualRetryLoop();
    }
  }

  // ── Manual retry loop (runs after automatic reconnect gives up) ───────────

  void _startManualRetryLoop() {
    if (_disposed) return;
    _retryTimer?.cancel();

    final delayMs = _manualRetryCount < _manualRetryDelays.length
        ? _manualRetryDelays[_manualRetryCount]
        : _manualRetryDelays.last; // stay at max delay

    _manualRetryCount++;

    // ignore: avoid_print
    print('[SignalR] Manual retry #$_manualRetryCount in ${delayMs}ms...');

    _retryTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_disposed) {
        _hub = null;
        connect(_lastToken);
      }
    });
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

  // ── Red Room Sends ─────────────────────────────────────────────────────────

  Future<void> rollDice(String partnerId) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('RollDiceAsync', args: [partnerId]);
  }

  Future<void> swipeFantasy(String partnerId, String itemId, String direction) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SwipeFantasyAsync', args: [partnerId, itemId, direction]);
  }

  Future<void> generateRoleplay(String partnerId) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('GenerateRoleplayAsync', args: [partnerId]);
  }

  Future<void> sendBodyMap(String partnerId, String pointsJson) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SendBodyMapAsync', args: [partnerId, pointsJson]);
  }

  Future<void> spinRoulette(String partnerId) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SpinRouletteAsync', args: [partnerId]);
  }

  Future<void> sendSpotlightMove(String partnerId, double x, double y) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SendSpotlightMoveAsync', args: [partnerId, x, y]);
  }

  Future<void> startDarkRoom(String partnerId, String encryptedMediaId) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('StartDarkRoomAsync', args: [partnerId, encryptedMediaId]);
  }

  Future<void> triggerSafeWord(String partnerId) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('TriggerSafeWordAsync', args: [partnerId]);
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
    _retryTimer?.cancel();
    await _hub?.stop();
    _hub = null;
    _setStatus(HubConnectionStatus.disconnected);
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _hub?.stop();
  }

  void _setStatus(HubConnectionStatus s) =>
      _ref.read(hubStatusProvider.notifier).state = s;
}
