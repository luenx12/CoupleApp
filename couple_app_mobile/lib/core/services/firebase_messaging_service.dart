import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background message handler. DO NOT place inside the class.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background ops
  await Firebase.initializeApp();
  // Here we do not decrypt E2EE messages, because this is just a ping.
  // The user will open the app and the foreground SignalR/HTTP fetch will grab the ciphertext.
}

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  Function(RemoteMessage)? _syncCallback;

  void setSyncCallback(Function(RemoteMessage) callback) {
    _syncCallback = callback;
  }

  Future<void> initialize() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions (primarily for iOS)
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      _setupLocalNotifications();
      _setupForegroundListener();
      
      // Handle app opened from terminated state
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null && _syncCallback != null) {
          _syncCallback!(message);
        }
      });
    }
  }

  void _setupLocalNotifications() {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle bringing app to foreground from local notification tap if desired
      },
    );
  }

  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: const AndroidNotificationDetails(
              'couple_app_channel', // id
              'CoupleApp Notifications', // name
              channelDescription: 'E2EE discreet push notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (_syncCallback != null) {
        _syncCallback!(message);
      }
    });
  }

  Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;
}
