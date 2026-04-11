class AppConfig {
  AppConfig._();

  // Android emülatör için → localhost
  // Gerçek cihaz için kendi IP adresinizi yazın
  static const String baseUrl = 'http://10.0.2.2:5193';
  static const String hubUrl  = '$baseUrl/hubs/couple';
  static const String apiUrl  = '$baseUrl/api';

  static const List<int> reconnectDelaysMs = [0, 2000, 5000, 10000, 30000];
}
