import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
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
      hasSpotlight: hasSpotlight,
    );

    test('AC-ML-5.1 社畜滿分 (Perfect): 花費 <= 2000, Theme >= 60, Hype >= 30', () {
      final stats = createStats(cost: 1800, theme: 80, hype: 45, story: 4);
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

      // Budget 70 + Theme 30 - Boredom 25 = 75
      expect(report.satisfaction, 75);
      expect(report.outcome, ReviewOutcome.pass); // 降為 Pass，無法 Perfect
    });

    test(
      'AC-ML-5.3 社畜 Near Miss: 超支 160 円 (扣 32 分), Theme 60 得 30 分 -> 滿意度 68 分',
      () {
        final stats = createStats(cost: 2160, theme: 60, hype: 35, story: 4);
        final report = ClientReviewEngine.evaluate(
          client: ClientSpec.budgetWorker,
          stats: stats,
        );

        // BudgetScore: 70 - (160 / 10 * 2) = 70 - 32 = 38
        // ThemeScore: 30
        // Boredom: 0
        // Total: 38 + 30 = 68
        expect(report.satisfaction, 68);
        expect(report.outcome, ReviewOutcome.nearMiss);
        expect(
          report.earnedCoins,
          (1000 * 0.3).round() + (4 * 5),
        ); // 300 + 20 = 320
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
      expect(report.earnedCoins, 2000 * 1.5 + (5 * 5)); // 3000 + 25 = 3025
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
        (2000 * 0.3).round() + (3 * 5),
      ); // 600 + 15 = 615
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
      // ThemeFactor: 0.7 + 0.3 * (20 / 100) = 0.76
      // Satisfaction: (90 / 150 * 100 * 0.76).round() = 46
      expect(report.satisfaction, 46);
      expect(report.outcome, ReviewOutcome.rejected);
      expect(report.earnedCoins, 0 + (2 * 5)); // 0 佣金 + 10 故事幣
    });
  });
}
