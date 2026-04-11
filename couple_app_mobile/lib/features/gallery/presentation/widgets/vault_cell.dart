import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/gallery_item_model.dart';

class VaultCell extends StatefulWidget {
  const VaultCell({super.key, required this.item});
  final GalleryItemModel item;

  @override
  State<VaultCell> createState() => _VaultCellState();
}

class _VaultCellState extends State<VaultCell> {
  Timer? _timer;
  late Duration _timeLeft;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateTimeLeft();
        });
      }
    });
  }

  void _calculateTimeLeft() {
    if (widget.item.lockedUntil == null) {
      _timeLeft = Duration.zero;
      return;
    }
    final now = DateTime.now();
    _timeLeft = widget.item.lockedUntil!.difference(now);
    if (_timeLeft.isNegative) {
      _timeLeft = Duration.zero;
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    if (_timeLeft.inDays > 0) {
      return '${_timeLeft.inDays} g ${_timeLeft.inHours.remainder(24)} s';
    }
    if (_timeLeft.inHours > 0) {
      return '${_timeLeft.inHours} s ${_timeLeft.inMinutes.remainder(60)} d';
    }
    return '${_timeLeft.inMinutes} d ${_timeLeft.inSeconds.remainder(60)} sn';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_clock_rounded,
            color: AppColors.primary,
            size: 36,
          ),
          const SizedBox(height: 8),
          const Text(
            'Zaman Kapsülü',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _timeLeft.inSeconds > 0 ? _formattedTime : 'Açılıyor...',
            style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
