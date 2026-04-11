import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../chat/data/signalr_service.dart';

class VibeState {
  const VibeState({
    this.myWater = 0,
    this.partnerWater = 0,
    this.currentVibe,
  });

  final int myWater;
  final int partnerWater;
  final String? currentVibe; // If not null, triggers animation

  VibeState copyWith({
    int? myWater,
    int? partnerWater,
    String? currentVibe,
    bool clearVibe = false,
  }) {
    return VibeState(
      myWater: myWater ?? this.myWater,
      partnerWater: partnerWater ?? this.partnerWater,
      currentVibe: clearVibe ? null : (currentVibe ?? this.currentVibe),
    );
  }
}

final vibeNotifierProvider = StateNotifierProvider<VibeNotifier, VibeState>((ref) {
  return VibeNotifier(ref);
});

class VibeNotifier extends StateNotifier<VibeState> {
  VibeNotifier(this.ref) : super(const VibeState()) {
    _initSignalR();
  }

  final Ref ref;

  void _initSignalR() {
    final signalR = ref.read(signalRServiceProvider);
    
    signalR.onWaterSynced = (senderId, count) {
      final myPartnerId = ref.read(authNotifierProvider).partnerId;
      if (senderId == myPartnerId) {
        if (mounted) {
          state = state.copyWith(partnerWater: count);
        }
      }
    };

    signalR.onVibeReceived = (senderId, vibeType) {
      final myPartnerId = ref.read(authNotifierProvider).partnerId;
      if (senderId == myPartnerId) {
        if (mounted) {
          state = state.copyWith(currentVibe: vibeType);
        }
      }
    };
  }

  Future<void> incrementWater() async {
    final newCount = state.myWater + 1;
    state = state.copyWith(myWater: newCount);

    final partnerId = ref.read(authNotifierProvider).partnerId;
    if (partnerId != null) {
      await ref.read(signalRServiceProvider).syncWater(partnerId, newCount);
    }
  }

  Future<void> sendVibe(String vibeType) async {
    final partnerId = ref.read(authNotifierProvider).partnerId;
    if (partnerId != null) {
      await ref.read(signalRServiceProvider).sendVibe(partnerId, vibeType);
    }
  }

  void clearVibe() {
    state = state.copyWith(clearVibe: true);
  }
}
