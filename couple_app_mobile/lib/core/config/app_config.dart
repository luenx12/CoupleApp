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

  /// SignalR automatic reconnect delays (ms).
  /// Pattern: immediate → 3s → 7s → 15s → 30s → 60s → 60s (repeating)
  /// More attempts = better resilience for mobile background/sleep scenarios.
  static const List<int> reconnectDelaysMs = [
    0,      // 1st attempt: immediate
    3000,   // 2nd: 3 seconds
    7000,   // 3rd: 7 seconds
    15000,  // 4th: 15 seconds
    30000,  // 5th: 30 seconds
    60000,  // 6th: 1 minute
    60000,  // 7th+: keep trying every 1 minute
  ];
}

