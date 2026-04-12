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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black,
            const Color(0xFF1A0000), // Very dark red
            const Color(0xFF0D001A), // Very dark purple
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "❤️‍🔥 Kırmızı Oda",
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Sadece ikiniz için özel bir alan.",
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
            SizedBox(height: 40),
            FlameSlider(),
            SizedBox(height: 32),
            RedRoomVideoTask(),
            SizedBox(height: 24),
            SpicyTruthDareWidget(),
            SizedBox(height: 24),
            SpicyNeverEverWidget(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
