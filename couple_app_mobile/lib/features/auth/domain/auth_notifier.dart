import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';
import 'auth_state.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/firebase_messaging_service.dart';

final localAuthProvider  = Provider<LocalAuthentication>((_) => LocalAuthentication());

// The Dio provider with Interceptor attached
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  dio.interceptors.add(AuthInterceptor(dio, ref.read(secureStorageProvider), ref));
  return dio;
});

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final FlutterSecureStorage storage;
  final ProviderRef ref;

  AuthInterceptor(this.dio, this.storage, this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Access token expired, attempt refresh
      final refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        try {
          // Send request with an isolated Dio instance to prevent interceptor loop
          final refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiUrl));
          final res = await refreshDio.post('/Auth/refresh', data: {
            'refreshToken': refreshToken
          });

          final newAccess = res.data['accessToken'];
          final newRefresh = res.data['refreshToken'];

          // Save new tokens
          await storage.write(key: 'access_token', value: newAccess);
          await storage.write(key: 'refresh_token', value: newRefresh);

          // Retry the original request
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          final cloneReq = await dio.request(
            err.requestOptions.path,
            options: Options(
              method: err.requestOptions.method,
              headers: err.requestOptions.headers,
            ),
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
          );
          
          return handler.resolve(cloneReq);
        } catch (_) {
          // Token rotation failed or refresh token expired -> Logout
          ref.read(authNotifierProvider.notifier).logout();
        }
      } else {
        ref.read(authNotifierProvider.notifier).logout();
      }
    }
    return handler.next(err);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(
          ref.read(localAuthProvider),
          ref.read(dioProvider),
          ref.read(secureStorageProvider),
        ));

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._localAuth, this._dio, this._storage)
      : super(const AuthState()) {
    _init();
  }

  final LocalAuthentication _localAuth;
  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<void> _init() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      state = state.copyWith(
        status:      AuthStatus.biometricPending,
        accessToken: token,
      );
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        await _loadUserFromStorage();
        return true;
      }

      final didAuth = await _localAuth.authenticate(
        localizedReason: 'CoupleApp\'a erişmek için kimliğini doğrula',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );

      if (didAuth) await _loadUserFromStorage();
      return didAuth;
    } catch (_) {
      await _loadUserFromStorage();
      return true;
    }
  }

  Future<void> _loadUserFromStorage() async {
    final userId   = await _storage.read(key: 'user_id');
    final username = await _storage.read(key: 'username');
    final token    = await _storage.read(key: 'access_token');
    state = state.copyWith(
      status:      AuthStatus.authenticated,
      userId:      userId,
      username:    username,
      accessToken: token,
    );
    // Partner bilgisini arka planda yükle
    await _fetchPartner(token);
    await _registerDeviceToken(token);
  }

  Future<void> login(String username, String password) async {
    try {
      final res = await _dio.post('/Auth/login',
          data: {'username': username, 'password': password});
      final token     = res.data['accessToken'] as String;
      final refresh   = res.data['refreshToken'] as String;
      final userId    = res.data['id']           as String;
      final uname     = res.data['username']     as String;
      await _storage.write(key: 'access_token', value: token);
      await _storage.write(key: 'refresh_token', value: refresh);
      await _storage.write(key: 'user_id',      value: userId);
      await _storage.write(key: 'username',     value: uname);
      state = state.copyWith(
        status:      AuthStatus.authenticated,
        accessToken: token,
        userId:      userId,
        username:    uname,
      );
      // Partner bilgisini yükle
      await _fetchPartner(token);
      await _registerDeviceToken(token);
    } on DioException catch (e) {
      state = state.copyWith(
          errorMessage: e.response?.data?.toString() ?? 'Giriş başarısız.');
    }
  }

  Future<void> register(String username, String password) async {
    try {
      await _dio.post('/Auth/register',
          data: {'username': username, 'password': password});
      await login(username, password);
    } on DioException catch (e) {
      state = state.copyWith(
          errorMessage: e.response?.data?.toString() ?? 'Kayıt başarısız.');
    }
  }

  Future<void> logout() async {
    try {
      final token = state.accessToken;
      if (token != null) {
        await _dio.post('/Auth/revoke');
      }
    } catch (_) {}

    await _storage.deleteAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _registerDeviceToken(String? accessToken) async {
    if (accessToken == null) return;
    try {
      final fcmService = FirebaseMessagingService();
      await fcmService.initialize();
      final deviceToken = await fcmService.getToken();
      
      if (deviceToken != null) {
        final platform = Platform.isIOS ? 'ios' : 'android';
        await _dio.post('/Auth/device-token', data: {
          'token': deviceToken,
          'platform': platform
        });
      }

      // Background listener for token rotation silently updating backend
      fcmService.onTokenRefresh.listen((newToken) async {
        try {
          final platform = Platform.isIOS ? 'ios' : 'android';
          await _dio.post('/Auth/device-token', data: {
            'token': newToken,
            'platform': platform
          });
        } catch (_) {}
      });
    } catch (_) {
      // Non-blocking fallback if Firebase throws exceptions
    }
  }

  Future<void> _fetchPartner(String? token) async {
    if (token == null) return;
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiUrl,
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final res = await dio.get('/couple/partner');
      final data = res.data as Map<String, dynamic>;
      state = state.copyWith(
        partnerId:        data['id']?.toString(),
        partnerName:      data['username']?.toString(),
        partnerPublicKey: data['publicKey']?.toString(),
      );
    } catch (_) {
      // If no partner is found or request fails, clear partner data
      state = state.copyWith(
        partnerId: null,
        partnerName: null,
        partnerPublicKey: null,
      );
    }
  }

  Future<String?> invitePartner() async {
    final token = state.accessToken;
    if (token == null) return null;
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiUrl,
        headers: {'Authorization': 'Bearer $token'},
      ));
      final res = await dio.post('/couple/invite');
      return res.data['inviteCode'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> joinWithCode(String code) async {
    final token = state.accessToken;
    if (token == null) return false;
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiUrl,
        headers: {'Authorization': 'Bearer $token'},
      ));
      await dio.post('/couple/join/$code');
      await _fetchPartner(token); // Load the newly joined partner
      return true;
    } catch (_) {
      return false;
    }
  }
}

