// ═══════════════════════════════════════════════════════════════════════════════
// LocationNotifier — State machine for location sharing flow
//
// idle → requesting → (partner side: waitingApproval) → sharing → idle
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../auth/domain/auth_state.dart';
import '../../crypto/crypto_provider.dart';
import '../data/location_service.dart';
import '../../chat/data/signalr_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum LocationFlowStatus {
  idle,
  requesting,         // Sent request, waiting for partner to approve
  waitingApproval,    // We received a request, showing dialog
  fetchingGps,        // Approved, getting GPS
  sharing,            // Location sent / received → show map
  denied,             // Partner denied
  error,
}

class LocationState {
  const LocationState({
    this.status = LocationFlowStatus.idle,
    this.partnerLat,
    this.partnerLon,
    this.requesterId,
    this.error,
    this.timestamp,
  });

  final LocationFlowStatus status;
  final double? partnerLat;
  final double? partnerLon;
  final String? requesterId;
  final String? error;
  final DateTime? timestamp;

  LocationState copyWith({
    LocationFlowStatus? status,
    double? partnerLat,
    double? partnerLon,
    String? requesterId,
    String? error,
    DateTime? timestamp,
  }) =>
      LocationState(
        status:      status      ?? this.status,
        partnerLat:  partnerLat  ?? this.partnerLat,
        partnerLon:  partnerLon  ?? this.partnerLon,
        requesterId: requesterId ?? this.requesterId,
        error:       error,
        timestamp:   timestamp   ?? this.timestamp,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final locationNotifierProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final auth    = ref.watch(authNotifierProvider);
  final crypto  = ref.watch(cryptoServiceProvider);
  final signalR = ref.watch(signalRServiceProvider);

  final notifier = LocationNotifier(
    myId:               auth.userId ?? '',
    partnerId:          auth.partnerId ?? '',
    partnerPublicKey:   auth.partnerPublicKey ?? '',
    locationService:    LocationService(crypto),
    signalR:            signalR,
    auth:               auth,
  );

  // Register SignalR callbacks
  signalR.onLocationRequested = notifier._onLocationRequested;
  signalR.onLocationShared    = notifier._onLocationShared;
  signalR.onLocationDenied    = notifier._onLocationDenied;

  return notifier;
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier({
    required this.myId,
    required this.partnerId,
    required this.partnerPublicKey,
    required this.locationService,
    required this.signalR,
    required this.auth,
  }) : super(const LocationState());

  final String myId;
  final String partnerId;
  final String partnerPublicKey;
  final LocationService locationService;
  final SignalRService signalR;
  final AuthState auth;

  // ── "Neredesin?" isteği gönder ────────────────────────────────────────────

  Future<void> requestLocation(String targetPartnerId) async {
    state = state.copyWith(status: LocationFlowStatus.requesting);
    await signalR.requestLocation(targetPartnerId);
  }

  void resetToIdle() {
    state = const LocationState();
  }

  /// FCM data push üzerinden gelen konum isteğini işler.
  /// Uygulama kapalıyken gelen `location_request` bildirimi açılışta
  /// FirebaseMessagingService tarafından buraya yönlendirilir.
  void handleFcmLocationRequest(String requesterId) {
    if (!mounted) return;
    if (requesterId.isEmpty) return;
    state = state.copyWith(
      status:      LocationFlowStatus.waitingApproval,
      requesterId: requesterId,
    );
  }


  // ── Partner konum paylaşmayı onayladı ────────────────────────────────────

  Future<void> approveRequest() async {
    final requesterId = state.requesterId;
    if (requesterId == null) return;

    state = state.copyWith(status: LocationFlowStatus.fetchingGps);

    try {
      final position = await locationService.getCurrentPosition();
      final encrypted = await locationService.encryptLocation(
        lat:               position.latitude,
        lon:               position.longitude,
        partnerPublicKeyPem: partnerPublicKey,
      );

      await signalR.shareLocation(requesterId, encrypted);
      state = state.copyWith(status: LocationFlowStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: LocationFlowStatus.error,
        error:  e.toString(),
      );
    }
  }

  // ── Partner konum paylaşmayı reddetti ────────────────────────────────────

  Future<void> denyRequest() async {
    final requesterId = state.requesterId;
    if (requesterId == null) return;
    await signalR.denyLocation(requesterId);
    state = const LocationState();
  }

  // ── SignalR Event Handlers ─────────────────────────────────────────────────

  void _onLocationRequested(Map<String, dynamic> dto) {
    final requesterId = dto['requesterId']?.toString() ?? '';
    if (!mounted) return;
    state = state.copyWith(
      status:      LocationFlowStatus.waitingApproval,
      requesterId: requesterId,
    );
  }

  void _onLocationShared(Map<String, dynamic> dto) async {
    final encPayload = dto['encryptedPayload'] as String?;
    if (encPayload == null || !mounted) return;

    try {
      final loc = await locationService.decryptLocation(encPayload);
      if (mounted) {
        state = LocationState(
          status:     LocationFlowStatus.sharing,
          partnerLat: loc.lat,
          partnerLon: loc.lon,
          timestamp:  loc.timestamp,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          status: LocationFlowStatus.error,
          error:  'Konum çözümlenemedi: $e',
        );
      }
    }
  }

  void _onLocationDenied(Map<String, dynamic> dto) {
    if (!mounted) return;
    state = state.copyWith(status: LocationFlowStatus.denied);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) state = const LocationState();
    });
  }
}
