import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/auth_notifier.dart';
import 'features/auth/domain/auth_state.dart';
import 'screens/biometric_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() {
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
    return switch (status) {
      AuthStatus.unknown          => const _Splash(),
      AuthStatus.unauthenticated  => const LoginScreen(),
      AuthStatus.biometricPending => const BiometricScreen(),
      AuthStatus.authenticated    => const MainScreen(),
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
