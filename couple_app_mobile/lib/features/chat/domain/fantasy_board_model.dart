// ═══════════════════════════════════════════════════════════════════════════════
// FantasyBoard — Domain models, enums, task list
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

// ── Enums ─────────────────────────────────────────────────────────────────────

enum FantasyCardCategory {
  visual,    // Görsel
  obedience, // İtaat
  confession // İtiraf
}

extension FantasyCardCategoryX on FantasyCardCategory {
  String get label => switch (this) {
    FantasyCardCategory.visual    => 'Görsel',
    FantasyCardCategory.obedience => 'İtaat',
    FantasyCardCategory.confession => 'İtiraf',
  };

  String get emoji => switch (this) {
    FantasyCardCategory.visual    => '📸',
    FantasyCardCategory.obedience => '🔗',
    FantasyCardCategory.confession => '💬',
  };

  int get index2 => switch (this) {
    FantasyCardCategory.visual    => 0,
    FantasyCardCategory.obedience => 1,
    FantasyCardCategory.confession => 2,
  };

  static FantasyCardCategory fromIndex(int i) => FantasyCardCategory.values[i];
}

/// Cinsiyet: 0=Belirtilmemiş, 1=Kadın, 2=Erkek
enum TargetGender { unspecified, female, male }

// ── FantasyCard ───────────────────────────────────────────────────────────────

class FantasyCard {
  const FantasyCard({
    required this.id,
    required this.category,
    required this.targetGender,
    required this.taskText,
  });

  final String              id;
  final FantasyCardCategory category;
  final TargetGender        targetGender;
  final String              taskText;

  Map<String, dynamic> toJson() => {
    'id':           id,
    'category':     category.index,
    'targetGender': targetGender.index,
    'taskText':     taskText,
  };

  factory FantasyCard.fromJson(Map<String, dynamic> j) => FantasyCard(
    id:           j['id'] as String,
    category:     FantasyCardCategory.values[j['category'] as int],
    targetGender: TargetGender.values[j['targetGender'] as int],
    taskText:     j['taskText'] as String,
  );
}

// ── FantasyBoardPayload ───────────────────────────────────────────────────────

class FantasyBoardPayload {
  const FantasyBoardPayload({
    required this.boardId,
    required this.cards,
  });

  final String            boardId;
  final List<FantasyCard> cards; // Her zaman 3 kart (bir per kategori)

  Map<String, dynamic> toJson() => {
    'boardId': boardId,
    'cards':   cards.map((c) => c.toJson()).toList(),
  };

  String toJsonString() => jsonEncode(toJson());

  factory FantasyBoardPayload.fromJson(Map<String, dynamic> j) =>
      FantasyBoardPayload(
        boardId: j['boardId'] as String,
        cards: (j['cards'] as List)
            .map((c) => FantasyCard.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  static FantasyBoardPayload? tryParseJson(String jsonStr) {
    try {
      return FantasyBoardPayload.fromJson(
          jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static List<FantasyCard> allTasks = [];

  static Future<void> loadTasks() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/json/fantasy_tasks.json');
      final list = jsonDecode(jsonStr) as List;
      allTasks = list.map((item) {
        final catStr = item['category'] as String;
        final genStr = item['targetGender'] as String;

        final category = switch (catStr) {
          'visual' => FantasyCardCategory.visual,
          'obedience' => FantasyCardCategory.obedience,
          'confession' => FantasyCardCategory.confession,
          _ => FantasyCardCategory.visual,
        };

        final gender = switch (genStr) {
          'female' => TargetGender.female,
          'male' => TargetGender.male,
          _ => TargetGender.unspecified,
        };

        return FantasyCard(
          id: item['id'] as String,
          category: category,
          targetGender: gender,
          taskText: item['taskText'] as String,
        );
      }).toList();
    } catch (e) {
      // JSON okuma hatası durumunda empty list
      allTasks = [];
    }
  }

  /// Belirli bir cinsiyet için her kategoriden 1 kart seçerek tahta oluşturur.
  /// [partnerGender]: 0=Belirtilmemiş (→ female default), 1=Kadın, 2=Erkek
  static FantasyBoardPayload generateForGender(String boardId, int partnerGender) {
    final gender = partnerGender == 2 ? TargetGender.male : TargetGender.female;
    final rng    = Random();

    final picked = FantasyCardCategory.values.map((cat) {
      final pool = allTasks
          .where((t) => t.category == cat && (t.targetGender == gender || t.targetGender == TargetGender.unspecified))
          .toList();
      if (pool.isEmpty) {
        return FantasyCard(id: '${cat.name}_empty', category: cat, targetGender: gender, taskText: 'Görev bulunamadı.');
      }
      return pool[rng.nextInt(pool.length)];
    }).toList();

    return FantasyBoardPayload(boardId: boardId, cards: picked);
  }
}


