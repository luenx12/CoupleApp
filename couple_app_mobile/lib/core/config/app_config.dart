import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  AppConfig._();

  // Web/Windows → localhost, Android emülatör → 10.0.2.2
  static String get baseUrl =>
      kIsWeb ? 'http://localhost:5193' : 'http://10.0.2.2:5193';

  static String get hubUrl  => '$baseUrl/hubs/couple';
  static String get apiUrl  => '$baseUrl/api';

  static const List<int> reconnectDelaysMs = [0, 2000, 5000, 10000, 30000];
}
