// ═══════════════════════════════════════════════════════════════════════════════
// MainScreen — Ana ekran + WhatsApp tarzı lifecycle yönetimi
//
// WhatsApp mantığı:
//  1. Eager init: ChatNotifier + LocationNotifier uygulama açılır açılmaz başlar,
//     kullanıcı tab değiştirmeden önce de mesajları + konum isteklerini dinler.
//  2. WidgetsBindingObserver: Uygulama arka plandan öne gelince syncHistory()
//     + SignalR bağlantısını yenile. Böylece arka planda kaçırılan mesajlar
//     anında gösterilir.
//  3. FCM callback'leri burada wire-up edilir: location_request diyaloğu,
//     chat sync, tab yönlendirmesi.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/firebase_messaging_service.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/domain/auth_notifier.dart';
import '../features/chat/data/signalr_service.dart';
import '../features/chat/domain/chat_notifier.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/location/presentation/location_map_screen.dart';
import '../features/location/domain/location_notifier.dart';
import '../features/gallery/presentation/gallery_screen.dart';
import '../features/vibe/domain/vibe_notifier.dart';
import '../features/vibe/presentation/vibe_dashboard_screen.dart';
import '../features/games/domain/games_notifier.dart';
import '../features/games/presentation/games_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import 'package:lottie/lottie.dart';

final activeTabProvider = StateProvider<int>((_) => 0);

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});
  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {          // ← lifecycle observer

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
      ..addObserver(this)
      ..addPostFrameCallback((_) => _initServices());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── App lifecycle ───────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  /// Uygulama arka plandan öne geldiğinde:
  /// 1. SignalR bağlantısını yenile (kopmuşsa)
  /// 2. Chat geçmişini sunucudan sync et (kaçırılan mesajlar)
  void _onAppResumed() {
    // SignalR yeniden bağlan (bağlıysa no-op)
    final token = ref.read(authNotifierProvider).accessToken;
    if (token != null) {
      ref.read(signalRServiceProvider).connect(token);
    }

    // Chat sync — WhatsApp gibi: arka planda kaçırılan mesajları çek
    ref.read(chatNotifierProvider.notifier).syncHistory();
  }

  // ── Servis başlatma ─────────────────────────────────────────────────────────

  Future<void> _initServices() async {
    // 1. SignalR bağlantısı
    final token = ref.read(authNotifierProvider).accessToken;
    if (token != null) {
      await ref.read(signalRServiceProvider).connect(token);
    }

    // 2. Eager init: ChatNotifier (SignalR callback'leri kaydeder, mesaj dinler)
    //    Chat sekmesi açılmadan önce de ReceiveMessage eventi yakalanır.
    ref.read(chatNotifierProvider);

    // 3. Eager init: LocationNotifier (SignalR + FCM konum callback'leri)
    //    Harita sekmesine gitmeden de LocationRequested eventi yakalanır.
    ref.read(locationNotifierProvider);

    // 4. GamesNotifier (RedRoom medya bildirimleri için)
    ref.read(gamesNotifierProvider);

    // 5. FCM callback'lerini wire-up et
    _wireFcmCallbacks();
  }

  void _wireFcmCallbacks() {
    final fcm = FirebaseMessagingService();

    // Chat sync callback — her FCM geldiğinde
    fcm.setMessageSyncCallback((_) {
      if (mounted) {
        ref.read(chatNotifierProvider.notifier).syncHistory();
      }
    });

    // Konum isteği callback — FCM'den location_request gelince
    fcm.setLocationRequestCallback((requesterId) {
      if (!mounted) return;
      // LocationNotifier'a bildir → waitingApproval state
      ref.read(locationNotifierProvider.notifier)
          .handleFcmLocationRequest(requesterId);
      // Harita sekmesine yönlendir (index 2)
      ref.read(activeTabProvider.notifier).state = 2;
    });

    // Bildirime tıklanınca tab yönlendirmesi
    fcm.setNotificationTapCallback((type, payload) {
      if (!mounted) return;
      switch (type) {
        case 'location_request':
          ref.read(activeTabProvider.notifier).state = 2; // Harita
          if (payload != null && payload.isNotEmpty) {
            ref.read(locationNotifierProvider.notifier)
                .handleFcmLocationRequest(payload);
          }
        case 'message':
          ref.read(activeTabProvider.notifier).state = 1; // Chat
        default:
          break;
      }
    });
  }

  // ── Sayfalar ────────────────────────────────────────────────────────────────

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
                  'https://lottie.host/e2ccda68-da7d-47be-bba2-cc84a44d8b94/I0QjVzQdM2.json',
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
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
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

// ── Sayfa widget'ları ──────────────────────────────────────────────────────

/// Chat sayfası — eager init sayesinde ChatNotifier zaten başlamış olacak.
class _ChatPage extends StatelessWidget {
  const _ChatPage();
  @override
  Widget build(BuildContext context) => const ChatScreen();
}

/// Harita sayfası — eager init sayesinde LocationNotifier zaten başlamış olacak.
/// locationNotifierProvider burada tekrar watch edilmesi redundant ama zararsız.
class _MapPage extends ConsumerWidget {
  const _MapPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
