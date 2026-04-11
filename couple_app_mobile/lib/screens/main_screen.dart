import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/domain/auth_notifier.dart';
import '../features/chat/data/signalr_service.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/location/presentation/location_map_screen.dart';
import '../features/location/domain/location_notifier.dart';
import '../features/gallery/presentation/gallery_screen.dart';
import '../features/vibe/domain/vibe_notifier.dart';
import '../features/vibe/presentation/vibe_dashboard_screen.dart';
import '../features/games/presentation/games_screen.dart';
import 'package:lottie/lottie.dart';

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
    _VibePage(),
    _ChatPage(),
    _MapPage(),
    _GalleryPage(),
    _GamesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeTabProvider);
    final hubStatus = ref.watch(hubStatusProvider);
    final vibeState = ref.watch(vibeNotifierProvider);

    return Scaffold(
      body: Stack(
        children: [
          Container(
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
          
          // Lottie Overlay for Vibes
          if (vibeState.currentVibe != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Lottie.network(
                  'https://lottie.host/e2ccda68-da7d-47be-bba2-cc84a44d8b94/I0QjVzQdM2.json', // Sample Love Heart explosion URL
                  fit: BoxFit.cover,
                  repeat: false,
                  onLoaded: (composition) {
                    Future.delayed(composition.duration, () {
                      if (mounted) ref.read(vibeNotifierProvider.notifier).clearVibe();
                    });
                  },
                ),
              ),
            ),
        ],
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
            icon:         Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label:        'Günlük',
          ),
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
class _ChatPage extends StatelessWidget {
  const _ChatPage();
  @override
  Widget build(BuildContext context) => const ChatScreen();
}

class _MapPage extends ConsumerWidget {
  const _MapPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize location notifier (registers SignalR callbacks)
    ref.watch(locationNotifierProvider);
    return const LocationMapScreen();
  }
}

class _GalleryPage extends StatelessWidget {
  const _GalleryPage();
  @override
  Widget build(BuildContext context) => const GalleryScreen();
}

class _VibePage extends StatelessWidget {
  const _VibePage();
  @override
  Widget build(BuildContext context) => const VibeDashboardScreen();
}

class _GamesPage extends StatelessWidget {
  const _GamesPage();
  @override
  Widget build(BuildContext context) => const GamesScreen();
}

// End of Main Screen pages
