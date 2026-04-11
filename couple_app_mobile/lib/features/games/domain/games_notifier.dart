import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../chat/data/signalr_service.dart';

class GamesState {
  const GamesState({
    this.partnerFlameLevel = 0.0,
    this.incomingMediaId,
    this.mediaTimeoutSeconds = 10,
    this.whoIsMoreMatches = const [], // Sadece UI için match history
  });

  final double partnerFlameLevel;
  final String? incomingMediaId;
  final int mediaTimeoutSeconds;
  final List<String> whoIsMoreMatches;

  GamesState copyWith({
    double? partnerFlameLevel,
    String? incomingMediaId,
    int? mediaTimeoutSeconds,
    List<String>? whoIsMoreMatches,
    bool clearMedia = false,
  }) {
    return GamesState(
      partnerFlameLevel: partnerFlameLevel ?? this.partnerFlameLevel,
      incomingMediaId: clearMedia ? null : (incomingMediaId ?? this.incomingMediaId),
      mediaTimeoutSeconds: mediaTimeoutSeconds ?? this.mediaTimeoutSeconds,
      whoIsMoreMatches: whoIsMoreMatches ?? this.whoIsMoreMatches,
    );
  }
}

final gamesNotifierProvider = StateNotifierProvider<GamesNotifier, GamesState>((ref) {
  return GamesNotifier(ref);
});

class GamesNotifier extends StateNotifier<GamesState> {
  GamesNotifier(this.ref) : super(const GamesState()) {
    _initSignalR();
  }

  final Ref ref;

  void _initSignalR() {
    final signalR = ref.read(signalRServiceProvider);
    
    signalR.onFlameLevelChanged = (senderId, level) {
      final myPartnerId = ref.read(authNotifierProvider).partnerId;
      if (senderId == myPartnerId && mounted) {
        state = state.copyWith(partnerFlameLevel: level);
      }
    };

    signalR.onWhoIsMoreAnswered = (senderId, questionId, answer) {
      // In a full implementation, we'd check if my answer equals partner's answer.
      // For MVP, whenever partner answers, if it's a match, we trigger confetti.
      // (Mock logic: just assume match for visual demonstration if we answered)
      if (mounted) {
        state = state.copyWith(whoIsMoreMatches: [...state.whoIsMoreMatches, questionId]);
      }
    };

    signalR.onRedRoomMediaReceived = (senderId, mediaId, timeoutSeconds) {
      final myPartnerId = ref.read(authNotifierProvider).partnerId;
      if (senderId == myPartnerId && mounted) {
        state = state.copyWith(
          incomingMediaId: mediaId,
          mediaTimeoutSeconds: timeoutSeconds,
        );
      }
    };
  }

  Future<void> sendFlameLevel(double level) async {
    final partnerId = ref.read(authNotifierProvider).partnerId;
    if (partnerId != null) {
      await ref.read(signalRServiceProvider).sendFlameLevel(partnerId, level);
    }
  }

  Future<void> sendWhoIsMoreAnswer(String questionId, String answer) async {
    final partnerId = ref.read(authNotifierProvider).partnerId;
    if (partnerId != null) {
      await ref.read(signalRServiceProvider).sendWhoIsMoreAnswer(partnerId, questionId, answer);
    }
  }
  
  Future<void> sendRedRoomMediaTask(String mediaId, int timeoutSeconds) async {
    final partnerId = ref.read(authNotifierProvider).partnerId;
    if (partnerId != null) {
      await ref.read(signalRServiceProvider).sendRedRoomMedia(partnerId, mediaId, timeoutSeconds);
    }
  }

  void clearIncomingMedia() {
    state = state.copyWith(clearMedia: true);
  }
}
