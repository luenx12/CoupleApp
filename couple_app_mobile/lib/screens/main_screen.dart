import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/domain/auth_notifier.dart';
import '../features/chat/data/signalr_service.dart';

final activeTabProvider = StateProvider<int>((_) => 0);

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});
  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectSignalR());
  }

  Future<void> _connectSignalR() async {
    final token = ref.read(authNotifierProvider).accessToken;
    if (token != null) {
      await ref.read(signalRServiceProvider).connect(token);
    }
  }

  static const _pages = [
    _ChatPage(),
    _MapPage(),
    _GalleryPage(),
    _GamesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeTabProvider);
    final hubStatus = ref.watch(hubStatusProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(hubStatus: hubStatus),
              Expanded(child: _pages[activeTab]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(activeTab: activeTab),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.hubStatus});
  final HubConnectionStatus hubStatus;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (hubStatus) {
      HubConnectionStatus.connected    => ('● Bağlandı',    AppColors.success),
      HubConnectionStatus.connecting   => ('◌ Bağlanıyor…', Colors.amber),
      HubConnectionStatus.reconnecting => ('◌ Yeniden…',   Colors.orange),
      HubConnectionStatus.disconnected => ('○ Bağlı Değil', AppColors.error),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (r) =>
                AppTheme.primaryGradient.createShader(r),
            child: const Text(
              '💝 CoupleApp',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(100)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ).animate(key: ValueKey(hubStatus)).fadeIn(duration: 300.ms),
        ],
      ),
    );
  }
}

// ── Bottom Nav ─────────────────────────────────────────────────────────────
class _BottomNav extends ConsumerWidget {
  const _BottomNav({required this.activeTab});
  final int activeTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: const Border(
            top: BorderSide(color: AppColors.cardBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(40),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: activeTab,
        onDestinationSelected: (i) =>
            ref.read(activeTabProvider.notifier).state = i,
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 68,
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label:        'Sohbet',
          ),
          NavigationDestination(
            icon:         Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label:        'Harita',
          ),
          NavigationDestination(
            icon:         Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library_rounded),
            label:        'Galeri',
          ),
          NavigationDestination(
            icon:         Icon(Icons.videogame_asset_outlined),
            selectedIcon: Icon(Icons.videogame_asset_rounded),
            label:        'Oyunlar',
          ),
        ],
      ),
    );
  }
}

// ── Placeholder Pages ──────────────────────────────────────────────────────
class _ChatPage    extends StatelessWidget { const _ChatPage();    @override Widget build(BuildContext ctx) => _PlaceholderPage(icon: Icons.chat_bubble_rounded,    title: 'Sohbet',  subtitle: 'Uçtan uca şifrelenmiş mesajlar', gradient: const [Color(0xFFE91E8C), Color(0xFF7C3AED)]); }
class _MapPage     extends StatelessWidget { const _MapPage();     @override Widget build(BuildContext ctx) => _PlaceholderPage(icon: Icons.location_on_rounded,     title: 'Harita',  subtitle: 'Partnerinizin anlık konumu',     gradient: const [Color(0xFF06B6D4), Color(0xFF6366F1)]); }
class _GalleryPage extends StatelessWidget { const _GalleryPage(); @override Widget build(BuildContext ctx) => _PlaceholderPage(icon: Icons.photo_album_rounded,     title: 'Galeri',  subtitle: 'Gizli anılarınız',               gradient: const [Color(0xFFF59E0B), Color(0xFFEC4899)]); }
class _GamesPage   extends StatelessWidget { const _GamesPage();   @override Widget build(BuildContext ctx) => _PlaceholderPage(icon: Icons.extension_rounded,       title: 'Oyunlar', subtitle: 'Görevler ve mini oyunlar',        gradient: const [Color(0xFF10B981), Color(0xFF3B82F6)]); }

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
  final IconData icon;
  final String title, subtitle;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: gradient.first.withAlpha(100), blurRadius: 30, spreadRadius: 5)],
            ),
            child: Icon(icon, size: 48, color: Colors.white),
          ).animate()
           .scale(begin: const Offset(0.5, 0.5), duration: 500.ms, curve: Curves.elasticOut)
           .fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          Text(title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800, color: AppColors.onSurface),
          ).animate().slideY(begin: 0.3, duration: 400.ms, delay: 100.ms).fadeIn(),

          const SizedBox(height: 8),

          Text(subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
          ).animate().slideY(begin: 0.3, duration: 400.ms, delay: 200.ms).fadeIn(),

          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Yakında…',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }
}
