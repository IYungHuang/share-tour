import 'timeline_slot.dart';
import 'travel_material.dart';
import 'travel_philosophy.dart';

/// 時間線行程表統計彙總與視覺擊穿資料
class ItineraryStats {
  const ItineraryStats({
    required this.totalCost,
    required this.totalHype,
    required this.finalTheme,
    required this.totalStory,
    required this.canSubmit,
    required this.slotEffectiveHypes,
    required this.comboActiveSlots,
    required this.rhythmActivePairs,
    required this.fatiguePairs,
    required this.slotThemeBonuses,
    required this.hasSpotlight,
  });

  /// 總開銷
  final int totalCost;

  /// 總熱度 (含槽位倍率與連鎖加成)
  final int totalHype;

  /// 最終主題分數 (0~100 clamp)
  final int finalTheme;

  /// 總故事厚度星等
  final int totalStory;

  /// 是否填滿 4 槽位可提交審查
  final bool canSubmit;

  /// 各槽位獨立計算之有效 Hype (長度 4)
  final List<int> slotEffectiveHypes;

  /// 觸發同標籤共鳴連鎖的槽位索引集合 (如 {1, 2})
  final Set<int> comboActiveSlots;

  /// 觸發節奏互補的相鄰對索引 (如 0 表示 (0,1) 對)
  final Set<int> rhythmActivePairs;

  /// 觸發拉車疲勞的相鄰對索引 (如 2 表示 (2,3) 對)
  final Set<int> fatiguePairs;

  /// 各槽位獲得的專屬 Theme 額外加分 (如 {0: 5, 1: 5})
  final Map<int, int> slotThemeBonuses;

  /// 行程中是否含有至少 1 個絕景素材
  final bool hasSpotlight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItineraryStats &&
          runtimeType == other.runtimeType &&
          totalCost == other.totalCost &&
          totalHype == other.totalHype &&
          finalTheme == other.finalTheme &&
          totalStory == other.totalStory &&
          canSubmit == other.canSubmit &&
          hasSpotlight == other.hasSpotlight;

  @override
  int get hashCode => Object.hash(
    totalCost,
    totalHype,
    finalTheme,
    totalStory,
    canSubmit,
    hasSpotlight,
  );

  @override
  String toString() =>
      'ItineraryStats(Cost: $totalCost, Hype: $totalHype, Theme: $finalTheme, Story: $totalStory, canSubmit: $canSubmit)';
}

/// 4 槽位時間線行程表 (支援草稿狀態與即時預覽)
class TimelineItinerary {
  TimelineItinerary({List<TravelMaterial?>? slots})
    : slots = List.unmodifiable(
        slots ?? List<TravelMaterial?>.filled(4, null),
      ) {
    assert(this.slots.length == 4, '時間線槽位數量必須固定為 4');
  }

  /// 建立全空的時間線草稿
  factory TimelineItinerary.empty() => TimelineItinerary();

  /// 4 個固定時間線槽位 [晨曦(0), 午後(1), 黃昏(2), 深夜(3)]
  final List<TravelMaterial?> slots;

  /// 槽位是否全數填滿
  bool get isComplete => slots.every((s) => s != null);

  /// 是否可以提交審查 (必須恰好 4 個非空槽位)
  bool get canSubmit => isComplete;

  /// 指定槽位設定素材
  TimelineItinerary setSlot(int index, TravelMaterial? material) {
    if (index < 0 || index >= 4) {
      throw RangeError.index(index, slots, 'slotIndex');
    }
    final nextSlots = List<TravelMaterial?>.from(slots);
    nextSlots[index] = material;
    return TimelineItinerary(slots: nextSlots);
  }

  /// 移除指定槽位素材
  TimelineItinerary removeSlot(int index) => setSlot(index, null);

  /// 執行完整的數值流水線計算 (支援非完整草稿槽位之安全預覽)
  ItineraryStats calculateStats({
    required TravelPhilosophy philosophy,
    required double cameraMultiplier,
    int baseTheme = 50,
  }) {
    var totalCost = 0;
    var rawThemeDelta = 0;
    var totalStory = 0;
    var hasSpotlight = false;

    final slotEffectiveHypes = List<int>.filled(4, 0);
    final comboActiveSlots = <int>{};
    final rhythmActivePairs = <int>{};
    final fatiguePairs = <int>{};
    final slotThemeBonuses = <int, int>{};

    // 1. 各槽位獨立素材計算
    for (var i = 0; i < 4; i++) {
      final material = slots[i];
      if (material == null) continue;

      totalCost += material.cost;
      totalStory += material.storyValue;
      if (material.isSpotlight) {
        hasSpotlight = true;
      }

      // 槽位專屬 Theme 加成
      final slotType = TimelineSlotType.values[i];
      final bonus = slotType.evaluateSlotBonus(material);
      if (bonus > 0) {
        slotThemeBonuses[i] = bonus;
        rawThemeDelta += bonus;
      }

      // 旅行哲學契合度計算
      final philContribution = philosophy.evaluateMaterial(material);
      rawThemeDelta += philContribution.effectiveTheme;
      rawThemeDelta -= philContribution.flatThemePenalty;

      // 槽位 Hype 基礎倍率 (黃昏槽位 Slot 2 享有相機倍率)
      final baseHype = (i == 2)
          ? material.hypeValue * cameraMultiplier
          : material.hypeValue.toDouble();

      slotEffectiveHypes[i] = baseHype.round();
    }

    // 2. 相鄰槽位關係判定 (0,1), (1,2), (2,3)
    for (var i = 1; i < 4; i++) {
      final prev = slots[i - 1];
      final curr = slots[i];
      if (prev == null || curr == null) continue;

      final pairIndex = i - 1;

      // 2.1 同標籤共鳴 (Tag Synergy): 後者 Hype +20% (獨立取整)
      if (curr.sharesTagWith(prev)) {
        comboActiveSlots.add(i);
        final currentHype = (i == 2)
            ? curr.hypeValue * cameraMultiplier
            : curr.hypeValue.toDouble();
        slotEffectiveHypes[i] = (currentHype * 1.2).round();
      }

      // 2.2 節奏互補 (一高風險 >=3, 一低風險 <=2) -> +10 Theme
      final isPrevHigh = prev.riskLevel >= 3;
      final isCurrHigh = curr.riskLevel >= 3;
      if (isPrevHigh != isCurrHigh) {
        rhythmActivePairs.add(pairIndex);
        rawThemeDelta += 10;
      }

      // 2.3 拉車疲勞 (兩者皆為高風險 >=3) -> -10 Theme
      if (isPrevHigh && isCurrHigh) {
        fatiguePairs.add(pairIndex);
        rawThemeDelta -= 10;
      }
    }

    final totalHype = slotEffectiveHypes.fold<int>(0, (sum, h) => sum + h);
    final finalTheme = (baseTheme + rawThemeDelta).clamp(0, 100);

    return ItineraryStats(
      totalCost: totalCost,
      totalHype: totalHype,
      finalTheme: finalTheme,
      totalStory: totalStory,
      canSubmit: canSubmit,
      slotEffectiveHypes: List.unmodifiable(slotEffectiveHypes),
      comboActiveSlots: Set.unmodifiable(comboActiveSlots),
      rhythmActivePairs: Set.unmodifiable(rhythmActivePairs),
      fatiguePairs: Set.unmodifiable(fatiguePairs),
      slotThemeBonuses: Map.unmodifiable(slotThemeBonuses),
      hasSpotlight: hasSpotlight,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineItinerary &&
          runtimeType == other.runtimeType &&
          _slotsEqual(slots, other.slots);

  static bool _slotsEqual(List<TravelMaterial?> a, List<TravelMaterial?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]?.id != b[i]?.id) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(slots.map((s) => s?.id));
}
