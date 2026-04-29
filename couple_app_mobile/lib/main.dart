import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/auth_notifier.dart';
import 'features/auth/domain/auth_state.dart';
import 'features/crypto/crypto_provider.dart';
import 'screens/biometric_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'features/chat/domain/fantasy_board_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ağ bağlantısı izlemeyi başlat (offline-first outbox queue)
  await ConnectivityService.instance.init();
  // Fantasy görevlerini yükle
  await FantasyBoardPayload.loadTasks();
  // Firebase'i erken başlat — background handler kayıt olabilsin
  // (auth'dan önce gelir; token kaydı auth akışında ayrıca yapılır)
  await FirebaseMessagingService().initialize();
  runApp(const ProviderScope(child: CoupleApp()));
}

class CoupleApp extends ConsumerWidget {
  const CoupleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'CoupleApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authNotifierProvider).status;

    if (status == AuthStatus.authenticated) {
      // RSA anahtar çifti yükleniyor / üretiliyor (ilk açılışta ~1-2 sn)
      final cryptoInit = ref.watch(cryptoInitProvider);
      return cryptoInit.when(
        loading: () => const _CryptoInitScreen(),
        error:   (e, _) => const _Splash(),  // retry mekanizması eklenebilir
        data:    (_) => const MainScreen(),
      );
    }

    return switch (status) {
      AuthStatus.unknown          => const _Splash(),
      AuthStatus.unauthenticated  => const LoginScreen(),
      AuthStatus.biometricPending => const BiometricScreen(),
      AuthStatus.authenticated    => const MainScreen(), // unreachable, covered above
    };
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    ),
  );
}

// Gösterilen ekran: RSA anahtar çifti üretilirken (ilk açılışta ~1-2 saniye)
class _CryptoInitScreen extends StatelessWidget {
  const _CryptoInitScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 20),
            Text(
              '🔐 Şifreleme anahtarları hazırlanıyor…',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
