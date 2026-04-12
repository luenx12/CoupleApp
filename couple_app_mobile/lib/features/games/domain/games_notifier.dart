import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../chat/data/signalr_service.dart';

class GamesState {
  const GamesState({
    this.partnerFlameLevel = 0.0,
    this.incomingMediaId,
    this.mediaTimeoutSeconds = 10,
    this.whoIsMoreMatches = const [],
    this.wordlePartnerAttempts,
    this.wordleChallengeWord,
  });

  final double partnerFlameLevel;
  final String? incomingMediaId;
  final int mediaTimeoutSeconds;
  final List<String> whoIsMoreMatches;
  final int? wordlePartnerAttempts;
  final String? wordleChallengeWord;

  GamesState copyWith({
    double? partnerFlameLevel,
    String? incomingMediaId,
    int? mediaTimeoutSeconds,
    List<String>? whoIsMoreMatches,
    int? wordlePartnerAttempts,
    String? wordleChallengeWord,
    bool clearMedia = false,
    bool clearWordleChallenge = false,
  }) {
    return GamesState(
      partnerFlameLevel: partnerFlameLevel ?? this.partnerFlameLevel,
      incomingMediaId: clearMedia ? null : (incomingMediaId ?? this.incomingMediaId),
      mediaTimeoutSeconds: mediaTimeoutSeconds ?? this.mediaTimeoutSeconds,
      whoIsMoreMatches: whoIsMoreMatches ?? this.whoIsMoreMatches,
      wordlePartnerAttempts: wordlePartnerAttempts ?? this.wordlePartnerAttempts,
      wordleChallengeWord: clearWordleChallenge ? null : (wordleChallengeWord ?? this.wordleChallengeWord),
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
    
    signalR.onWordleChallengeReceived = (senderId, encryptedWord) {
      final myPartnerId = ref.read(authNotifierProvider).partnerId;
      if (senderId == myPartnerId && mounted) {
         // UI can show a dialog or notification: Partner sent you a challenge!
         state = state.copyWith(wordleChallengeWord: encryptedWord);
      }
    };

    signalR.onWordleResultReceived = (senderId, attempts, isDaily) {
      final myPartnerId = ref.read(authNotifierProvider).partnerId;
      if (senderId == myPartnerId && mounted) {
        state = state.copyWith(wordlePartnerAttempts: attempts);
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

  Future<void> sendWordleChallenge(String encryptedWord) async {
    final partnerId = ref.read(authNotifierProvider).partnerId;
    if (partnerId != null) {
      await ref.read(signalRServiceProvider).sendWordleChallenge(partnerId, encryptedWord);
    }
  }
  
  Future<void> sendWordleResult(int attempts, bool isDaily) async {
    final partnerId = ref.read(authNotifierProvider).partnerId;
    if (partnerId != null) {
      await ref.read(signalRServiceProvider).sendWordleResult(partnerId, attempts, isDaily);
    }
  }

  void clearIncomingMedia() {
    state = state.copyWith(clearMedia: true);
  }
  
  void clearIncomingWordleChallenge() {
    state = state.copyWith(clearWordleChallenge: true);
  }
}
