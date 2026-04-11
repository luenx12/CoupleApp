import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:io' show Platform;

class AppConfig {
  AppConfig._();

  // Web/Windows → localhost, Android emülatör → 10.0.2.2
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5193';
    if (Platform.isWindows) return 'http://localhost:5193';
    return 'http://10.0.2.2:5193';
  }

  static String get hubUrl  => '$baseUrl/hubs/couple';
  static String get apiUrl  => '$baseUrl/api';

  static const List<int> reconnectDelaysMs = [0, 2000, 5000, 10000, 30000];
}
