import 'shot_tier.dart';
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
    required this.spotlightCount,
    required this.themeBaseline,
    required this.themeBeforeFatigue,
    required this.purityActive,
    this.failedSpotlightHype = 0,
    this.failedNonSpotlightHype = 0,
    this.normalSpotlightHype = 0,
    this.normalNonSpotlightHype = 0,
    this.perfectSpotlightHype = 0,
    this.perfectNonSpotlightHype = 0,
    bool? hasSpotlight,
  }) : hasSpotlight = hasSpotlight ?? (spotlightCount > 0);

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

  /// 行程中焦點絕景素材數量
  final int spotlightCount;

  /// 主題契合度基準分 (50 + 已填槽位契合貢獻平均)
  final int themeBaseline;

  /// 扣除拉車疲勞前之主題分數 (含時段、節奏與純度)
  final int themeBeforeFatigue;

  /// 是否達成純度加成 (全部已填槽位皆為契合素材)
  final bool purityActive;

  /// 行程中是否含有至少 1 個絕景素材 (衍生自 spotlightCount > 0)
  final bool hasSpotlight;

  /// 第二層資料流（REQ-M5-02.5）：依 (shotTier, isSpotlight) 分組的
  /// `material.hypeValue` 原始值總和——**不是** [slotEffectiveHypes]
  /// （那是排列相依量，含槽位倍率與連鎖加成）。難度無關，只看素材本身
  /// 的三態與是否絕景；`tierFactor` 的套用留給 `ClientReviewEngine`
  /// （它才知道難度）。
  final int failedSpotlightHype;
  final int failedNonSpotlightHype;
  final int normalSpotlightHype;
  final int normalNonSpotlightHype;
  final int perfectSpotlightHype;
  final int perfectNonSpotlightHype;

  /// 純度加成分數 (達成時為 1，失效為 0)
  int get purityBonus => purityActive ? TimelineItinerary.defaultPurityBonus : 0;

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
          spotlightCount == other.spotlightCount &&
          themeBaseline == other.themeBaseline &&
          themeBeforeFatigue == other.themeBeforeFatigue &&
          purityActive == other.purityActive &&
          hasSpotlight == other.hasSpotlight &&
          failedSpotlightHype == other.failedSpotlightHype &&
          failedNonSpotlightHype == other.failedNonSpotlightHype &&
          normalSpotlightHype == other.normalSpotlightHype &&
          normalNonSpotlightHype == other.normalNonSpotlightHype &&
          perfectSpotlightHype == other.perfectSpotlightHype &&
          perfectNonSpotlightHype == other.perfectNonSpotlightHype &&
          _listEquals(slotEffectiveHypes, other.slotEffectiveHypes) &&
          _setEquals(comboActiveSlots, other.comboActiveSlots) &&
          _setEquals(rhythmActivePairs, other.rhythmActivePairs) &&
          _setEquals(fatiguePairs, other.fatiguePairs) &&
          _mapEquals(slotThemeBonuses, other.slotThemeBonuses);

  @override
  int get hashCode => Object.hashAll([
        totalCost,
        totalHype,
        finalTheme,
        totalStory,
        canSubmit,
        spotlightCount,
        themeBaseline,
        themeBeforeFatigue,
        purityActive,
        hasSpotlight,
        failedSpotlightHype,
        failedNonSpotlightHype,
        normalSpotlightHype,
        normalNonSpotlightHype,
        perfectSpotlightHype,
        perfectNonSpotlightHype,
        Object.hashAll(slotEffectiveHypes),
        Object.hashAll(comboActiveSlots),
        Object.hashAll(rhythmActivePairs),
        Object.hashAll(fatiguePairs),
        Object.hashAll(
          (slotThemeBonuses.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
              .map((e) => Object.hash(e.key, e.value)),
        ),
      ]);

  @override
  String toString() =>
      'ItineraryStats(Cost: $totalCost, Hype: $totalHype, Theme: $finalTheme, Baseline: $themeBaseline, BeforeFatigue: $themeBeforeFatigue, Story: $totalStory, Spotlights: $spotlightCount, Purity: $purityActive, canSubmit: $canSubmit)';
}

/// 時間線行程表提交檢查異常原因
enum ItinerarySubmissionIssue {
  /// 槽位數量不足 3 個
  tooFewSlots,

  /// 槽位未連續排列 (存在中間缺口)
  nonContiguous,
}

/// 4 槽位時間線行程表 (支援草稿狀態與即時預覽)
class TimelineItinerary {
  /// 純度成立時的主題加分 (D6 勝者為 1)
  static const int defaultPurityBonus = 1;

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

  /// 行程表提交合法性檢查 (REQ-A1-05)
  ///
  /// 規則：
  /// - < 3 槽: tooFewSlots
  /// - 恰 3 槽: 必須連續 ([0, 1, 2] 或 [1, 2, 3])，否則 nonContiguous
  /// - 4 槽: 合法 (null)
  ItinerarySubmissionIssue? get submissionIssue {
    final filledIndices = <int>[];
    for (var i = 0; i < slots.length; i++) {
      if (slots[i] != null) {
        filledIndices.add(i);
      }
    }
    if (filledIndices.length < 3) {
      return ItinerarySubmissionIssue.tooFewSlots;
    }
    if (filledIndices.length == 3) {
      final isContiguous = (filledIndices[0] == 0 &&
              filledIndices[1] == 1 &&
              filledIndices[2] == 2) ||
          (filledIndices[0] == 1 &&
              filledIndices[1] == 2 &&
              filledIndices[2] == 3);
      if (!isContiguous) {
        return ItinerarySubmissionIssue.nonContiguous;
      }
      return null;
    }
    return null;
  }

  /// 是否可以提交審查 (連續 3 槽或填滿 4 槽)
  bool get canSubmit => submissionIssue == null;

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
    var totalStory = 0;
    var spotlightCount = 0;
    var filledCount = 0;
    var sumCardContribution = 0;
    var slotBonusSum = 0;
    var allFilledAligned = true;

    final slotEffectiveHypes = List<int>.filled(4, 0);
    final comboActiveSlots = <int>{};
    final rhythmActivePairs = <int>{};
    final fatiguePairs = <int>{};
    final slotThemeBonuses = <int, int>{};

    var failedSpotlightHype = 0;
    var failedNonSpotlightHype = 0;
    var normalSpotlightHype = 0;
    var normalNonSpotlightHype = 0;
    var perfectSpotlightHype = 0;
    var perfectNonSpotlightHype = 0;

    // 1. 各槽位獨立素材計算
    for (var i = 0; i < 4; i++) {
      final material = slots[i];
      if (material == null) continue;

      filledCount++;
      totalCost += material.cost;
      totalStory += material.storyValue;
      if (material.isSpotlight) {
        spotlightCount++;
      }

      // 第二層資料流：用 material.hypeValue 原始值，不是下面算的
      // slotEffectiveHypes（排列相依，含相機倍率與連鎖加成）。
      switch ((material.shotTier, material.isSpotlight)) {
        case (ShotTier.failed, true):
          failedSpotlightHype += material.hypeValue;
        case (ShotTier.failed, false):
          failedNonSpotlightHype += material.hypeValue;
        case (ShotTier.normal, true):
          normalSpotlightHype += material.hypeValue;
        case (ShotTier.normal, false):
          normalNonSpotlightHype += material.hypeValue;
        case (ShotTier.perfect, true):
          perfectSpotlightHype += material.hypeValue;
        case (ShotTier.perfect, false):
          perfectNonSpotlightHype += material.hypeValue;
      }

      // 槽位專屬 Theme 加成
      final slotType = TimelineSlotType.values[i];
      final bonus = slotType.evaluateSlotBonus(material);
      if (bonus > 0) {
        slotThemeBonuses[i] = bonus;
        slotBonusSum += bonus;
      }

      // 旅行哲學契合度計算 (D1/D2)
      final philContribution = philosophy.evaluateMaterial(material);
      sumCardContribution +=
          philContribution.effectiveTheme - philContribution.flatThemePenalty;
      if (!philContribution.isAligned) {
        allFilledAligned = false;
      }

      // 槽位 Hype 基礎倍率 (黃昏槽位 Slot 2 享有相機倍率)
      final baseHype = (i == 2)
          ? material.hypeValue * cameraMultiplier
          : material.hypeValue.toDouble();

      slotEffectiveHypes[i] = baseHype.round();
    }

    // 2. 相鄰槽位關係判定 (0,1), (1,2), (2,3)
    var rhythmBonusSum = 0;
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
        rhythmBonusSum += 10;
      }

      // 2.3 拉車疲勞 (兩者皆為高風險 >=3) -> -10 Theme
      if (isPrevHigh && isCurrHigh) {
        fatiguePairs.add(pairIndex);
      }
    }

    final totalHype = slotEffectiveHypes.fold<int>(0, (sum, h) => sum + h);

    // 3. 兩階段 Theme 計算 (D1/D2)
    // 3.1 契合度基準分：50 + round(sum(cardContribution) / filledCount)，空槽不進分母
    final themeBaseline = filledCount == 0
        ? baseTheme
        : baseTheme + (sumCardContribution / filledCount).round();

    // 3.2 純度判定：所有已填素材皆為契合素材
    final purityActive = filledCount > 0 && allFilledAligned;
    const purityBonus = defaultPurityBonus;

    // 3.3 扣除疲勞前 Theme (含基準、時段、節奏與純度)
    final themeBeforeFatigue =
        themeBaseline + slotBonusSum + rhythmBonusSum + (purityActive ? purityBonus : 0);

    // 3.4 最終 Theme：最後扣減疲勞再進行 0~100 clamp
    final fatiguePenalty = fatiguePairs.length * 10;
    final finalTheme = (themeBeforeFatigue - fatiguePenalty).clamp(0, 100);

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
      spotlightCount: spotlightCount,
      themeBaseline: themeBaseline,
      themeBeforeFatigue: themeBeforeFatigue,
      purityActive: purityActive,
      hasSpotlight: spotlightCount > 0,
      failedSpotlightHype: failedSpotlightHype,
      failedNonSpotlightHype: failedNonSpotlightHype,
      normalSpotlightHype: normalSpotlightHype,
      normalNonSpotlightHype: normalNonSpotlightHype,
      perfectSpotlightHype: perfectSpotlightHype,
      perfectNonSpotlightHype: perfectNonSpotlightHype,
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

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _setEquals<T>(Set<T>? a, Set<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  return a.containsAll(b);
}

bool _mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || b[key] != a[key]) return false;
  }
  return true;
}
