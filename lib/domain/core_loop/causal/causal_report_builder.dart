import '../models/review_outcome.dart';
import '../models/timeline_itinerary.dart';
import '../models/travel_philosophy.dart';
import '../review/client_review_engine.dart';
import '../review/client_spec.dart';
import 'causal_fact.dart';

/// 因果報告建構器（純領域無副作用純函式）
class CausalReportBuilder {
  /// 依既有評分規則與統計資料建構因果分析報告
  static ItineraryCausalReport build({
    required TimelineItinerary itinerary,
    required ItineraryStats stats,
    required TravelPhilosophy philosophy,
    required ClientSpec client,
  }) {
    final facts = <CausalFact>[];

    // 1. 相鄰槽位軸：拉車疲勞（Theme 側與 Hype 側）、冒險連段
    for (final p in stats.fatiguePairs) {
      final pair = (p, p + 1);

      // Theme 側疲勞：所有客戶皆扣除 10 點
      facts.add(CausalFact(
        domain: CausalDomain.adjacency,
        direction: ImpactDirection.negative,
        intensity: ImpactIntensity.major,
        pairIndices: pair,
        sourceSignifier: '💀 拉車疲勞',
        reasonCode: 'fatigue_spike',
      ));

      // Hype 側疲勞：僅限網紅局存在
      if (client.type == ClientType.hypeInfluencer) {
        if (philosophy.turnsAdjacentHighRiskIntoHypeCombo) {
          facts.add(CausalFact(
            domain: CausalDomain.adjacency,
            direction: ImpactDirection.positive,
            intensity: ImpactIntensity.major,
            pairIndices: pair,
            sourceSignifier: '⚡ 驚險連段',
            reasonCode: 'chaotic_combo',
          ));
        } else {
          facts.add(CausalFact(
            domain: CausalDomain.adjacency,
            direction: ImpactDirection.negative,
            intensity: ImpactIntensity.major,
            pairIndices: pair,
            sourceSignifier: '💀 脫妝暴跌',
            reasonCode: 'fatigue_hype_penalty',
          ));
        }
      }
    }

    // 2. 相鄰槽位軸：節奏互補（與疲勞同軸正面，互斥）
    for (final p in stats.rhythmActivePairs) {
      facts.add(CausalFact(
        domain: CausalDomain.adjacency,
        direction: ImpactDirection.positive,
        intensity: ImpactIntensity.major,
        pairIndices: (p, p + 1),
        sourceSignifier: '🎵 節奏互補',
        reasonCode: 'rhythm_complement',
      ));
    }

    // 3. 哲學契合與排斥
    for (var i = 0; i < itinerary.slots.length; i++) {
      final mat = itinerary.slots[i];
      if (mat == null) continue;

      final hitsRepelled = philosophy.repelledTags.any((t) => mat.hasTag(t));
      if (hitsRepelled) {
        facts.add(CausalFact(
          domain: CausalDomain.philosophySynergy,
          direction: ImpactDirection.negative,
          intensity: ImpactIntensity.major,
          slotIndex: i,
          sourceSignifier: '💢 排斥',
          reasonCode: 'philosophy_repelled',
        ));
      } else {
        final matchCount =
            philosophy.preferredTags.where((t) => mat.hasTag(t)).length;
        if (matchCount >= 2) {
          facts.add(CausalFact(
            domain: CausalDomain.philosophySynergy,
            direction: ImpactDirection.positive,
            intensity: ImpactIntensity.major,
            slotIndex: i,
            sourceSignifier: '★★ 強烈共鳴',
            reasonCode: 'philosophy_matched_major',
          ));
        } else if (matchCount == 1) {
          facts.add(CausalFact(
            domain: CausalDomain.philosophySynergy,
            direction: ImpactDirection.positive,
            intensity: ImpactIntensity.minor,
            slotIndex: i,
            sourceSignifier: '★ 契合',
            reasonCode: 'philosophy_matched_minor',
          ));
        }
      }
    }

    // 4. 預算上限與動態超支判定
    final isOverBudget = stats.totalCost > client.targetBudget;
    if (isOverBudget) {
      final overrunRatio =
          (stats.totalCost - client.targetBudget) / client.targetBudget;
      if (overrunRatio > 0.15) {
        facts.add(const CausalFact(
          domain: CausalDomain.budgetConstraint,
          direction: ImpactDirection.negative,
          intensity: ImpactIntensity.major,
          sourceSignifier: '🚨 超支·爆表',
          reasonCode: 'budget_overrun_major',
        ));
      } else {
        facts.add(const CausalFact(
          domain: CausalDomain.budgetConstraint,
          direction: ImpactDirection.negative,
          intensity: ImpactIntensity.minor,
          sourceSignifier: '⚠️ 超支·輕度',
          reasonCode: 'budget_overrun_minor',
        ));
      }
    }

    // 5. 絕景階梯（網紅限定）
    if (client.type == ClientType.hypeInfluencer) {
      if (stats.spotlightCount >= 4) {
        facts.add(const CausalFact(
          domain: CausalDomain.spotlight,
          direction: ImpactDirection.positive,
          intensity: ImpactIntensity.major,
          sourceSignifier: '🌟 絕景大滿貫',
          reasonCode: 'spotlight_full',
        ));
      } else {
        facts.add(CausalFact(
          domain: CausalDomain.spotlight,
          direction: ImpactDirection.negative,
          intensity: stats.spotlightCount <= 1
              ? ImpactIntensity.major
              : ImpactIntensity.minor,
          sourceSignifier: '📉 絕景缺口',
          reasonCode: 'spotlight_shortfall',
        ));
      }
    }

    // 6. 反無聊門檻（社畜限定斷崖）
    if (client.type == ClientType.budgetWorker &&
        stats.totalHype < client.boredomThreshold) {
      facts.add(const CausalFact(
        domain: CausalDomain.boredom,
        direction: ImpactDirection.negative,
        intensity: ImpactIntensity.major,
        sourceSignifier: '🚨 乏味風險',
        reasonCode: 'boredom_risk',
      ));
    }

    // 7. 環境：同標籤共鳴 (Tag Synergy)
    for (final slot in stats.comboActiveSlots) {
      facts.add(CausalFact(
        domain: CausalDomain.ambient,
        direction: ImpactDirection.positive,
        intensity: ImpactIntensity.major,
        slotIndex: slot,
        pairIndices: slot > 0 ? (slot - 1, slot) : null,
        sourceSignifier: '[共鳴]',
        reasonCode: 'tag_synergy',
      ));
    }

    // 8. 環境：槽位時段契合 (Slot Affinity)
    for (final slot in stats.slotThemeBonuses.keys) {
      facts.add(CausalFact(
        domain: CausalDomain.ambient,
        direction: ImpactDirection.positive,
        intensity: ImpactIntensity.minor,
        slotIndex: slot,
        sourceSignifier: '[時段契合]',
        reasonCode: 'ambient_slot_affinity',
      ));
    }

    // 9. 快門三態對第二層分數的影響（REQ-M5-08.2）。單一詞條
    // （'shot_quality'），方向依行程中是否存在 perfect／failed 素材決定；
    // 兩者皆存在時各記一條——這條事實指向第二層分數，不指向 satisfaction，
    // 故只看 hypeSumByTier 的六分量，不呼叫 ClientReviewEngine。
    final failedHype =
        stats.failedSpotlightHype + stats.failedNonSpotlightHype;
    final perfectHype =
        stats.perfectSpotlightHype + stats.perfectNonSpotlightHype;
    if (failedHype > 0) {
      facts.add(const CausalFact(
        domain: CausalDomain.shotQuality,
        direction: ImpactDirection.negative,
        sourceSignifier: '快門失手',
        reasonCode: 'shot_quality',
      ));
    }
    if (perfectHype > 0) {
      facts.add(const CausalFact(
        domain: CausalDomain.shotQuality,
        direction: ImpactDirection.positive,
        sourceSignifier: '快門完美',
        reasonCode: 'shot_quality',
      ));
    }

    // 嚴格全序排序：domain → (slotIndex ?? pairIndices?.$1 ?? 99) → (pairIndices?.$2 ?? 99) → reasonCode
    facts.sort(_compareFacts);

    // 客戶即時心態導出
    final ClientImpression impression;
    if (!stats.canSubmit) {
      impression = ClientImpression.idle;
    } else {
      final reviewReport = ClientReviewEngine.evaluate(
        client: client,
        stats: stats,
        philosophy: philosophy,
      );
      switch (reviewReport.outcome) {
        case ReviewOutcome.perfect:
          impression = ClientImpression.ecstatic;
          break;
        case ReviewOutcome.pass:
          impression = ClientImpression.pleased;
          break;
        case ReviewOutcome.nearMiss:
          impression = ClientImpression.neutral;
          break;
        case ReviewOutcome.rejected:
          impression = reviewReport.satisfaction >= 30
              ? ClientImpression.stressed
              : ClientImpression.furious;
          break;
      }
    }

    // 最嚴重失分槽位
    final primaryCulpritSlot = _derivePrimaryCulpritSlot(
      itinerary: itinerary,
      stats: stats,
      philosophy: philosophy,
      client: client,
    );

    return ItineraryCausalReport(
      facts: List.unmodifiable(facts),
      clientImpression: impression,
      hasFatigue: stats.fatiguePairs.isNotEmpty,
      isOverBudget: isOverBudget,
      primaryCulpritSlot: primaryCulpritSlot,
    );
  }

  static int _compareFacts(CausalFact a, CausalFact b) {
    final domainCmp = a.domain.index.compareTo(b.domain.index);
    if (domainCmp != 0) return domainCmp;

    final aIdx1 = a.slotIndex ?? a.pairIndices?.$1 ?? 99;
    final bIdx1 = b.slotIndex ?? b.pairIndices?.$1 ?? 99;
    final idx1Cmp = aIdx1.compareTo(bIdx1);
    if (idx1Cmp != 0) return idx1Cmp;

    final aIdx2 = a.pairIndices?.$2 ?? 99;
    final bIdx2 = b.pairIndices?.$2 ?? 99;
    final idx2Cmp = aIdx2.compareTo(bIdx2);
    if (idx2Cmp != 0) return idx2Cmp;

    return a.reasonCode.compareTo(b.reasonCode);
  }

  static int? _derivePrimaryCulpritSlot({
    required TimelineItinerary itinerary,
    required ItineraryStats stats,
    required TravelPhilosophy philosophy,
    required ClientSpec client,
  }) {
    // 1. 若超支：取已填槽位中 cost 最高者（平手取索引較小者）
    if (stats.totalCost > client.targetBudget) {
      int? highestCostSlot;
      int highestCost = -1;
      for (var i = 0; i < itinerary.slots.length; i++) {
        final mat = itinerary.slots[i];
        if (mat != null && mat.cost > highestCost) {
          highestCost = mat.cost;
          highestCostSlot = i;
        }
      }
      return highestCostSlot;
    }

    // 2. 否則若有疲勞對：取所有疲勞對涉及之槽位中 riskLevel 最高者（平手取索引較小者）
    if (stats.fatiguePairs.isNotEmpty) {
      final involvedSlots = <int>{};
      for (final p in stats.fatiguePairs) {
        involvedSlots.add(p);
        involvedSlots.add(p + 1);
      }
      final sortedInvolved = involvedSlots.toList()..sort();
      int? highestRiskSlot;
      int highestRisk = -1;
      for (final i in sortedInvolved) {
        final mat = itinerary.slots[i];
        if (mat != null && mat.riskLevel > highestRisk) {
          highestRisk = mat.riskLevel;
          highestRiskSlot = i;
        }
      }
      return highestRiskSlot;
    }

    // 3. 否則若有 philosophy_repelled：取索引最小的命中槽位
    for (var i = 0; i < itinerary.slots.length; i++) {
      final mat = itinerary.slots[i];
      if (mat != null && philosophy.repelledTags.any((t) => mat.hasTag(t))) {
        return i;
      }
    }

    // 4. 否則若客戶為 hypeInfluencer 且 spotlight_shortfall 成立：
    //    取索引最小的非絕景已填槽位；若已填槽位全為絕景，則取第一個空槽位；若皆無則為 null
    if (client.type == ClientType.hypeInfluencer && stats.spotlightCount < 4) {
      for (var i = 0; i < itinerary.slots.length; i++) {
        final mat = itinerary.slots[i];
        if (mat != null && !mat.isSpotlight) {
          return i;
        }
      }
      for (var i = 0; i < itinerary.slots.length; i++) {
        if (itinerary.slots[i] == null) {
          return i;
        }
      }
      return null;
    }

    // 5. 否則為 null
    return null;
  }
}
