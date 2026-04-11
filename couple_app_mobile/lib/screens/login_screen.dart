import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/domain/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isRegister = false;
  bool _obscure    = true;
  bool _loading    = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    if (_isRegister) {
      await ref.read(authNotifierProvider.notifier)
          .register(_userCtrl.text.trim(), _passCtrl.text);
    } else {
      await ref.read(authNotifierProvider.notifier)
          .login(_userCtrl.text.trim(), _passCtrl.text);
    }

    if (!mounted) return;
    setState(() => _loading = false);

    final err = ref.read(authNotifierProvider).errorMessage;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withAlpha(120), blurRadius: 40, spreadRadius: 5),
                        ],
                      ),
                      child: const Icon(Icons.favorite_rounded, size: 56, color: Colors.white),
                    ).animate().scale(duration: 600.ms, curve: Curves.elasticOut).fadeIn(),

                    const SizedBox(height: 32),

                    Text(
                      _isRegister ? 'Hesap Oluştur' : 'Hoş Geldin 💕',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800, color: AppColors.onSurface),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 8),

                    Text('Özel, güvenli alanınız',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 36),

                    TextFormField(
                      controller: _userCtrl,
                      style: const TextStyle(color: AppColors.onSurface),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline, color: AppColors.onSurfaceMuted),
                        labelText: 'Kullanıcı Adı',
                      ),
                      validator: (v) => v == null || v.length < 3 ? 'En az 3 karakter' : null,
                    ).animate().slideX(begin: -0.2, duration: 400.ms, delay: 100.ms).fadeIn(),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(color: AppColors.onSurface),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.onSurfaceMuted),
                        labelText: 'Şifre',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.onSurfaceMuted),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => v == null || v.length < 6 ? 'En az 6 karakter' : null,
                    ).animate().slideX(begin: 0.2, duration: 400.ms, delay: 200.ms).fadeIn(),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(100), blurRadius: 15, offset: const Offset(0, 6))],
                              ),
                              child: ElevatedButton(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                                child: Text(_isRegister ? 'Kayıt Ol' : 'Giriş Yap'),
                              ),
                            ),
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 20),

                    TextButton(
                      onPressed: () => setState(() => _isRegister = !_isRegister),
                      child: Text(
                        _isRegister ? 'Zaten hesabın var mı? Giriş yap' : 'Hesabın yok mu? Kaydol',
                        style: const TextStyle(color: AppColors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
