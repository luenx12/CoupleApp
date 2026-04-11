import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_state.dart';
import '../../../core/config/app_config.dart';

final localAuthProvider  = Provider<LocalAuthentication>((_) => LocalAuthentication());

final dioProvider = Provider<Dio>((ref) => Dio(
  BaseOptions(
    baseUrl: AppConfig.apiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ),
));

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
  }

  Future<void> login(String username, String password) async {
    try {
      final res = await _dio.post('/Auth/login',
          data: {'username': username, 'password': password});
      final token  = res.data['accessToken'] as String;
      final userId = res.data['id']           as String;
      final uname  = res.data['username']     as String;
      await _storage.write(key: 'access_token', value: token);
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
    await _storage.deleteAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
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
      final res = await dio.get('/Auth/partner');
      final data = res.data as Map<String, dynamic>;
      state = state.copyWith(
        partnerId:        data['id']?.toString(),
        partnerName:      data['username']?.toString(),
        partnerPublicKey: data['publicKey']?.toString(),
      );
    } catch (_) {
      // Partner kayıtlı değilse sessizce geç
    }
  }
}

