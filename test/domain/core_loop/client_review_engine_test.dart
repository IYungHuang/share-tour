import 'package:flutter_test/flutter_test.dart';
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
      spotlightCount: hasSpotlight ? 1 : 0,
      themeBaseline: 50,
      themeBeforeFatigue: theme,
      purityActive: false,
      hasSpotlight: hasSpotlight,
    );

    test('AC-ML-5.1 社畜滿分 (Perfect): 花費 <= 2000, Theme >= 60, Hype >= 30', () {
      final stats = createStats(cost: 1800, theme: 90, hype: 45, story: 4);
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.budgetWorker,
        stats: stats,
      );

      expect(report.outcome, ReviewOutcome.perfect);
      expect(report.satisfaction, greaterThanOrEqualTo(90));
      expect(report.earnedCoins, 1000 * 1.5 + (4 * 5)); // 1500 + 20 = 1520
    });

    test('AC-ML-5.2 社畜反無聊打擊: 0 花費但 Hype < 30，扣 25 分無法達成 Perfect', () {
      final stats = createStats(cost: 0, theme: 70, hype: 15, story: 4);
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.budgetWorker,
        stats: stats,
      );

      // Budget 44 + Theme 39 - Boredom 25 = 58
      expect(report.satisfaction, 58);
      expect(report.outcome, ReviewOutcome.rejected); // 降為 Rejected，無法 Perfect
    });

    test(
      'AC-ML-5.3 社畜超支扣分: 超支 160 円 (扣 32 分), Theme 60 得 34 分 -> 滿意度 46 分',
      () {
        final stats = createStats(cost: 2160, theme: 60, hype: 35, story: 4);
        final report = ClientReviewEngine.evaluate(
          client: ClientSpec.budgetWorker,
          stats: stats,
        );

        // BudgetScore: 44 - (160 / 10 * 2) = 44 - 32 = 12
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
        hype: 160,
        hasSpotlight: true,
        theme: 100,
        fatiguePairs: const {},
        story: 5,
      );
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.hypeInfluencer,
        stats: stats,
      );

      expect(report.outcome, ReviewOutcome.perfect);
      expect(report.satisfaction, greaterThanOrEqualTo(90));
      expect(report.earnedCoins, 1500 * 1.5 + (5 * 5)); // 2250 + 25 = 2275
    });

    test('AC-ML-5.5 網紅無絕景打五折 Near Miss: Hype 200 無絕景打五折得 67 分', () {
      final stats = createStats(
        hype: 200,
        hasSpotlight: false, // 無絕景
        theme: 100,
        fatiguePairs: const {},
        story: 3,
      );
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.hypeInfluencer,
        stats: stats,
      );

      // EffectiveHype: 200 * 0.5 = 100
      // ThemeFactor: 0.7 + 0.3 * (100 / 100) = 1.0
      // Satisfaction: (100 / 150 * 100 * 1.0).round() = 67
      expect(report.satisfaction, 67);
      expect(report.outcome, ReviewOutcome.nearMiss);
      expect(
        report.earnedCoins,
        (1500 * 0.3).round() + (3 * 5),
      ); // 450 + 15 = 465
    });

    test('AC-ML-5.6 網紅疲勞脫妝退件 (Rejected): 疲勞扣 30 Hype，Theme 20 導致滿意度 46 分', () {
      final stats = createStats(
        hype: 120,
        hasSpotlight: true,
        theme: 20,
        fatiguePairs: const {0, 2}, // 2 次疲勞
        story: 2,
      );
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.hypeInfluencer,
        stats: stats,
      );

      // Fatigue: 120 - (2 * 15) = 90
      // Spotlight: 90 * 1.0 = 90
      // ThemeFactor: (44 + 56 * (20 / 100)) / 100 = 0.552
      // Satisfaction: (90 / 150 * 100 * 0.552).round() = 33
      expect(report.satisfaction, 33);
      expect(report.outcome, ReviewOutcome.rejected);
      expect(report.earnedCoins, 0 + (2 * 5)); // 0 佣金 + 10 故事幣
    });

    group('AC-A1-1.7 & AC-A1-1.8 Theme 傳導到兩位客戶滿意度 (T3)', () {
      test('AC-A1-1.7 社畜參考行程：Theme 90 得分 85~95，Theme 降至 30 時降幅 >= 20', () {
        // 固定參考輸入：未超支 (cost 1000 <= 2000), 無聊不觸發 (hype 50 >= 30)
        final stats90 = createStats(cost: 1000, hype: 50, theme: 90);
        final report90 = ClientReviewEngine.evaluate(
          client: ClientSpec.budgetWorker,
          stats: stats90,
        );
        expect(report90.satisfaction, inInclusiveRange(85, 95));

        final stats30 = createStats(cost: 1000, hype: 50, theme: 30);
        final report30 = ClientReviewEngine.evaluate(
          client: ClientSpec.budgetWorker,
          stats: stats30,
        );
        final drop = report90.satisfaction - report30.satisfaction;
        expect(drop, greaterThanOrEqualTo(20));
      });

      test('AC-A1-1.7 網紅參考行程：Theme 90 得分 85~95，Theme 降至 30 時降幅 >= 20', () {
        // 固定參考輸入：hype 150 (= targetHype), 具絕景, 無疲勞
        final stats90 = createStats(
          hype: 150,
          theme: 90,
          hasSpotlight: true,
          fatiguePairs: const {},
        );
        final report90 = ClientReviewEngine.evaluate(
          client: ClientSpec.hypeInfluencer,
          stats: stats90,
        );
        expect(report90.satisfaction, inInclusiveRange(85, 95));

        final stats30 = createStats(
          hype: 150,
          theme: 30,
          hasSpotlight: true,
          fatiguePairs: const {},
        );
        final report30 = ClientReviewEngine.evaluate(
          client: ClientSpec.hypeInfluencer,
          stats: stats30,
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
        );

        // 哲學 B: chaos (排斥 #散步，極低 Theme)
        final statsChaos = itinerary.calculateStats(
          philosophy: TravelPhilosophy.chaos,
          cameraMultiplier: 1.0,
        );
        final reportChaos = ClientReviewEngine.evaluate(
          client: ClientSpec.budgetWorker,
          stats: statsChaos,
        );

        expect(reportMidnight.outcome, isNot(equals(reportChaos.outcome)));
      });
    });
  });
}
