import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/auth_notifier.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _clearCache() async {
    try {
      final dir = await getTemporaryDirectory();
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Önbellek başarıyla temizlendi! (0 sızıntı)'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _testPushNotification() async {
    try {
      final auth = ref.read(authNotifierProvider);
      if (auth.accessToken == null) throw Exception("Oturum bulunamadı");
      
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/Test/push'),
        headers: {'Authorization': 'Bearer ${auth.accessToken}'},
      );
      
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📩 Test bildirimi sunucudan tetiklendi.'), backgroundColor: AppColors.primary),
          );
        }
      } else {
        throw Exception("Status: ${res.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test bildirimi başarısız: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
        content: const Text('Kriptografik anahtarlarınız sıfırlanacak. Devam etmek istiyor musunuz?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              ref.read(authNotifierProvider.notifier).logout();
            },
            child: const Text('Çıkış Yap', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Ayarlar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionTitle('Geliştirici'),
              _buildListTile(
                icon: Icons.notifications_active_outlined,
                title: 'Test Bildirimi Gönder',
                subtitle: 'Firebase Cloud Messaging (FCM) altyapısını test eder.',
                onTap: _testPushNotification,
              ),
              _buildListTile(
                icon: Icons.cleaning_services_outlined,
                title: 'Önbelleği Temizle',
                subtitle: 'Local tmp dizinindeki RAM dışı kalıntıları siler.',
                onTap: _clearCache,
              ),
              const SizedBox(height: 30),
              _buildSectionTitle('Kimlik ve Eşleşme (E2EE)'),
              _buildListTile(
                icon: Icons.heart_broken_outlined,
                title: 'Eşleşmeyi Kopar',
                subtitle: 'Geliştirilecek... Kriptografik bağı sonlandırır.',
                iconColor: Colors.orange,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Eşleşme kaldırma modülü yapım aşamasında.')),
                  );
                },
              ),
              const SizedBox(height: 30),
              _buildSectionTitle('Hesap'),
              _buildListTile(
                icon: Icons.exit_to_app,
                title: 'Çıkış Yap',
                subtitle: 'Tokenları ve yerel ağ anahtarlarını siler.',
                iconColor: AppColors.error,
                onTap: _showLogoutDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = Colors.white70,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white30),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
    );
  }
}
