import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/domain/auth_notifier.dart';

class BiometricScreen extends ConsumerStatefulWidget {
  const BiometricScreen({super.key});
  @override
  ConsumerState<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends ConsumerState<BiometricScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    setState(() { _loading = true; _error = null; });
    final ok = await ref.read(authNotifierProvider.notifier).authenticateWithBiometrics();
    if (!ok && mounted) setState(() { _loading = false; _error = 'Kimlik doğrulama başarısız.'; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(120), blurRadius: 40, spreadRadius: 8)],
                    ),
                    child: const Icon(Icons.fingerprint, size: 64, color: Colors.white),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .scaleXY(end: 1.08, duration: 1200.ms, curve: Curves.easeInOut),

                  const SizedBox(height: 36),

                  Text('Güvenli Erişim',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800, color: AppColors.onSurface),
                  ).animate().fadeIn(duration: 600.ms),

                  const SizedBox(height: 12),

                  Text('CoupleApp\'a erişmek için\nbiyometrik doğrulama gerekiyor',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceMuted, height: 1.5),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 48),

                  if (_loading)
                    const CircularProgressIndicator(color: AppColors.primary)
                  else ...[
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(100), blurRadius: 15, offset: const Offset(0, 6))],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _authenticate,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Kimliğini Doğrula'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
