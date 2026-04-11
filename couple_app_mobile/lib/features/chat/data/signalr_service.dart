import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../../../core/config/app_config.dart';

enum HubConnectionStatus { disconnected, connecting, connected, reconnecting }

final hubStatusProvider = StateProvider<HubConnectionStatus>(
  (_) => HubConnectionStatus.disconnected,
);

final signalRServiceProvider = Provider<SignalRService>((ref) {
  final svc = SignalRService(ref);
  ref.onDispose(svc.dispose);
  return svc;
});

class SignalRService {
  SignalRService(this._ref);

  final Ref _ref;
  HubConnection? _hub;
  bool _disposed = false;

  Future<void> connect(String accessToken) async {
    if (_hub != null) return;
    _setStatus(HubConnectionStatus.connecting);

    _hub = HubConnectionBuilder()
      .withUrl(
        AppConfig.hubUrl,
        options: HttpConnectionOptions(
          accessTokenFactory: () async => accessToken,
          transport: HttpTransportType.WebSockets,
          skipNegotiation: true,
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

    _hub!.on('ReceiveMessage', _onReceiveMessage);
    _hub!.on('PartnerTyping',  _onPartnerTyping);
    _hub!.on('Error',          _onError);

    try {
      await _hub!.start();
      _setStatus(HubConnectionStatus.connected);
    } catch (e) {
      _setStatus(HubConnectionStatus.disconnected);
      _scheduleRetry(accessToken);
    }
  }

  Future<void> sendMessage({
    required String receiverId,
    required String encryptedText,
    String? iv,
    int type = 0,
  }) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SendMessageAsync', args: [
      {'receiverId': receiverId, 'encryptedText': encryptedText, 'iV': iv, 'type': type}
    ]);
  }

  Future<void> sendTyping(String partnerId, bool isTyping) async {
    if (_hub?.state != HubConnectionState.Connected) return;
    await _hub!.invoke('SendTypingAsync', args: [partnerId, isTyping]);
  }

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

  void _onReceiveMessage(List<Object?>? args) {}
  void _onPartnerTyping(List<Object?>? args) {}
  void _onError(List<Object?>? args) {}
}
