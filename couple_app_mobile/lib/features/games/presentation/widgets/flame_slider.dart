import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../domain/games_notifier.dart';

class FlameSlider extends ConsumerStatefulWidget {
  const FlameSlider({super.key});

  @override
  ConsumerState<FlameSlider> createState() => _FlameSliderState();
}

class _FlameSliderState extends ConsumerState<FlameSlider> {
  double _value = 0.0;
  List<FlSpot> _mySpots = [];
  List<FlSpot> _partnerSpots = [];
  bool _isLoadingChart = false;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoadingChart = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/MiniGames/flame-history?days=7'),
        headers: {'Authorization': 'Bearer MOCK_TOKEN'}, // Use actual token
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final myHistory = data['myHistory'] as List;
        final partnerHistory = data['partnerHistory'] as List;

        setState(() {
          _mySpots = _mapToSpots(myHistory);
          _partnerSpots = _mapToSpots(partnerHistory);
        });
      }
    } catch (e) {
      debugPrint("Error fetching flame history: $e");
    } finally {
      if (mounted) setState(() => _isLoadingChart = false);
    }
  }

  List<FlSpot> _mapToSpots(List history) {
    if (history.isEmpty) return const [];
    // Just mapping index to X for MVP visualization. In real scenarios, use time.
    List<FlSpot> spots = [];
    for (int i = 0; i < history.length; i++) {
        spots.add(FlSpot(i.toDouble(), (history[i]['level'] as num).toDouble()));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gamesNotifierProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.redAccent.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withAlpha(20).withOpacity(_value / 100 * 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Ateş Ölçer",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                "🔥 ${_value.toInt()}%",
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.redAccent,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              overlayColor: Colors.redAccent.withAlpha(50),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: _value,
              min: 0,
              max: 100,
              onChanged: (val) {
                setState(() => _value = val);
              },
              onChangeEnd: (val) {
                ref.read(gamesNotifierProvider.notifier).sendFlameLevel(val);
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Partnerin Seviyesi: 🔥 ${state.partnerFlameLevel.toInt()}%",
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 24),
          if (_isLoadingChart)
             const CircularProgressIndicator(color: Colors.redAccent)
          else if (_mySpots.isNotEmpty || _partnerSpots.isNotEmpty)
             SizedBox(
               height: 150,
               child: LineChart(
                 LineChartData(
                   gridData: const FlGridData(show: false),
                   titlesData: const FlTitlesData(show: false),
                   borderData: FlBorderData(show: false),
                   minY: 0,
                   maxY: 100,
                   lineBarsData: [
                     LineChartBarData(
                       spots: _mySpots.isEmpty ? const [FlSpot(0,0)] : _mySpots,
                       isCurved: true,
                       color: Colors.redAccent,
                       barWidth: 2,
                       isStrokeCapRound: true,
                       dotData: const FlDotData(show: false),
                       belowBarData: BarAreaData(show: true, color: Colors.redAccent.withAlpha(50)),
                     ),
                     LineChartBarData(
                       spots: _partnerSpots.isEmpty ? const [FlSpot(0,0)] : _partnerSpots,
                       isCurved: true,
                       color: Colors.orangeAccent,
                       barWidth: 2,
                       isStrokeCapRound: true,
                       dotData: const FlDotData(show: false),
                     ),
                   ],
                 ),
               ),
             ),
        ],
      ),
    );
  }
}
