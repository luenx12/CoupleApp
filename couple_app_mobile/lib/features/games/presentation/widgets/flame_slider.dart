import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/games_notifier.dart';

class FlameSlider extends ConsumerStatefulWidget {
  const FlameSlider({super.key});

  @override
  ConsumerState<FlameSlider> createState() => _FlameSliderState();
}

class _FlameSliderState extends ConsumerState<FlameSlider> {
  double _value = 0.0;

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
        ],
      ),
    );
  }
}
