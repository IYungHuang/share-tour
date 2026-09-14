/// 因果語意事實模型（純 Dart，零依賴）
enum ImpactDirection { positive, negative }

enum ImpactIntensity { minor, major }

enum CausalDomain {
  adjacency, // 相鄰槽位軸：疲勞 / 連段 / 節奏互補
  philosophySynergy, // 哲學契合與排斥
  budgetConstraint, // 預算上限與超支
  spotlight, // 絕景階梯
  boredom, // 反無聊門檻
  ambient, // 環境：同標籤共鳴、槽位時段契合
  shotQuality, // 快門三態對第二層分數的影響（REQ-M5-08.2），與 satisfaction 無關
}

/// 供 UI 轉譯為表情的客戶即時心態
enum ClientImpression { ecstatic, pleased, neutral, stressed, furious, idle }

/// 單項因果事實不可變實體
class CausalFact {
  final CausalDomain domain;
  final ImpactDirection direction;
  final ImpactIntensity intensity;
  final int? slotIndex;
  final (int, int)? pairIndices;
  final String sourceSignifier;
  final String reasonCode;

  const CausalFact({
    required this.domain,
    required this.direction,
    this.intensity = ImpactIntensity.minor,
    this.slotIndex,
    this.pairIndices,
    required this.sourceSignifier,
    required this.reasonCode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CausalFact &&
          runtimeType == other.runtimeType &&
          domain == other.domain &&
          direction == other.direction &&
          intensity == other.intensity &&
          slotIndex == other.slotIndex &&
          pairIndices == other.pairIndices &&
          sourceSignifier == other.sourceSignifier &&
          reasonCode == other.reasonCode;

  @override
  int get hashCode => Object.hash(
        domain,
        direction,
        intensity,
        slotIndex,
        pairIndices,
        sourceSignifier,
        reasonCode,
      );

  @override
  String toString() =>
      'CausalFact(code: $reasonCode, signifier: $sourceSignifier, intensity: $intensity, slot: $slotIndex, pair: $pairIndices)';
}

/// 時間線行程因果彙總報告
class ItineraryCausalReport {
  final List<CausalFact> facts;
  final ClientImpression clientImpression;
  final bool hasFatigue;
  final bool isOverBudget;
  final int? primaryCulpritSlot;

  const ItineraryCausalReport({
    required this.facts,
    required this.clientImpression,
    required this.hasFatigue,
    required this.isOverBudget,
    this.primaryCulpritSlot,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItineraryCausalReport &&
          runtimeType == other.runtimeType &&
          clientImpression == other.clientImpression &&
          hasFatigue == other.hasFatigue &&
          isOverBudget == other.isOverBudget &&
          primaryCulpritSlot == other.primaryCulpritSlot &&
          _factsEqual(facts, other.facts);

  static bool _factsEqual(List<CausalFact> a, List<CausalFact> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(facts),
        clientImpression,
        hasFatigue,
        isOverBudget,
        primaryCulpritSlot,
      );

  @override
  String toString() =>
      'ItineraryCausalReport(impression: $clientImpression, culprit: $primaryCulpritSlot, facts: ${facts.length})';
}
