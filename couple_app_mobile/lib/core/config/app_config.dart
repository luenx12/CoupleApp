class AppConfig {
  AppConfig._();

  // Web/Windows → localhost, Android emülatör → 10.0.2.2
  static String get baseUrl {
    // VPS Production IP (Nginx: 80, Direct Backend: 5000)
    return 'http://209.38.238.55'; 
    
    // For local development:
    // if (kIsWeb) return 'http://localhost:5193';
    // if (Platform.isWindows) return 'http://localhost:5193';
    // return 'http://10.0.2.2:5193';
  }

  static String get hubUrl  => '$baseUrl/hubs/couple';
  static String get apiUrl  => '$baseUrl/api';

  static const List<int> reconnectDelaysMs = [0, 2000, 5000, 10000, 30000];
}
