import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/causal/causal_fact.dart';
import 'package:share_tour/domain/core_loop/causal/causal_report_builder.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';

void main() {
  TravelMaterial mat({
    required String id,
    List<String> tags = const ['#散步'],
    int cost = 100,
    int theme = 30,
    int hype = 40,
    int risk = 1,
    bool isSpotlight = false,
  }) {
    return TravelMaterial(
      id: id,
      name: id,
      tags: tags,
      themeValue: theme,
      hypeValue: hype,
      riskLevel: risk,
      cost: cost,
      isSpotlight: isSpotlight,
    );
  }

  final samplePhilosophy = TravelPhilosophy.slow; // preferred: #散步, #古蹟; repelled: #高風險
  final sampleWorker = ClientSpec.budgetWorker;
  final sampleInfluencer = ClientSpec.hypeInfluencer;

  group('AC-CF-1.1: 相鄰兩槽 riskLevel >= 3 產出 fatigue_spike', () {
    test('產出 fatigue_spike (negative/major) 且 hasFatigue 為 true', () {
      final itinerary = TimelineItinerary(
        slots: [
          mat(id: 'm1', risk: 3),
          mat(id: 'm2', risk: 4),
          mat(id: 'm3', risk: 1),
          mat(id: 'm4', risk: 1),
        ],
      );
      final stats = itinerary.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final report = CausalReportBuilder.build(
        itinerary: itinerary,
        stats: stats,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );

      expect(report.hasFatigue, isTrue);
      final fact = report.facts.firstWhere((f) => f.reasonCode == 'fatigue_spike');
      expect(fact.domain, CausalDomain.adjacency);
      expect(fact.direction, ImpactDirection.negative);
      expect(fact.intensity, ImpactIntensity.major);
      expect(fact.pairIndices, equals((0, 1)));
    });
  });

  group('AC-CF-1.2: 網紅 × 混亂冒險產出 chaotic_combo 且不產出 fatigue_hype_penalty', () {
    test('混亂冒險反轉 Hype 疲勞為 chaotic_combo，但 Theme 側 fatigue_spike 仍須產出', () {
      final chaoticPhilosophy = TravelPhilosophy.chaos;
      final itinerary = TimelineItinerary(
        slots: [
          mat(id: 'm1', risk: 3),
          mat(id: 'm2', risk: 4),
          mat(id: 'm3', risk: 1),
          mat(id: 'm4', risk: 1),
        ],
      );
      final stats = itinerary.calculateStats(
        philosophy: chaoticPhilosophy,
        cameraMultiplier: 1.5,
      );
      final report = CausalReportBuilder.build(
        itinerary: itinerary,
        stats: stats,
        philosophy: chaoticPhilosophy,
        client: sampleInfluencer,
      );

      final codes = report.facts.map((f) => f.reasonCode).toList();
      expect(codes, contains('chaotic_combo'));
      expect(codes, contains('fatigue_spike'));
      expect(codes, isNot(contains('fatigue_hype_penalty')));

      final comboFact = report.facts.firstWhere((f) => f.reasonCode == 'chaotic_combo');
      expect(comboFact.domain, CausalDomain.adjacency);
      expect(comboFact.direction, ImpactDirection.positive);
      expect(comboFact.intensity, ImpactIntensity.major);
      expect(comboFact.pairIndices, equals((0, 1)));
    });
  });

  group('AC-CF-1.3: 社畜局不產出 chaotic_combo 或 fatigue_hype_penalty', () {
    test('社畜審查無 Hype 側疲勞與連段', () {
      final itinerary = TimelineItinerary(
        slots: [
          mat(id: 'm1', risk: 3),
          mat(id: 'm2', risk: 4),
          mat(id: 'm3', risk: 1),
          mat(id: 'm4', risk: 1),
        ],
      );
      final stats = itinerary.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final report = CausalReportBuilder.build(
        itinerary: itinerary,
        stats: stats,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );

      final codes = report.facts.map((f) => f.reasonCode).toList();
      expect(codes, isNot(contains('chaotic_combo')));
      expect(codes, isNot(contains('fatigue_hype_penalty')));
    });
  });

  group('AC-CF-1.4: 動態預算超支判定', () {
    test('社畜超支 10% 產出 minor、超支 35% 產出 major；網紅不超支不產出事實', () {
      // 社畜預算 2000
      // 行程 A：花費 2200（超支 200 = 10% <= 15%）
      final itineraryMinor = TimelineItinerary(
        slots: [
          mat(id: 'm1', cost: 1100),
          mat(id: 'm2', cost: 1100),
          mat(id: 'm3', cost: 0),
          mat(id: 'm4', cost: 0),
        ],
      );
      final statsMinor = itineraryMinor.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final reportWorkerMinor = CausalReportBuilder.build(
        itinerary: itineraryMinor,
        stats: statsMinor,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      expect(reportWorkerMinor.isOverBudget, isTrue);
      final factMinor = reportWorkerMinor.facts.firstWhere((f) => f.reasonCode == 'budget_overrun_minor');
      expect(factMinor.intensity, ImpactIntensity.minor);
      expect(factMinor.direction, ImpactDirection.negative);

      // 同一行程對網紅（預算 8000）不超支
      final reportInfluencer = CausalReportBuilder.build(
        itinerary: itineraryMinor,
        stats: statsMinor,
        philosophy: samplePhilosophy,
        client: sampleInfluencer,
      );
      expect(reportInfluencer.isOverBudget, isFalse);
      expect(reportInfluencer.facts.any((f) => f.reasonCode.startsWith('budget_overrun')), isFalse);

      // 行程 B：花費 2700（超支 700 = 35% > 15%）
      final itineraryMajor = TimelineItinerary(
        slots: [
          mat(id: 'm1', cost: 1700),
          mat(id: 'm2', cost: 1000),
          mat(id: 'm3', cost: 0),
          mat(id: 'm4', cost: 0),
        ],
      );
      final statsMajor = itineraryMajor.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final reportWorkerMajor = CausalReportBuilder.build(
        itinerary: itineraryMajor,
        stats: statsMajor,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      final factMajor = reportWorkerMajor.facts.firstWhere((f) => f.reasonCode == 'budget_overrun_major');
      expect(factMajor.intensity, ImpactIntensity.major);
    });
  });

  group('AC-CF-1.5: clientImpression 由 ReviewOutcome 導出且包含社畜 50~59 分案例', () {
    test('perfect/pass/nearMiss/stressed/furious 映射驗證與社畜退件分界', () {
      // 1. 社畜 satisfaction 落在 50~59 時為 rejected -> stressed（非 nearMiss）
      // budgetScore: cost 2000 => 44 分
      // themeScore: 56 * 20 / 100 = 11 分
      // boredom: 0 (hype >= 168)
      // satisfaction = 44 + 11 = 55 分（社畜 < 60 退件，網紅 < 50 退件）
      final itinerary55 = TimelineItinerary(
        slots: [
          mat(id: 'm1', tags: const [], theme: 0, hype: 50, cost: 500, risk: 3),
          mat(id: 'm2', tags: const [], theme: 0, hype: 50, cost: 500, risk: 3),
          mat(id: 'm3', tags: const [], theme: 0, hype: 50, cost: 500, risk: 3),
          mat(id: 'm4', tags: const [], theme: 0, hype: 50, cost: 500, risk: 3),
        ],
      );
      final stats55 = itinerary55.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final reportWorker55 = CausalReportBuilder.build(
        itinerary: itinerary55,
        stats: stats55,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      expect(reportWorker55.clientImpression, equals(ClientImpression.stressed));

      // 2. perfect -> ecstatic (滿分 100: cost 100, finalTheme 100, hype 200)
      final itineraryPerfect = TimelineItinerary(
        slots: [
          mat(id: 'm1', tags: ['#古蹟', '#散步'], theme: 100, hype: 50, cost: 25),
          mat(id: 'm2', tags: ['#古蹟', '#散步'], theme: 100, hype: 50, cost: 25),
          mat(id: 'm3', tags: ['#古蹟', '#散步'], theme: 100, hype: 50, cost: 25),
          mat(id: 'm4', tags: ['#古蹟', '#散步'], theme: 100, hype: 50, cost: 25),
        ],
      );
      final statsPerfect = itineraryPerfect.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final reportPerfect = CausalReportBuilder.build(
        itinerary: itineraryPerfect,
        stats: statsPerfect,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      expect(reportPerfect.clientImpression, equals(ClientImpression.ecstatic));

      // 3. pass -> pleased (satisfaction 70~89: budgetScore 44 + themeScore 28 = 72)
      // 構造 finalTheme 約 50
      final itineraryPass = TimelineItinerary(
        slots: [
          mat(id: 'm1', tags: const [], theme: 0, hype: 50, cost: 25),
          mat(id: 'm2', tags: const [], theme: 0, hype: 50, cost: 25),
          mat(id: 'm3', tags: const [], theme: 0, hype: 50, cost: 25),
          mat(id: 'm4', tags: const [], theme: 0, hype: 50, cost: 25),
        ],
      );
      final statsPass = itineraryPass.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final reportPass = CausalReportBuilder.build(
        itinerary: itineraryPass,
        stats: statsPass,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      expect(reportPass.clientImpression, equals(ClientImpression.pleased));

      // 4. nearMiss -> neutral (社畜 60~69: satisfaction 62)
      // cost 2200 超支 10% 扣 10 分: budgetScore 34 + themeScore 28 = 62 -> nearMiss
      final itineraryNearMiss = TimelineItinerary(
        slots: [
          mat(id: 'm1', tags: const [], theme: 0, hype: 50, cost: 550, risk: 1),
          mat(id: 'm2', tags: const [], theme: 0, hype: 50, cost: 550, risk: 1),
          mat(id: 'm3', tags: const [], theme: 0, hype: 50, cost: 550, risk: 1),
          mat(id: 'm4', tags: const [], theme: 0, hype: 50, cost: 550, risk: 1),
        ],
      );
      final statsNearMiss = itineraryNearMiss.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final reportNearMiss = CausalReportBuilder.build(
        itinerary: itineraryNearMiss,
        stats: statsNearMiss,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      expect(reportNearMiss.clientImpression, equals(ClientImpression.neutral));

      // 5. rejected (< 30) -> furious
      // 大幅超支 cost 4000 (budgetScore 0) + boredomPenalty 25 + low theme
      final itineraryFurious = TimelineItinerary(
        slots: [
          mat(id: 'm1', tags: const [], theme: 0, hype: 10, cost: 1000),
          mat(id: 'm2', tags: const [], theme: 0, hype: 10, cost: 1000),
          mat(id: 'm3', tags: const [], theme: 0, hype: 10, cost: 1000),
          mat(id: 'm4', tags: const [], theme: 0, hype: 10, cost: 1000),
        ],
      );
      final statsFurious = itineraryFurious.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final reportFurious = CausalReportBuilder.build(
        itinerary: itineraryFurious,
        stats: statsFurious,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      expect(reportFurious.clientImpression, equals(ClientImpression.furious));
    });
  });

  group('AC-CF-1.6: stats.canSubmit == false 時為 idle 且不等於 neutral', () {
    test('未達提交門檻（如 2 槽）為 idle', () {
      final itinerary2 = TimelineItinerary(
        slots: [
          mat(id: 'm1'),
          mat(id: 'm2'),
          null,
          null,
        ],
      );
      final stats = itinerary2.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      expect(stats.canSubmit, isFalse);

      final report = CausalReportBuilder.build(
        itinerary: itinerary2,
        stats: stats,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      expect(report.clientImpression, equals(ClientImpression.idle));
      expect(report.clientImpression, isNot(equals(ClientImpression.neutral)));
    });
  });

  group('AC-CF-1.7: Slot 0, 1, 3 各自命中時段加成皆產出 ambient_slot_affinity', () {
    test('Slot 0/1/3 分別觸發對應 slotIndex 的時段加成事實', () {
      final itinerary = TimelineItinerary(
        slots: [
          mat(id: 'm1', tags: ['#散步'], risk: 1),
          mat(id: 'm2', tags: ['#美食'], risk: 1),
          mat(id: 'm3', tags: const []),
          mat(id: 'm4', tags: ['#深夜'], risk: 1),
        ],
      );
      final stats = itinerary.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final report = CausalReportBuilder.build(
        itinerary: itinerary,
        stats: stats,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );

      final slotAffinities = report.facts
          .where((f) => f.reasonCode == 'ambient_slot_affinity')
          .map((f) => f.slotIndex)
          .toSet();

      expect(slotAffinities, containsAll({0, 1, 3}));
    });
  });

  group('AC-CF-1.8: primaryCulpritSlot 依 §2.4 五款優先序與平手取較小索引', () {
    test('款 1：超支優先於疲勞，且平手取索引較小者', () {
      // 同時超支且有疲勞對
      // Slot 0 (cost 1500), Slot 1 (cost 1500) -> 總花費 3000 > 2000 超支
      // 兩者皆最高 cost 1500，平手取索引較小者 Slot 0
      final itinerary = TimelineItinerary(
        slots: [
          mat(id: 'm1', cost: 1500, risk: 4),
          mat(id: 'm2', cost: 1500, risk: 4),
          mat(id: 'm3', cost: 0, risk: 1),
          mat(id: 'm4', cost: 0, risk: 1),
        ],
      );
      final stats = itinerary.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final report = CausalReportBuilder.build(
        itinerary: itinerary,
        stats: stats,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      expect(report.primaryCulpritSlot, equals(0));
    });

    test('款 2：疲勞對優先於排斥，取涉及槽位中最高 riskLevel 者', () {
      // 未超支，有疲勞對 (0, 1)，且 Slot 2 排斥（#高風險）
      // Slot 0 risk 3, Slot 1 risk 4 -> 最高 risk 為 Slot 1
      final itinerary = TimelineItinerary(
        slots: [
          mat(id: 'm1', cost: 100, risk: 3),
          mat(id: 'm2', cost: 100, risk: 4),
          mat(id: 'm3', cost: 100, risk: 1, tags: ['#高風險']),
          mat(id: 'm4', cost: 100, risk: 1),
        ],
      );
      final stats = itinerary.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final report = CausalReportBuilder.build(
        itinerary: itinerary,
        stats: stats,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      expect(report.primaryCulpritSlot, equals(1));
    });

    test('款 3：排斥標籤優先於絕景缺口，取命中排斥之最小索引槽位', () {
      // 網紅局，未超支、無疲勞，有絕景缺口 (spotlightCount < 4)
      // Slot 1 與 Slot 2 命中排斥標籤（#高風險），取較小索引 Slot 1
      final itinerary = TimelineItinerary(
        slots: [
          mat(id: 'm1', cost: 100, risk: 1, isSpotlight: false),
          mat(id: 'm2', cost: 100, risk: 1, tags: ['#高風險'], isSpotlight: false),
          mat(id: 'm3', cost: 100, risk: 1, tags: ['#高風險'], isSpotlight: false),
          mat(id: 'm4', cost: 100, risk: 1, isSpotlight: false),
        ],
      );
      final stats = itinerary.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final report = CausalReportBuilder.build(
        itinerary: itinerary,
        stats: stats,
        philosophy: samplePhilosophy,
        client: sampleInfluencer,
      );
      expect(report.primaryCulpritSlot, equals(1));
    });

    test('款 4：網紅絕景缺口取最小索引非絕景槽位', () {
      // 網紅局，未超支、無疲勞、無排斥
      // Slot 0 為絕景，Slot 1 為非絕景，Slot 2 為非絕景，Slot 3 為絕景
      // 取最小索引非絕景槽位 Slot 1
      final itinerary = TimelineItinerary(
        slots: [
          mat(id: 'm1', isSpotlight: true, cost: 100),
          mat(id: 'm2', isSpotlight: false, cost: 100),
          mat(id: 'm3', isSpotlight: false, cost: 100),
          mat(id: 'm4', isSpotlight: true, cost: 100),
        ],
      );
      final stats = itinerary.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final report = CausalReportBuilder.build(
        itinerary: itinerary,
        stats: stats,
        philosophy: samplePhilosophy,
        client: sampleInfluencer,
      );
      expect(report.primaryCulpritSlot, equals(1));
    });

    test('款 4 邊界：3 槽連續純絕景時，取第一個空槽位（Slot 3）', () {
      final itinerary3 = TimelineItinerary(
        slots: [
          mat(id: 'm1', isSpotlight: true, cost: 100),
          mat(id: 'm2', isSpotlight: true, cost: 100),
          mat(id: 'm3', isSpotlight: true, cost: 100),
          null,
        ],
      );
      final stats = itinerary3.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final report = CausalReportBuilder.build(
        itinerary: itinerary3,
        stats: stats,
        philosophy: samplePhilosophy,
        client: sampleInfluencer,
      );
      expect(report.primaryCulpritSlot, equals(3));
    });

    test('款 5：無任何負面失分項時為 null', () {
      // 4 槽純絕景、低花費、無疲勞、無排斥
      final itinerary = TimelineItinerary(
        slots: [
          mat(id: 'm1', isSpotlight: true, cost: 100),
          mat(id: 'm2', isSpotlight: true, cost: 100),
          mat(id: 'm3', isSpotlight: true, cost: 100),
          mat(id: 'm4', isSpotlight: true, cost: 100),
        ],
      );
      final stats = itinerary.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final report = CausalReportBuilder.build(
        itinerary: itinerary,
        stats: stats,
        philosophy: samplePhilosophy,
        client: sampleInfluencer,
      );
      expect(report.primaryCulpritSlot, isNull);
    });
  });

  group('AC-CF-1.9: ItineraryCausalReport 與 CausalFact 的值相等性', () {
    test('兩份相同內容報告 == 為真且 hashCode 相等', () {
      final fact1a = const CausalFact(
        domain: CausalDomain.adjacency,
        direction: ImpactDirection.negative,
        intensity: ImpactIntensity.major,
        pairIndices: (0, 1),
        sourceSignifier: '💀 拉車疲勞',
        reasonCode: 'fatigue_spike',
      );
      final fact1b = const CausalFact(
        domain: CausalDomain.adjacency,
        direction: ImpactDirection.negative,
        intensity: ImpactIntensity.major,
        pairIndices: (0, 1),
        sourceSignifier: '💀 拉車疲勞',
        reasonCode: 'fatigue_spike',
      );
      expect(fact1a, equals(fact1b));
      expect(fact1a.hashCode, equals(fact1b.hashCode));

      final reportA = ItineraryCausalReport(
        facts: [fact1a],
        clientImpression: ClientImpression.stressed,
        hasFatigue: true,
        isOverBudget: false,
        primaryCulpritSlot: 0,
      );
      final reportB = ItineraryCausalReport(
        facts: [fact1b],
        clientImpression: ClientImpression.stressed,
        hasFatigue: true,
        isOverBudget: false,
        primaryCulpritSlot: 0,
      );
      expect(reportA, equals(reportB));
      expect(reportA.hashCode, equals(reportB.hashCode));
    });
  });

  group('AC-CF-1.10: rhythm_complement 與 fatigue_spike 互斥', () {
    test('一高一低產生 rhythm_complement，同一對槽位不產出 fatigue_spike', () {
      final itinerary = TimelineItinerary(
        slots: [
          mat(id: 'm1', risk: 4),
          mat(id: 'm2', risk: 1),
          mat(id: 'm3', risk: 1),
          mat(id: 'm4', risk: 1),
        ],
      );
      final stats = itinerary.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final report = CausalReportBuilder.build(
        itinerary: itinerary,
        stats: stats,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );

      final codes = report.facts.map((f) => f.reasonCode).toList();
      expect(codes, contains('rhythm_complement'));
      expect(codes, isNot(contains('fatigue_spike')));
      final rhythmFact = report.facts.firstWhere((f) => f.reasonCode == 'rhythm_complement');
      expect(rhythmFact.direction, ImpactDirection.positive);
      expect(rhythmFact.intensity, ImpactIntensity.major);
    });
  });

  group('AC-CF-1.11: 網紅局絕景階梯三檔覆蓋', () {
    test('spotlightCount 為 0 產出 major，為 2 產出 minor，為 4 產出 spotlight_full；社畜不產出', () {
      // 0 絕景
      final itinerary0 = TimelineItinerary(
        slots: [
          mat(id: 'm1', isSpotlight: false),
          mat(id: 'm2', isSpotlight: false),
          mat(id: 'm3', isSpotlight: false),
          mat(id: 'm4', isSpotlight: false),
        ],
      );
      final stats0 = itinerary0.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final reportInf0 = CausalReportBuilder.build(
        itinerary: itinerary0,
        stats: stats0,
        philosophy: samplePhilosophy,
        client: sampleInfluencer,
      );
      final fact0 = reportInf0.facts.firstWhere((f) => f.reasonCode == 'spotlight_shortfall');
      expect(fact0.intensity, ImpactIntensity.major);

      // 社畜不產出絕景階梯
      final reportWork0 = CausalReportBuilder.build(
        itinerary: itinerary0,
        stats: stats0,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      expect(reportWork0.facts.any((f) => f.reasonCode.startsWith('spotlight_')), isFalse);

      // 2 絕景
      final itinerary2 = TimelineItinerary(
        slots: [
          mat(id: 'm1', isSpotlight: true),
          mat(id: 'm2', isSpotlight: true),
          mat(id: 'm3', isSpotlight: false),
          mat(id: 'm4', isSpotlight: false),
        ],
      );
      final stats2 = itinerary2.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final reportInf2 = CausalReportBuilder.build(
        itinerary: itinerary2,
        stats: stats2,
        philosophy: samplePhilosophy,
        client: sampleInfluencer,
      );
      final fact2 = reportInf2.facts.firstWhere((f) => f.reasonCode == 'spotlight_shortfall');
      expect(fact2.intensity, ImpactIntensity.minor);

      // 4 絕景
      final itinerary4 = TimelineItinerary(
        slots: [
          mat(id: 'm1', isSpotlight: true),
          mat(id: 'm2', isSpotlight: true),
          mat(id: 'm3', isSpotlight: true),
          mat(id: 'm4', isSpotlight: true),
        ],
      );
      final stats4 = itinerary4.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final reportInf4 = CausalReportBuilder.build(
        itinerary: itinerary4,
        stats: stats4,
        philosophy: samplePhilosophy,
        client: sampleInfluencer,
      );
      expect(reportInf4.facts.any((f) => f.reasonCode == 'spotlight_shortfall'), isFalse);
      final fact4 = reportInf4.facts.firstWhere((f) => f.reasonCode == 'spotlight_full');
      expect(fact4.direction, ImpactDirection.positive);
      expect(fact4.intensity, ImpactIntensity.major);
    });
  });

  group('AC-CF-1.12: 社畜局反無聊門檻 boredom_risk', () {
    test('社畜 Hype < boredomThreshold (168) 產出 major，高於時不產出；網紅皆不產出', () {
      final itineraryLowHype = TimelineItinerary(
        slots: [
          mat(id: 'm1', hype: 20),
          mat(id: 'm2', hype: 20),
          mat(id: 'm3', hype: 20),
          mat(id: 'm4', hype: 20),
        ],
      );
      final statsLow = itineraryLowHype.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      expect(statsLow.totalHype, lessThan(sampleWorker.boredomThreshold));

      final reportWorkerLow = CausalReportBuilder.build(
        itinerary: itineraryLowHype,
        stats: statsLow,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      final boredomFact = reportWorkerLow.facts.firstWhere((f) => f.reasonCode == 'boredom_risk');
      expect(boredomFact.domain, CausalDomain.boredom);
      expect(boredomFact.direction, ImpactDirection.negative);
      expect(boredomFact.intensity, ImpactIntensity.major);

      // 高於反無聊門檻時不產出
      final itineraryHighHype = TimelineItinerary(
        slots: [
          mat(id: 'm1', hype: 50),
          mat(id: 'm2', hype: 50),
          mat(id: 'm3', hype: 50),
          mat(id: 'm4', hype: 50),
        ],
      );
      final statsHigh = itineraryHighHype.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      expect(statsHigh.totalHype, greaterThanOrEqualTo(sampleWorker.boredomThreshold));
      final reportWorkerHigh = CausalReportBuilder.build(
        itinerary: itineraryHighHype,
        stats: statsHigh,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );
      expect(reportWorkerHigh.facts.any((f) => f.reasonCode == 'boredom_risk'), isFalse);

      // 網紅即便低 Hype 也不產出 boredom_risk
      final reportInfluencer = CausalReportBuilder.build(
        itinerary: itineraryLowHype,
        stats: statsLow,
        philosophy: samplePhilosophy,
        client: sampleInfluencer,
      );
      expect(reportInfluencer.facts.any((f) => f.reasonCode == 'boredom_risk'), isFalse);
    });
  });

  group('AC-CF-1.13: 排斥與契合互斥', () {
    test('素材同時包含排斥與偏好標籤時，只產出 philosophy_repelled 不產出 matched', () {
      final itinerary = TimelineItinerary(
        slots: [
          mat(id: 'm1', tags: ['#古蹟', '#高風險']),
          mat(id: 'm2'),
          mat(id: 'm3'),
          mat(id: 'm4'),
        ],
      );
      final stats = itinerary.calculateStats(
        philosophy: samplePhilosophy,
        cameraMultiplier: 1.5,
      );
      final report = CausalReportBuilder.build(
        itinerary: itinerary,
        stats: stats,
        philosophy: samplePhilosophy,
        client: sampleWorker,
      );

      final slot0Facts = report.facts.where((f) => f.slotIndex == 0).map((f) => f.reasonCode).toList();
      expect(slot0Facts, contains('philosophy_repelled'));
      expect(slot0Facts, isNot(contains('philosophy_matched_major')));
      expect(slot0Facts, isNot(contains('philosophy_matched_minor')));
    });
  });
}
