// ═══════════════════════════════════════════════════════════════════════════════
// LocationMapScreen — Dark-theme map with partner's encrypted location
// Uses google_maps_flutter with custom heart pin
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/auth_notifier.dart';
import '../domain/location_notifier.dart';

// Dark-mode map style JSON
const _darkMapStyle = '''
[{"elementType":"geometry","stylers":[{"color":"#0d0618"}]},
{"elementType":"labels.text.fill","stylers":[{"color":"#9d7fc4"}]},
{"elementType":"labels.text.stroke","stylers":[{"color":"#1a1025"}]},
{"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#251535"}]},
{"featureType":"road","elementType":"geometry","stylers":[{"color":"#251535"}]},
{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#3d2060"}]},
{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9d7fc4"}]},
{"featureType":"water","elementType":"geometry","stylers":[{"color":"#0a0418"}]},
{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#1a0a2e"}]},
{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#251535"}]}]
''';

class LocationMapScreen extends ConsumerStatefulWidget {
  const LocationMapScreen({super.key});

  @override
  ConsumerState<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends ConsumerState<LocationMapScreen> {

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locState = ref.watch(locationNotifierProvider);
    final auth     = ref.watch(authNotifierProvider);

    // Location request approval dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (locState.status == LocationFlowStatus.waitingApproval) {
        _showApprovalDialog(context);
      } else if (locState.status == LocationFlowStatus.denied) {
        _showDeniedSnack(context, auth.partnerName ?? 'Partner');
      }
    });

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: _buildBody(locState, auth),
    );
  }

  Widget _buildBody(LocationState locState, dynamic auth) {
    switch (locState.status) {
      case LocationFlowStatus.idle:
        return _IdleView(onRequest: () {
          final partnerId = ref.read(authNotifierProvider).partnerId;
          if (partnerId != null) {
            ref.read(locationNotifierProvider.notifier).requestLocation(partnerId);
          }
        });

      case LocationFlowStatus.requesting:
        return _StatusView(
          icon: Icons.location_searching_rounded,
          label: '📍 Konum isteği gönderildi…',
          subtitle: 'Partner onaylayana kadar bekle',
          showSpinner: true,
        );

      case LocationFlowStatus.waitingApproval:
        return _StatusView(
          icon: Icons.where_to_vote_rounded,
          label: '📍 Konum isteği alındı',
          subtitle: 'Paylaşmak istiyor musun?',
          showSpinner: false,
        );

      case LocationFlowStatus.fetchingGps:
        return _StatusView(
          icon: Icons.gps_fixed_rounded,
          label: '📡 GPS konum alınıyor…',
          subtitle: 'Şifrelenip gönderiliyor',
          showSpinner: true,
        );

      case LocationFlowStatus.sharing:
        return _MapView(
          lat: locState.partnerLat!,
          lon: locState.partnerLon!,
          partnerName: auth.partnerName ?? 'Partner',
          timestamp: locState.timestamp,
          onClose: () =>
              ref.read(locationNotifierProvider.notifier).resetToIdle(),
        );

      case LocationFlowStatus.denied:
        return _StatusView(
          icon: Icons.location_off_rounded,
          label: 'Konum paylaşımı reddedildi',
          subtitle: '${auth.partnerName ?? "Partner"} konumunu paylaşmak istemedi',
          showSpinner: false,
        );

      case LocationFlowStatus.error:
        return _StatusView(
          icon: Icons.error_outline_rounded,
          label: 'Hata',
          subtitle: locState.error ?? 'Bilinmeyen hata',
          showSpinner: false,
        );
    }
  }

  void _showApprovalDialog(BuildContext ctx) {
    final notifier = ref.read(locationNotifierProvider.notifier);
    final auth     = ref.read(authNotifierProvider);

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('📍 ', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              '${auth.partnerName ?? 'Partner'} konumunu istiyor',
              style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
            ),
          ],
        ),
        content: const Text(
          'Anlık GPS konumun şifrelenip gönderilecek.\nSunucuda saklanmayacak.',
          style: TextStyle(color: AppColors.onSurfaceMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              notifier.denyRequest();
            },
            child: const Text('Reddet',
                style: TextStyle(color: AppColors.onSurfaceMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogCtx);
              notifier.approveRequest();
            },
            icon: const Icon(Icons.share_location_rounded, size: 16),
            label: const Text('Konumu Paylaş'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeniedSnack(BuildContext ctx, String partnerName) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text('$partnerName konumunu paylaşmak istemedi.'),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Idle / status views ───────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onRequest});
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF6366F1)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withAlpha(100),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.location_on_rounded,
                size: 54, color: Colors.white),
          )
          .animate()
          .scale(begin: const Offset(0.5, 0.5), duration: 500.ms, curve: Curves.elasticOut)
          .fadeIn(duration: 400.ms),

          const SizedBox(height: 28),

          const Text(
            'Konum Radar',
            style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 26,
                fontWeight: FontWeight.w800),
          ).animate().slideY(begin: 0.3, duration: 400.ms).fadeIn(),

          const SizedBox(height: 10),

          const Text(
            'Partnerinden anlık konumunu iste.\nKonum E2EE şifreli olarak gönderilir.',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ).animate().slideY(begin: 0.3, delay: 100.ms, duration: 400.ms).fadeIn(),

          const SizedBox(height: 36),

          ElevatedButton.icon(
            onPressed: onRequest,
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Neredesin? 📍'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.showSpinner,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner)
            const CircularProgressIndicator(color: AppColors.primary)
          else
            Icon(icon, size: 64, color: AppColors.primary),
          const SizedBox(height: 20),
          Text(label,
              style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(color: AppColors.onSurfaceMuted),
              textAlign: TextAlign.center),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Map view ──────────────────────────────────────────────────────────────────

class _MapView extends StatelessWidget {
  const _MapView({
    required this.lat,
    required this.lon,
    required this.partnerName,
    required this.timestamp,
    required this.onClose,
  });

  final double lat;
  final double lon;
  final String partnerName;
  final DateTime? timestamp;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final initial = CameraPosition(
      target: LatLng(lat, lon),
      zoom: 15.5,
    );

    final marker = Marker(
      markerId: const MarkerId('partner'),
      position: LatLng(lat, lon),
      infoWindow: InfoWindow(title: partnerName, snippet: '💝 Buradadır'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
    );

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: initial,
          style:                 _darkMapStyle,
          markers:               {marker},
          myLocationEnabled:     false,
          zoomControlsEnabled:   false,
          mapToolbarEnabled:     false,
          compassEnabled:        false,
        ),
        // Top card overlay
        Positioned(
          top: 16, left: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card.withAlpha(220),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(40),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('💝 $partnerName',
                          style: const TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      if (timestamp != null)
                        Text(
                          _formatTime(timestamp!),
                          style: const TextStyle(
                            color: AppColors.onSurfaceMuted,
                            fontSize: 12,
                          ),
                        ),
                      const Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 10,
                              color: AppColors.success),
                          SizedBox(width: 3),
                          Text('Konum şifreli iletildi',
                              style: TextStyle(
                                  color: AppColors.success, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.onSurfaceMuted),
                ),
              ],
            ),
          ),
        ).animate().slideY(begin: -0.5, duration: 400.ms, curve: Curves.easeOut).fadeIn(),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
