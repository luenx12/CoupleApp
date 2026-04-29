// ═══════════════════════════════════════════════════════════════════════════════
// FirebaseMessagingService — FCM push + local notifications
//
// WhatsApp mantığı:
//  • Uygulama kapalı / arka planda → FCM data push → local bildirim göster
//  • Bildirime tıklayınca → app açılır → callback tetiklenir (sync / konum diyaloğu)
//  • Foreground → local bildirim göster + hemen sync tetikle
//
// Timing güvenliği:
//  • initialize() main()'de erken çağrılır ama callback'ler henüz wire-up edilmemiş
//    olabilir. Bu yüzden "pending" alanlarında saklıyoruz; callback kaydedilince
//    otomatik tetikleniyoruz.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ── Notification channel constants ───────────────────────────────────────────

const _kChannelId   = 'couple_app_channel';
const _kChannelName = 'CoupleApp Bildirimleri';
const _kChannelDesc = 'E2EE güvenli anlık bildirimler';

// ── Background isolate handler (top-level, not inside class) ─────────────────

/// Background / terminated mesaj handler.
/// UI thread olmadığından state değiştiremeyiz; sadece loglama yapılır.
/// FCM'in kendi bildirim mekanizması Android'de zaten notification gösterir.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // ignore: avoid_print
  print('[FCM-BG] type=${message.data["type"]} title=${message.notification?.title}');
}

// ── Service ───────────────────────────────────────────────────────────────────

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ── Pending state (timing safety) ────────────────────────────────────────
  // initialize() → main() → callback wire-up → MainScreen arasında boşluk var.
  // Bu alanda bekleyen olayları saklıyoruz; callback gelince hemen tetikleriz.

  RemoteMessage?  _pendingMessageSync;
  String?         _pendingLocationRequesterId;
  ({String? type, String? payload})? _pendingTap;

  // ── Callback'ler ─────────────────────────────────────────────────────────

  Function(RemoteMessage)? _onMessageSync;
  Function(String requesterId)? _onLocationRequest;
  Function(String? type, String? payload)? _onNotificationTap;

  void setMessageSyncCallback(Function(RemoteMessage) cb) {
    _onMessageSync = cb;
    // Bekleyen sync varsa hemen tetikle
    if (_pendingMessageSync != null) {
      cb(_pendingMessageSync!);
      _pendingMessageSync = null;
    }
  }

  void setLocationRequestCallback(Function(String) cb) {
    _onLocationRequest = cb;
    // Bekleyen konum isteği varsa hemen tetikle
    if (_pendingLocationRequesterId != null) {
      cb(_pendingLocationRequesterId!);
      _pendingLocationRequesterId = null;
    }
  }

  void setNotificationTapCallback(Function(String?, String?) cb) {
    _onNotificationTap = cb;
    if (_pendingTap != null) {
      cb(_pendingTap!.type, _pendingTap!.payload);
      _pendingTap = null;
    }
  }

  // ── Initialize ───────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Bildirim izni (iOS zorunlu, Android 13+ zorunlu)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _setupLocalNotifications();
      _setupForegroundListener();
      _setupOpenedAppListener();
      // Terminated state'den bildirimle açılış kontrolü
      await _checkInitialMessage();
    }
  }

  // ── Local notification setup ──────────────────────────────────────────────

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit     = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Android bildirim kanalı
    const channel = AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDesc,
      importance: Importance.max,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onLocalNotificationTap(NotificationResponse details) {
    // payload: "type|extra" formatında gönderilir
    final parts   = (details.payload ?? '').split('|');
    final type    = parts.isNotEmpty ? parts[0] : null;
    final payload = parts.length > 1 ? parts[1] : null;
    _routeTap(type, payload);
  }

  // ── Foreground listener ───────────────────────────────────────────────────

  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final type = message.data['type'] as String?;

      // Chat sync
      _fireOrStoreSync(message);

      // Konum isteği → diyalog aç, bildirim gösterme
      if (type == 'location_request') {
        final requesterId = message.data['requesterId'] as String?;
        if (requesterId != null) {
          _fireOrStoreLocationRequest(requesterId);
          return;
        }
      }

      // Diğer tüm mesajlar için local bildirim
      _showLocalNotification(message);
    });
  }

  // ── Bildirime tıklanarak açılma (background → tap) ───────────────────────

  void _setupOpenedAppListener() {
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
  }

  Future<void> _checkInitialMessage() async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleOpenedMessage(initial);
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final type = message.data['type'] as String?;

    // Her açılışta chat sync
    _fireOrStoreSync(message);

    if (type == 'location_request') {
      final requesterId = message.data['requesterId'] as String?;
      if (requesterId != null) {
        _fireOrStoreLocationRequest(requesterId);
        _routeTap('location_request', requesterId);
      }
      return;
    }

    _routeTap(type, message.data['payload'] as String?);
  }

  // ── Pending-safe tetikleyiciler ───────────────────────────────────────────

  void _fireOrStoreSync(RemoteMessage message) {
    if (_onMessageSync != null) {
      _onMessageSync!(message);
    } else {
      _pendingMessageSync = message; // Callback gelince tetiklenecek
    }
  }

  void _fireOrStoreLocationRequest(String requesterId) {
    if (_onLocationRequest != null) {
      _onLocationRequest!(requesterId);
    } else {
      _pendingLocationRequesterId = requesterId; // Callback gelince tetiklenecek
    }
  }

  void _routeTap(String? type, String? payload) {
    if (_onNotificationTap != null) {
      _onNotificationTap!(type, payload);
    } else {
      _pendingTap = (type: type, payload: payload); // Callback gelince tetiklenecek
    }
  }

  // ── Local bildirim göster ─────────────────────────────────────────────────

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final type    = message.data['type'] as String? ?? '';
    final payload = '$type|${message.data['requesterId'] ?? ''}';

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          channelDescription: _kChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: const DarwinNotificationDetails(sound: 'default'),
      ),
      payload: payload,
    );
  }

  // ── FCM Token ─────────────────────────────────────────────────────────────

  Future<String?> getToken() async =>
      FirebaseMessaging.instance.getToken();

  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;
}
