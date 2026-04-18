import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/kazikazan_widget.dart';
import 'widgets/who_is_more_widget.dart';
import 'widgets/flame_slider.dart';
import 'widgets/red_room_video_task.dart';
import 'widgets/spicy_truth_dare_widget.dart';
import 'widgets/spicy_never_ever_widget.dart';
import 'widgets/draw_game_widget.dart';
import 'widgets/wordle/wordle_widget.dart';
// Red Room Premium Modüller
import 'widgets/spicy_dice_widget.dart';
import 'widgets/red_match_widget.dart';
import 'widgets/roleplay_generator_widget.dart';
import 'widgets/body_map_widget.dart';
import 'widgets/snapshot_roulette_widget.dart';
import 'widgets/dark_room_widget.dart';
import 'widgets/safe_word_button.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          dividerColor: Colors.transparent,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceMuted,
          tabs: const [
            Tab(text: "Eğlence", icon: Icon(Icons.videogame_asset_outlined)),
            Tab(text: "Kırmızı Oda", icon: Icon(Icons.favorite_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSfwGames(),
          _buildRedRoom(),
        ],
      ),
    );
  }

  Widget _buildSfwGames() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildDrawGameCard(),
          const SizedBox(height: 20),
          const WordleWidget(),
          const SizedBox(height: 20),
          const WhoIsMoreWidget(),
          const SizedBox(height: 20),
          const KazikazanWidget(),
        ],
      ),
    );
  }

  Widget _buildDrawGameCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
           MaterialPageRoute(builder: (_) => const DrawGameWidget()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3F51B5), Color(0xFF2196F3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
             BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ]
        ),
        child: const Column(
          children: [
            Icon(Icons.brush, size: 48, color: Colors.white),
            SizedBox(height: 12),
            Text(
              "Çizim & Tahmin",
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              "Duygularını ciz, partnerin tahmin etsin!",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedRoom() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0A0000),
            Color(0xFF1A0008),
            Color(0xFF0D001A),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Banner ────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  const Text('❤️‍🔥', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 6),
                  const Text(
                    'KIRMIZI ODA',
                    style: TextStyle(
                      color: Color(0xFFFF0055),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sadece ikinize özel — sıfır sızıntı, sonsuz tutku.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── 🛑 Safe Word — Her zaman üstte ─────────────────────────
            const SafeWordButton(),

            const SizedBox(height: 28),

            // ── 🔥 Ateş Seviyesi ────────────────────────────────────────
            _sectionHeader('🔥', 'Ateş Seviyesi'),
            const SizedBox(height: 12),
            const FlameSlider(),

            const SizedBox(height: 28),

            // ── 🎲 İkimizin Zarları ──────────────────────────────────────
            _sectionHeader('🎲', 'İkimizin Zarları'),
            const SizedBox(height: 12),
            const SpicyDiceWidget(),

            const SizedBox(height: 28),

            // ── 🔥 Red Match ─────────────────────────────────────────────
            _sectionHeader('🔥', 'Red Match — Swipe to Passion'),
            const SizedBox(height: 12),
            const RedMatchWidget(),

            const SizedBox(height: 28),

            // ── 🎭 Roleplay Jeneratör ────────────────────────────────────
            _sectionHeader('🎭', 'Roleplay Jeneratör'),
            const SizedBox(height: 12),
            const RoleplayGeneratorWidget(),

            const SizedBox(height: 28),

            // ── 🧭 Vücut Haritası ───────────────────────────────────────
            _sectionHeader('🧭', 'Vücut Haritası'),
            const SizedBox(height: 12),
            const BodyMapWidget(),

            const SizedBox(height: 28),

            // ── 📸 Snapshot Roulette ─────────────────────────────────────
            _sectionHeader('📸', 'Snapshot Roulette'),
            const SizedBox(height: 12),
            const SnapshotRouletteWidget(),

            const SizedBox(height: 28),

            // ── 🔦 Karanlık Oda ──────────────────────────────────────────
            _sectionHeader('🔦', 'Karanlık Oda'),
            const SizedBox(height: 12),
            const DarkRoomWidget(),

            const SizedBox(height: 28),

            // ── 🎬 Süreli Medya Görevi ───────────────────────────────────
            _sectionHeader('🎬', 'Süreli Medya Görevi'),
            const SizedBox(height: 12),
            const RedRoomVideoTask(),

            const SizedBox(height: 28),

            // ── 🃏 Spicy Truth or Dare ────────────────────────────────────
            _sectionHeader('🃏', 'Doğru mu Yanlış mı?'),
            const SizedBox(height: 12),
            const SpicyTruthDareWidget(),

            const SizedBox(height: 28),

            // ── 🙅 Never Have I Ever ──────────────────────────────────────
            _sectionHeader('🙅', 'Ben Hiç...'),
            const SizedBox(height: 12),
            const SpicyNeverEverWidget(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF0055).withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
