import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';

void main() {
  group('雙客戶 100 分制審查引擎測試 (AC-ML-5)', () {
    ItineraryStats createStats({
      int cost = 1500,
      int hype = 50,
      int theme = 70,
      int story = 5,
      bool hasSpotlight = false,
      int? spotlightCount,
      Set<int> fatiguePairs = const {},
    }) => ItineraryStats(
      totalCost: cost,
      totalHype: hype,
      finalTheme: theme,
      totalStory: story,
      canSubmit: true,
      slotEffectiveHypes: const [10, 20, 10, 10],
      comboActiveSlots: const {},
      rhythmActivePairs: const {},
      fatiguePairs: fatiguePairs,
      slotThemeBonuses: const {},
      spotlightCount: spotlightCount ?? (hasSpotlight ? 1 : 0),
      themeBaseline: 50,
      themeBeforeFatigue: theme,
      purityActive: false,
      hasSpotlight: hasSpotlight || (spotlightCount != null && spotlightCount > 0),
    );

    test('AC-ML-5.1 社畜滿分 (Perfect): 花費 <= 2000, Theme >= 60, Hype >= boredomThreshold', () {
      final stats = createStats(cost: 1800, theme: 90, hype: 200, story: 4);
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.budgetWorker,
        stats: stats,
        philosophy: TravelPhilosophy.slow,
      );

      expect(report.outcome, ReviewOutcome.perfect);
      expect(report.satisfaction, greaterThanOrEqualTo(90));
      expect(report.earnedCoins, 1000 * 1.5 + (4 * 5)); // 1500 + 20 = 1520
    });

    test('AC-ML-5.2 社畜反無聊打擊: 0 花費但 Hype < boredomThreshold，扣 25 分無法達成 Perfect', () {
      final stats = createStats(cost: 0, theme: 70, hype: 15, story: 4);
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.budgetWorker,
        stats: stats,
        philosophy: TravelPhilosophy.slow,
      );

      // Budget 44 + Theme 39 - Boredom 25 = 58
      expect(report.satisfaction, 58);
      expect(report.outcome, ReviewOutcome.rejected); // 降為 Rejected，無法 Perfect
    });

    test(
      'AC-ML-5.3 社畜比例超支扣分: 超支 640 円 (32%, 扣 32 分), Theme 60 得 34 分 -> 滿意度 46 分',
      () {
        final stats = createStats(cost: 2640, theme: 60, hype: 200, story: 4);
        final report = ClientReviewEngine.evaluate(
          client: ClientSpec.budgetWorker,
          stats: stats,
          philosophy: TravelPhilosophy.slow,
        );

        // BudgetScore: 44 - round(640 / 2000 * 100) = 44 - 32 = 12
        // ThemeScore: round(56 * 0.6) = 34
        // Boredom: 0
        // Total: 12 + 34 = 46
        expect(report.satisfaction, 46);
        expect(report.outcome, ReviewOutcome.rejected);
        expect(
          report.earnedCoins,
          0 + (4 * 5),
        ); // 0 + 20 = 20
      },
    );


    test('AC-ML-5.4 網紅通關 (Perfect): Hype >= 150, 具絕景且無疲勞 (Theme=100)', () {
      final stats = createStats(
        hype: 180,
        hasSpotlight: true,
        spotlightCount: 1,
        theme: 100,
        fatiguePairs: const {},
        story: 5,
      );
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.hypeInfluencer,
        stats: stats,
        philosophy: TravelPhilosophy.slow,
      );

      // EffectiveHype: round(180 * 0.75) = 135
      // ThemeFactor: (44 + 56 * 1.0) / 100 = 1.0
      // Satisfaction: (135 / 150 * 100 * 1.0).round() = 90
      expect(report.outcome, ReviewOutcome.perfect);
      expect(report.satisfaction, greaterThanOrEqualTo(90));
      expect(report.earnedCoins, 1500 * 1.5 + (5 * 5)); // 2250 + 25 = 2275
    });

    test('AC-ML-5.5 網紅無絕景階梯 Near Miss: Hype 130 無絕景 (0.70x) 得 61 分', () {
      final stats = createStats(
        hype: 130,
        hasSpotlight: false, // 0 張絕景乘 0.70
        spotlightCount: 0,
        theme: 100,
        fatiguePairs: const {},
        story: 3,
      );
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.hypeInfluencer,
        stats: stats,
        philosophy: TravelPhilosophy.slow,
      );

      // EffectiveHype: round(130 * 0.70) = 91
      // ThemeFactor: (44 + 56 * 1.0) / 100 = 1.0
      // Satisfaction: (91 / 150 * 100 * 1.0).round() = 61
      expect(report.satisfaction, 61);
      expect(report.outcome, ReviewOutcome.nearMiss);
      expect(
        report.earnedCoins,
        (1500 * 0.3).round() + (3 * 5),
      ); // 450 + 15 = 465
    });

    test('AC-ML-5.6 網紅疲勞脫妝退件 (Rejected): 疲勞扣 42 Hype，Theme 20 導致滿意度 22 分', () {
      final stats = createStats(
        hype: 120,
        hasSpotlight: true,
        spotlightCount: 1,
        theme: 20,
        fatiguePairs: const {0, 2}, // 2 次疲勞扣 42 Hype
        story: 2,
      );
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.hypeInfluencer,
        stats: stats,
        philosophy: TravelPhilosophy.slow,
      );

      // Fatigue: 120 - (2 * 21) = 78
      // Spotlight: round(78 * 0.75) = 59
      // ThemeFactor: (44 + 56 * (20 / 100)) / 100 = 0.552
      // Satisfaction: (59 / 150 * 100 * 0.552).round() = 22
      expect(report.satisfaction, 22);
      expect(report.outcome, ReviewOutcome.rejected);
      expect(report.earnedCoins, 0 + (2 * 5)); // 0 佣金 + 10 故事幣
    });

    group('AC-A1-1.7 & AC-A1-1.8 Theme 傳導到兩位客戶滿意度 (T3)', () {
      test('AC-A1-1.7 社畜參考行程：Theme 90 得分 85~95，Theme 降至 30 時降幅 >= 20', () {
        // 固定參考輸入：未超支 (cost 1000 <= 2000), 無聊不觸發 (hype 200 >= boredomThreshold)
        final stats90 = createStats(cost: 1000, hype: 200, theme: 90);
        final report90 = ClientReviewEngine.evaluate(
          client: ClientSpec.budgetWorker,
          stats: stats90,
          philosophy: TravelPhilosophy.midnight,
        );
        expect(report90.satisfaction, inInclusiveRange(85, 95));

        final stats30 = createStats(cost: 1000, hype: 200, theme: 30);
        final report30 = ClientReviewEngine.evaluate(
          client: ClientSpec.budgetWorker,
          stats: stats30,
          philosophy: TravelPhilosophy.midnight,
        );
        final drop = report90.satisfaction - report30.satisfaction;
        expect(drop, greaterThanOrEqualTo(20));
      });

      test('AC-A1-1.7 網紅參考行程：Theme 90 得分 85~95，Theme 降至 30 時降幅 >= 20', () {
        // 固定參考輸入：hype 150 (= targetHype), 滿絕景 (1.0x), 無疲勞
        final stats90 = createStats(
          hype: 150,
          theme: 90,
          hasSpotlight: true,
          spotlightCount: 4,
          fatiguePairs: const {},
        );
        final report90 = ClientReviewEngine.evaluate(
          client: ClientSpec.hypeInfluencer,
          stats: stats90,
          philosophy: TravelPhilosophy.midnight,
        );
        expect(report90.satisfaction, inInclusiveRange(85, 95));

        final stats30 = createStats(
          hype: 150,
          theme: 30,
          hasSpotlight: true,
          spotlightCount: 4,
          fatiguePairs: const {},
        );
        final report30 = ClientReviewEngine.evaluate(
          client: ClientSpec.hypeInfluencer,
          stats: stats30,
          philosophy: TravelPhilosophy.midnight,
        );
        final drop = report90.satisfaction - report30.satisfaction;
        expect(drop, greaterThanOrEqualTo(20));
      });

      test('AC-A1-1.8 同一素材、同一客戶，僅換哲學使審查結果跨越至少一個評級', () {
        const materials = [
          TravelMaterial(
            id: 'x0',
            name: 'x0',
            tags: ['#深夜', '#小酌', '#散步'],
            themeValue: 45,
            hypeValue: 40,
            cost: 100,
            riskLevel: 1,
          ),
          TravelMaterial(
            id: 'x1',
            name: 'x1',
            tags: ['#深夜', '#小酌', '#散步'],
            themeValue: 45,
            hypeValue: 40,
            cost: 100,
            riskLevel: 1,
          ),
          TravelMaterial(
            id: 'x2',
            name: 'x2',
            tags: ['#深夜', '#小酌', '#散步'],
            themeValue: 45,
            hypeValue: 40,
            cost: 100,
            riskLevel: 1,
          ),
          TravelMaterial(
            id: 'x3',
            name: 'x3',
            tags: ['#深夜', '#小酌', '#散步'],
            themeValue: 45,
            hypeValue: 40,
            cost: 100,
            riskLevel: 1,
          ),
        ];

        final itinerary = TimelineItinerary(slots: materials);

        // 哲學 A: midnight (命中 #深夜、#小酌，高 Theme)
        final statsMidnight = itinerary.calculateStats(
          philosophy: TravelPhilosophy.midnight,
          cameraMultiplier: 1.0,
        );
        final reportMidnight = ClientReviewEngine.evaluate(
          client: ClientSpec.budgetWorker,
          stats: statsMidnight,
          philosophy: TravelPhilosophy.midnight,
        );

        // 哲學 B: chaos (排斥 #散步，極低 Theme)
        final statsChaos = itinerary.calculateStats(
          philosophy: TravelPhilosophy.chaos,
          cameraMultiplier: 1.0,
        );
        final reportChaos = ClientReviewEngine.evaluate(
          client: ClientSpec.budgetWorker,
          stats: statsChaos,
          philosophy: TravelPhilosophy.chaos,
        );

        expect(reportMidnight.outcome, isNot(equals(reportChaos.outcome)));
      });
    });


    group('AC-A1-6 網紅疲勞、連段、絕景階梯與純度 (T4)', () {
      test('AC-A1-6.1 絕景係數單調遞增，0 張時 >= 0.7，任兩相鄰張數增幅 <= 0.15', () {
        final ladder = ClientReviewEngine.spotlightLadder;
        expect(ladder.length, equals(5));
        expect(ladder[0], greaterThanOrEqualTo(0.70));
        expect(ladder[4], equals(1.00));
        for (var i = 1; i < ladder.length; i++) {
          expect(ladder[i], greaterThan(ladder[i - 1]), reason: '單調遞增');
          expect(ladder[i] - ladder[i - 1], lessThanOrEqualTo(0.150001), reason: '相鄰增幅 <= 0.15');
        }
      });

      test('AC-A1-6.3a 對 targetHype = 150 且混亂以外哲學，一組拉車疲勞扣除 Hype >= 20', () {
        const client = ClientSpec.hypeInfluencer;
        expect(client.targetHype, equals(150));

        final statsZeroFatigue = createStats(
          cost: 0,
          hype: 120,
          theme: 80,
          hasSpotlight: true,
          spotlightCount: 1,
          fatiguePairs: {},
        );

        final statsOneFatigue = createStats(
          cost: 0,
          hype: 120,
          theme: 80,
          hasSpotlight: true,
          spotlightCount: 1,
          fatiguePairs: {0},
        );

        for (final phil in TravelPhilosophy.values) {
          if (phil == TravelPhilosophy.chaos) continue;
          final reportZero = ClientReviewEngine.evaluate(
            client: client,
            stats: statsZeroFatigue,
            philosophy: phil,
          );
          final reportOne = ClientReviewEngine.evaluate(
            client: client,
            stats: statsOneFatigue,
            philosophy: phil,
          );

          final netHypeZero = reportZero.subscores['netHype'] as int;
          final netHypeOne = reportOne.subscores['netHype'] as int;
          final diff = netHypeZero - netHypeOne;
          expect(diff, greaterThanOrEqualTo(20), reason: '${phil.displayName} 扣除 Hype 必須 >= 20');
        }
      });

      test('AC-A1-6.3b 對混亂以外哲學，新增一組疲勞損失不得小於 totalHype +20 之增益', () {
        const client = ClientSpec.hypeInfluencer;

        final statsBase = createStats(
          cost: 0,
          hype: 120,
          theme: 70,
          hasSpotlight: true,
          spotlightCount: 1,
          fatiguePairs: {},
        );

        final statsPlus20 = createStats(
          cost: 0,
          hype: 140,
          theme: 70,
          hasSpotlight: true,
          spotlightCount: 1,
          fatiguePairs: {},
        );

        final statsFatigue = createStats(
          cost: 0,
          hype: 120,
          theme: 70,
          hasSpotlight: true,
          spotlightCount: 1,
          fatiguePairs: {0},
        );


        for (final phil in TravelPhilosophy.values) {
          if (phil == TravelPhilosophy.chaos) continue;
          final reportBase = ClientReviewEngine.evaluate(
            client: client,
            stats: statsBase,
            philosophy: phil,
          );
          final reportPlus20 = ClientReviewEngine.evaluate(
            client: client,
            stats: statsPlus20,
            philosophy: phil,
          );
          final reportFatigue = ClientReviewEngine.evaluate(
            client: client,
            stats: statsFatigue,
            philosophy: phil,
          );

          final gain = reportPlus20.satisfaction - reportBase.satisfaction;
          final loss = reportBase.satisfaction - reportFatigue.satisfaction;
          expect(loss, greaterThanOrEqualTo(gain), reason: '${phil.displayName} 疲勞損失 ($loss) 不得小於 +20 Hype 增益 ($gain)');
        }
      });

      test('AC-A1-6.6 同一行程在混亂冒險與其他哲學下，相鄰高風險在 Hype 側效果相反，Theme 側一律為負', () {
        final statsWithFatigue = createStats(
          cost: 0,
          hype: 100,
          theme: 60, // 疲勞扣除 10 點
          hasSpotlight: true,
          spotlightCount: 1,
          fatiguePairs: {0}, // 1 組相鄰高風險對
        );

        // 混亂冒險：Hype 側為冒險連段加成 (netHype > totalHype)
        final reportChaos = ClientReviewEngine.evaluate(
          client: ClientSpec.hypeInfluencer,
          stats: statsWithFatigue,
          philosophy: TravelPhilosophy.chaos,
        );
        final netHypeChaos = reportChaos.subscores['netHype'] as int;
        expect(netHypeChaos, greaterThan(100), reason: '混亂冒險 Hype 側必須反向加成');

        // 其他哲學：Hype 側為疲勞懲罰 (netHype < totalHype)
        for (final phil in TravelPhilosophy.values) {
          if (phil == TravelPhilosophy.chaos) continue;
          final reportOther = ClientReviewEngine.evaluate(
            client: ClientSpec.hypeInfluencer,
            stats: statsWithFatigue,
            philosophy: phil,
          );
          final netHypeOther = reportOther.subscores['netHype'] as int;
          expect(netHypeOther, lessThan(100), reason: '${phil.displayName} Hype 側必須扣除疲勞');
        }
      });
    });

    group('Amendment-01: 比例超支與反無聊測試 (AC-A1-2)', () {
      test('AC-A1-2.1 對 budgetWorker 存在四槽組合使滿意度落入 Rejected', () {
        final all = kyotoNightMaterials;
        final m1 = all.firstWhere((m) => m.id == 'kyoto_gion_kappo'); // cost 5000
        final m2 = all.firstWhere((m) => m.id == 'kyoto_sagano_torokko'); // cost 2000
        final m3 = all.firstWhere((m) => m.id == 'kyoto_kurama_night_train'); // cost 1000
        final m4 = all.firstWhere((m) => m.id == 'kyoto_yasaka_pagoda'); // cost 400

        final itinerary = TimelineItinerary(slots: [m1, m2, m3, m4]);
        final stats = itinerary.calculateStats(
          philosophy: TravelPhilosophy.slow,
          cameraMultiplier: 1.5,
        );

        final report = ClientReviewEngine.evaluate(
          client: ClientSpec.budgetWorker,
          stats: stats,
          philosophy: TravelPhilosophy.slow,
        );

        expect(report.outcome, equals(ReviewOutcome.rejected));
        expect(report.satisfaction, lessThan(60));
      });

      test('AC-A1-2.2 對 budgetWorker 存在四槽組合使滿意度落入 Perfect', () {
        final all = kyotoNightMaterials;
        final m1 = all.firstWhere((m) => m.id == 'kyoto_pontocho_cat');
        final m2 = all.firstWhere((m) => m.id == 'kyoto_ghost_vending');
        final m3 = all.firstWhere((m) => m.id == 'kyoto_gion_tatsumi');
        final m4 = all.firstWhere((m) => m.id == 'kyoto_fushimi_torii');

        final itinerary = TimelineItinerary(slots: [m1, m2, m3, m4]);
        final stats = itinerary.calculateStats(
          philosophy: TravelPhilosophy.midnight,
          cameraMultiplier: 1.5,
        );

        final report = ClientReviewEngine.evaluate(
          client: ClientSpec.budgetWorker,
          stats: stats,
          philosophy: TravelPhilosophy.midnight,
        );

        expect(report.outcome, equals(ReviewOutcome.perfect));
        expect(report.satisfaction, greaterThanOrEqualTo(90));
      });

      test('AC-A1-2.3 在 Theme 滿分下，Perfect 超支上界與 Rejected 超支下界差 >= 預算 30%，且滿意度單調不增', () {
        const client = ClientSpec.budgetWorker;
        final themeScore = (client.themeWeight * 100 / 100).round(); // 56
        expect(themeScore, equals(56));

        // 逐百分點 (0% ~ 200%) 測試超支比例
        var prevSat = 100;
        double? maxROverspendPerfect;
        double? minROverspendRejected;

        for (var pct = 0; pct <= 200; pct++) {
          final overspendRatio = pct / 100.0;
          final totalCost = (client.targetBudget * (1.0 + overspendRatio)).round();

          final stats = createStats(
            cost: totalCost,
            theme: 100,
            hype: 300, // 高 Hype 不觸發反無聊
          );

          final report = ClientReviewEngine.evaluate(
            client: client,
            stats: stats,
            philosophy: TravelPhilosophy.slow,
          );

          // 驗證滿意度對超支比例單調不增
          expect(
            report.satisfaction,
            lessThanOrEqualTo(prevSat),
            reason: '超支比例 $pct% 之滿意度 (${report.satisfaction}) 必須 <= 前一比例滿意度 ($prevSat)',
          );
          prevSat = report.satisfaction;

          if (report.outcome == ReviewOutcome.perfect) {
            maxROverspendPerfect = overspendRatio;
          }
          if (report.outcome == ReviewOutcome.rejected && minROverspendRejected == null) {
            minROverspendRejected = overspendRatio;
          }
        }

        expect(maxROverspendPerfect, isNotNull);
        expect(minROverspendRejected, isNotNull);
        final boundDiff = minROverspendRejected! - maxROverspendPerfect!;
        expect(
          boundDiff,
          greaterThanOrEqualTo(0.30),
          reason: 'Perfect 上界 ($maxROverspendPerfect) 與 Rejected 下界 ($minROverspendRejected) 差值 ($boundDiff) 必須 >= 30%',
        );
      });

      test('AC-A1-2.4 對 budgetWorker 存在四槽組合觸發反無聊懲罰且總成本低於預算', () {
        final all = kyotoNightMaterials;
        // 尋找總成本 <= 2000 且觸發反無聊 (totalHype < boredomThreshold) 的四槽組合
        final cheapLowHype = all.where((m) => m.cost <= 500 && m.hypeValue <= 35).toList();
        expect(cheapLowHype.length, greaterThanOrEqualTo(4));

        ReviewReport? boredReport;
        for (var i = 0; i < cheapLowHype.length; i++) {
          for (var j = 0; j < cheapLowHype.length; j++) {
            if (j == i) continue;
            for (var k = 0; k < cheapLowHype.length; k++) {
              if (k == i || k == j) continue;
              for (var l = 0; l < cheapLowHype.length; l++) {
                if (l == i || l == j || l == k) continue;
                final itin = TimelineItinerary(
                  slots: [cheapLowHype[i], cheapLowHype[j], cheapLowHype[k], cheapLowHype[l]],
                );
                final stats = itin.calculateStats(
                  philosophy: TravelPhilosophy.slow,
                  cameraMultiplier: 1.5,
                );
                if (stats.totalCost <= ClientSpec.budgetWorker.targetBudget) {
                  final rep = ClientReviewEngine.evaluate(
                    client: ClientSpec.budgetWorker,
                    stats: stats,
                    philosophy: TravelPhilosophy.slow,
                  );
                  if ((rep.subscores['boredomPenalty'] as int? ?? 0) > 0) {
                    boredReport = rep;
                    break;
                  }
                }
              }
              if (boredReport != null) break;
            }
            if (boredReport != null) break;
          }
          if (boredReport != null) break;
        }

        expect(boredReport, isNotNull, reason: '必須存在總成本低於預算但因無聊受罰的四槽組合');
        expect(boredReport!.subscores['boredomPenalty'], equals(25));
        expect(boredReport.subscores['totalCost'], lessThanOrEqualTo(ClientSpec.budgetWorker.targetBudget));
      });
    });
  });
}
