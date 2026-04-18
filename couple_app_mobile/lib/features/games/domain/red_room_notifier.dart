// ═══════════════════════════════════════════════════════════════════════════════
// Red Room Notifier — Riverpod State Management
// Tüm Red Room modüllerinin (Dice, Match, Roleplay, BodyMap, Roulette, DarkRoom)
// gerçek zamanlı durumunu yönetir.
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../chat/data/signalr_service.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class DiceResult {
  final String location;
  final String position;
  final String imageKey;
  final String duration;
  final int seed;

  const DiceResult({
    required this.location,
    required this.position,
    required this.imageKey,
    required this.duration,
    required this.seed,
  });

  factory DiceResult.fromMap(Map<String, dynamic> m) => DiceResult(
        location: m['location']?.toString() ?? '',
        position: m['position']?.toString() ?? '',
        imageKey: m['imageKey']?.toString() ?? '',
        duration: m['duration']?.toString() ?? '',
        seed: m['seed'] as int? ?? 0,
      );
}

class FantasyItem {
  final String id;
  final String label;
  final String imageKey;
  final String category; // 'position' | 'fantasy' | 'bdsm'

  const FantasyItem({
    required this.id,
    required this.label,
    required this.imageKey,
    required this.category,
  });
}

class RoleplayResult {
  final String myRole;
  final String partnerRole;
  final String atmosphere;
  final String instructions;

  const RoleplayResult({
    required this.myRole,
    required this.partnerRole,
    required this.atmosphere,
    required this.instructions,
  });

  factory RoleplayResult.fromMap(Map<String, dynamic> m) => RoleplayResult(
        myRole: m['myRole']?.toString() ?? '',
        partnerRole: m['partnerRole']?.toString() ?? '',
        atmosphere: m['atmosphere']?.toString() ?? '',
        instructions: m['instructions']?.toString() ?? '',
      );
}

class RouletteResult {
  final String zone;
  final String imageKey;
  final DateTime spunAt;

  const RouletteResult({required this.zone, required this.imageKey, required this.spunAt});

  factory RouletteResult.fromMap(Map<String, dynamic> m) => RouletteResult(
        zone: m['zone']?.toString() ?? '',
        imageKey: m['imageKey']?.toString() ?? '',
        spunAt: DateTime.tryParse(m['spunAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

// ── State ─────────────────────────────────────────────────────────────────────

class RedRoomState {
  const RedRoomState({
    // Dice
    this.diceResult,
    this.isDiceRolling = false,
    // Match
    this.matchedItemId,
    this.partnerSwipedItemId,
    this.partnerSwipeDirection,
    this.swipedItems = const {},
    // Roleplay
    this.roleplay,
    this.isGeneratingRoleplay = false,
    // BodyMap
    this.bodyMapPoints = const [],
    this.partnerBodyMapPoints = const [],
    // Roulette
    this.rouletteResult,
    this.isSpinning = false,
    // DarkRoom
    this.isDarkRoomActive = false,
    this.spotlightX,
    this.spotlightY,
    // SafeWord
    this.safeWordTriggered = false,
    this.safeWordSenderId,
  });

  // Dice
  final DiceResult? diceResult;
  final bool isDiceRolling;

  // Red Match
  final String? matchedItemId;
  final String? partnerSwipedItemId;
  final String? partnerSwipeDirection;
  final Map<String, String> swipedItems; // itemId → 'right'|'left'

  // Roleplay
  final RoleplayResult? roleplay;
  final bool isGeneratingRoleplay;

  // BodyMap — [{x, y, label}]
  final List<Map<String, dynamic>> bodyMapPoints;
  final List<Map<String, dynamic>> partnerBodyMapPoints;

  // Roulette
  final RouletteResult? rouletteResult;
  final bool isSpinning;

  // DarkRoom
  final bool isDarkRoomActive;
  final double? spotlightX;
  final double? spotlightY;

  // SafeWord
  final bool safeWordTriggered;
  final String? safeWordSenderId;

  RedRoomState copyWith({
    DiceResult? diceResult,
    bool? isDiceRolling,
    String? matchedItemId,
    String? partnerSwipedItemId,
    String? partnerSwipeDirection,
    Map<String, String>? swipedItems,
    RoleplayResult? roleplay,
    bool? isGeneratingRoleplay,
    List<Map<String, dynamic>>? bodyMapPoints,
    List<Map<String, dynamic>>? partnerBodyMapPoints,
    RouletteResult? rouletteResult,
    bool? isSpinning,
    bool? isDarkRoomActive,
    double? spotlightX,
    double? spotlightY,
    bool? safeWordTriggered,
    String? safeWordSenderId,
    bool clearDice          = false,
    bool clearMatch         = false,
    bool clearPartnerSwipe  = false,
    bool clearRoleplay      = false,
    bool clearRoulette      = false,
    bool clearSafeWord      = false,
  }) {
    return RedRoomState(
      diceResult:             clearDice      ? null : (diceResult ?? this.diceResult),
      isDiceRolling:          isDiceRolling  ?? this.isDiceRolling,
      matchedItemId:          clearMatch     ? null : (matchedItemId ?? this.matchedItemId),
      partnerSwipedItemId:    clearPartnerSwipe ? null : (partnerSwipedItemId ?? this.partnerSwipedItemId),
      partnerSwipeDirection:  clearPartnerSwipe ? null : (partnerSwipeDirection ?? this.partnerSwipeDirection),
      swipedItems:            swipedItems    ?? this.swipedItems,
      roleplay:               clearRoleplay  ? null : (roleplay ?? this.roleplay),
      isGeneratingRoleplay:   isGeneratingRoleplay ?? this.isGeneratingRoleplay,
      bodyMapPoints:          bodyMapPoints  ?? this.bodyMapPoints,
      partnerBodyMapPoints:   partnerBodyMapPoints ?? this.partnerBodyMapPoints,
      rouletteResult:         clearRoulette  ? null : (rouletteResult ?? this.rouletteResult),
      isSpinning:             isSpinning     ?? this.isSpinning,
      isDarkRoomActive:       isDarkRoomActive ?? this.isDarkRoomActive,
      spotlightX:             spotlightX     ?? this.spotlightX,
      spotlightY:             spotlightY     ?? this.spotlightY,
      safeWordTriggered:      clearSafeWord  ? false : (safeWordTriggered ?? this.safeWordTriggered),
      safeWordSenderId:       clearSafeWord  ? null  : (safeWordSenderId ?? this.safeWordSenderId),
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final redRoomNotifierProvider =
    StateNotifierProvider<RedRoomNotifier, RedRoomState>(
  (ref) => RedRoomNotifier(ref),
);

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Kapsamlı Red Room fantezi modüllerinin tüm state'ini ve SignalR olaylarını
/// yöneten Riverpod StateNotifier.
class RedRoomNotifier extends StateNotifier<RedRoomState> {
  RedRoomNotifier(this._ref) : super(const RedRoomState()) {
    _initSignalR();
  }

  final Ref _ref;

  String? get _partnerId => _ref.read(authNotifierProvider).partnerId;

  void _initSignalR() {
    final s = _ref.read(signalRServiceProvider);

    // 🎲 Dice
    s.onDiceResult = (dto) {
      if (!mounted) return;
      state = state.copyWith(
        isDiceRolling: false,
        diceResult: DiceResult.fromMap(dto),
      );
    };

    // 🔥 Red Match
    s.onPartnerSwiped = (senderId, itemId, direction) {
      final myPartnerId = _partnerId;
      if (senderId != myPartnerId || !mounted) return;
      state = state.copyWith(
        partnerSwipedItemId: itemId,
        partnerSwipeDirection: direction,
      );
    };

    s.onRedMatch = (itemId, matchedAt) {
      if (!mounted) return;
      state = state.copyWith(matchedItemId: itemId);
    };

    // 🎭 Roleplay
    s.onRoleplayGenerated = (dto) {
      if (!mounted) return;
      state = state.copyWith(
        isGeneratingRoleplay: false,
        roleplay: RoleplayResult.fromMap(dto),
      );
    };

    // 🧭 Body Map
    s.onBodyMapUpdated = (senderId, pointsJson) {
      final myPartnerId = _partnerId;
      if (senderId != myPartnerId || !mounted) return;
      try {
        final points = (jsonDecode(pointsJson) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        state = state.copyWith(partnerBodyMapPoints: points);
      } catch (_) {}
    };

    // 📸 Roulette
    s.onRouletteResult = (dto) {
      if (!mounted) return;
      state = state.copyWith(
        isSpinning: false,
        rouletteResult: RouletteResult.fromMap(dto),
      );
    };

    // 🔦 DarkRoom — Spotlight
    s.onSpotlightMoved = (x, y, ts) {
      if (!mounted) return;
      state = state.copyWith(spotlightX: x, spotlightY: y);
    };

    s.onDarkRoomStarted = (payload) {
      if (!mounted) return;
      state = state.copyWith(isDarkRoomActive: true);
    };

    // 🛑 SafeWord
    s.onSafeWordTriggered = (senderId) {
      if (!mounted) return;
      state = state.copyWith(
        safeWordTriggered: true,
        safeWordSenderId: senderId,
        isDarkRoomActive: false,
        isDiceRolling: false,
        isSpinning: false,
        isGeneratingRoleplay: false,
      );
    };
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// 🎲 Zar at — Mekan + Pozisyon
  Future<void> rollDice() async {
    if (_partnerId == null) return;
    state = state.copyWith(isDiceRolling: true, clearDice: true);
    await _ref.read(signalRServiceProvider).rollDice(_partnerId!);
  }

  /// 🔥 Swipe (sağ/sol) — Red Match
  Future<void> swipeFantasy(String itemId, String direction) async {
    if (_partnerId == null) return;
    final updated = Map<String, String>.from(state.swipedItems);
    updated[itemId] = direction;
    state = state.copyWith(swipedItems: updated);
    await _ref.read(signalRServiceProvider).swipeFantasy(_partnerId!, itemId, direction);
  }

  void clearMatch() => state = state.copyWith(clearMatch: true);

  /// 🎭 Roleplay senaryosu üret
  Future<void> generateRoleplay() async {
    if (_partnerId == null) return;
    state = state.copyWith(isGeneratingRoleplay: true, clearRoleplay: true);
    await _ref.read(signalRServiceProvider).generateRoleplay(_partnerId!);
  }

  /// 🧭 Vücut haritası noktalarını gönder
  Future<void> sendBodyMap(List<Map<String, dynamic>> points) async {
    if (_partnerId == null) return;
    state = state.copyWith(bodyMapPoints: points);
    final json = jsonEncode(points);
    await _ref.read(signalRServiceProvider).sendBodyMap(_partnerId!, json);
  }

  void addBodyMapPoint(Map<String, dynamic> point) {
    state = state.copyWith(bodyMapPoints: [...state.bodyMapPoints, point]);
  }

  void clearBodyMap() => state = state.copyWith(bodyMapPoints: []);

  /// 📸 Roulette çevir
  Future<void> spinRoulette() async {
    if (_partnerId == null) return;
    state = state.copyWith(isSpinning: true, clearRoulette: true);
    await _ref.read(signalRServiceProvider).spinRoulette(_partnerId!);
  }

  /// 🔦 Karanlık Oda — spotlight koordinatı gönder
  Future<void> sendSpotlightMove(double x, double y) async {
    if (_partnerId == null) return;
    await _ref.read(signalRServiceProvider).sendSpotlightMove(_partnerId!, x, y);
  }

  void closeDarkRoom() => state = state.copyWith(isDarkRoomActive: false);

  /// 🔦 Karanlık Oda — Başlat
  Future<void> startDarkRoom() async {
    state = state.copyWith(isDarkRoomActive: true);
    if (_partnerId == null) return;
    await _ref.read(signalRServiceProvider).startDarkRoom(_partnerId!, "");
  }

  /// 🛑 Güvenli kelime tetikle — tüm oturumları durdur
  Future<void> triggerSafeWord() async {
    if (_partnerId == null) return;
    await _ref.read(signalRServiceProvider).triggerSafeWord(_partnerId!);
    // Yerel state de hemen durdurulsun
    state = state.copyWith(
      safeWordTriggered: true,
      safeWordSenderId: _ref.read(authNotifierProvider).userId,
      isDarkRoomActive: false,
      isDiceRolling: false,
      isSpinning: false,
      isGeneratingRoleplay: false,
    );
  }

  void dismissSafeWord() => state = state.copyWith(clearSafeWord: true);
}

// ── Fantasy Card Catalog ──────────────────────────────────────────────────────
// Red Match'te kullanılacak kart listesi (sunucusuz — client-side)
// imageKey → assets/red_room/positions/<imageKey>.png

const List<FantasyItem> kFantasyItems = [
  FantasyItem(id: 'pos_missionary',   label: 'Misyoner',           imageKey: 'pos_missionary',   category: 'position'),
  FantasyItem(id: 'pos_doggy',        label: 'Doggy Style',        imageKey: 'pos_doggy',        category: 'position'),
  FantasyItem(id: 'pos_cowgirl',      label: 'Cowgirl',            imageKey: 'pos_cowgirl',      category: 'position'),
  FantasyItem(id: 'pos_rev_cowgirl',  label: 'Reverse Cowgirl',    imageKey: 'pos_rev_cowgirl',  category: 'position'),
  FantasyItem(id: 'pos_standing',     label: 'Ayakta',             imageKey: 'pos_standing',     category: 'position'),
  FantasyItem(id: 'pos_spooning',     label: 'Kaşık',              imageKey: 'pos_spooning',     category: 'position'),
  FantasyItem(id: 'pos_lotus',        label: 'Lotus',              imageKey: 'pos_lotus',        category: 'position'),
  FantasyItem(id: 'pos_69',           label: '69 Pozisyon',        imageKey: 'pos_69',           category: 'position'),
  FantasyItem(id: 'pos_amazon',       label: 'Amazon',             imageKey: 'pos_amazon',       category: 'position'),
  FantasyItem(id: 'fantasy_roleplay', label: 'Roleplay',           imageKey: 'fantasy_roleplay', category: 'fantasy'),
  FantasyItem(id: 'fantasy_bdsm',     label: 'BDSM / Bağlama',    imageKey: 'fantasy_bdsm',     category: 'bdsm'),
  FantasyItem(id: 'fantasy_outdoor',  label: 'Dışarıda',          imageKey: 'fantasy_outdoor',  category: 'fantasy'),
  FantasyItem(id: 'fantasy_mirror',   label: 'Ayna Karşısı',      imageKey: 'fantasy_mirror',   category: 'fantasy'),
  FantasyItem(id: 'fantasy_shower',   label: 'Duşta',             imageKey: 'fantasy_shower',   category: 'fantasy'),
  FantasyItem(id: 'fantasy_kitchen',  label: 'Mutfakta',          imageKey: 'fantasy_kitchen',  category: 'fantasy'),
];
