import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/shutter/shutter_params.dart';

TravelMaterial card({
  required String id,
  required int hypeValue,
  bool isSpotlight = false,
  ShotTier shotTier = ShotTier.normal,
  int cost = 0,
}) => TravelMaterial(
  id: id,
  name: id,
  tags: const [],
  themeValue: 30,
  hypeValue: hypeValue,
  isSpotlight: isSpotlight,
  cost: cost,
  shotTier: shotTier,
);

void main() {
  group('回歸：difficulty/interruptionDiscount 預設值下與既有呼叫結果全等', () {
    test('全 normal 態行程，帶新參數與不帶新參數結果一致', () {
      final it = TimelineItinerary(
        slots: [
          card(id: 'a', hypeValue: 40, cost: 200),
          card(id: 'b', hypeValue: 50, cost: 300),
          card(id: 'c', hypeValue: 30, cost: 100),
          null,
        ],
      );
      final stats = it.calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.0,
      );
      final withDefaults = ClientReviewEngine.evaluate(
        client: ClientSpec.budgetWorker,
        stats: stats,
        philosophy: TravelPhilosophy.midnight,
      );
      final explicit = ClientReviewEngine.evaluate(
        client: ClientSpec.budgetWorker,
        stats: stats,
        philosophy: TravelPhilosophy.midnight,
        difficulty: ShutterDifficulty.tourist,
        interruptionDiscount: 1.0,
      );
      // 第一層完全不動
      expect(explicit.satisfaction, withDefaults.satisfaction);
      expect(explicit.outcome, withDefaults.outcome);
      // 全 normal 態時 tierFactor 恆 1.00，L2 分數不因難度改變
      expect(explicit.l2Score, withDefaults.l2Score);
    });
  });

  group('reach / valueIndex 公式正確性（手算比對）', () {
    test('網紅 reach：一張絕景 perfect + 三張非絕景 normal，decisiveMoment', () {
      // 四槽全滿、皆為契合哲學高熱度卡，避免行程被判 rejected 觸發
      // 額外的 30% 退件折扣，讓這條測試只驗公式本身。
      final it = TimelineItinerary(
        slots: [
          card(id: 'spot', hypeValue: 80, isSpotlight: true, shotTier: ShotTier.perfect),
          card(id: 'plain1', hypeValue: 70, shotTier: ShotTier.normal),
          card(id: 'plain2', hypeValue: 65, shotTier: ShotTier.normal),
          card(id: 'plain3', hypeValue: 60, shotTier: ShotTier.normal),
        ],
      );
      final stats = it.calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.5,
      );
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.hypeInfluencer,
        stats: stats,
        philosophy: TravelPhilosophy.midnight,
        difficulty: ShutterDifficulty.decisiveMoment,
      );
      expect(
        report.outcome,
        isNot(ReviewOutcome.rejected),
        reason: '本測試只驗公式，退件的 30% 折扣由另一條測試專責驗證',
      );

      final fPerfectSpot = tierFactorFor(
        ShutterDifficulty.decisiveMoment,
        ShotTier.perfect,
        isSpotlight: true,
      );
      final raw = 80 * fPerfectSpot + 70 * 1.00 + 65 * 1.00 + 60 * 1.00;
      // spotlightCount=1 → ladder[1]=0.75
      final expectedReach = (raw * 0.75).round();
      expect(report.l2Score, expectedReach);
      expect(report.l2Coins, (expectedReach * 0.36).round());
    });

    test('社畜 valueIndex：CP 地板 2000 生效（總成本 < 2000）', () {
      final it = TimelineItinerary(
        slots: [
          card(id: 'a', hypeValue: 60, cost: 300, shotTier: ShotTier.perfect),
          card(id: 'b', hypeValue: 40, cost: 200, shotTier: ShotTier.normal),
          card(id: 'c', hypeValue: 45, cost: 150, shotTier: ShotTier.normal),
          card(id: 'd', hypeValue: 35, cost: 100, shotTier: ShotTier.normal),
        ],
      );
      final stats = it.calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.0,
      );
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.budgetWorker,
        stats: stats,
        philosophy: TravelPhilosophy.midnight,
        difficulty: ShutterDifficulty.photographer,
      );
      expect(
        report.outcome,
        isNot(ReviewOutcome.rejected),
        reason: '本測試只驗公式，退件的 30% 折扣由另一條測試專責驗證',
      );

      final fPerfect = tierFactorFor(
        ShutterDifficulty.photographer,
        ShotTier.perfect,
        isSpotlight: false,
      );
      final raw = 60 * fPerfect + 40 * 1.00 + 45 * 1.00 + 35 * 1.00;
      // 總成本 750 < 地板 2000 → 分母用 2000
      final expectedValueIndex = (raw / 2000 * 1000).round();
      expect(report.l2Score, expectedValueIndex);
    });
  });

  group('中斷折扣', () {
    test('interruptionDiscount 乘進 l2Coins', () {
      final it = TimelineItinerary(
        slots: [
          card(id: 'a', hypeValue: 60, shotTier: ShotTier.perfect),
          card(id: 'b', hypeValue: 55, shotTier: ShotTier.normal),
          card(id: 'c', hypeValue: 50, shotTier: ShotTier.normal),
          card(id: 'd', hypeValue: 45, shotTier: ShotTier.normal),
        ],
      );
      final stats = it.calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.0,
      );
      final full = ClientReviewEngine.evaluate(
        client: ClientSpec.hypeInfluencer,
        stats: stats,
        philosophy: TravelPhilosophy.midnight,
        difficulty: ShutterDifficulty.tourist,
      );
      final discounted = ClientReviewEngine.evaluate(
        client: ClientSpec.hypeInfluencer,
        stats: stats,
        philosophy: TravelPhilosophy.midnight,
        difficulty: ShutterDifficulty.tourist,
        interruptionDiscount: 0.9,
      );
      expect(full.outcome, isNot(ReviewOutcome.rejected));
      // l2Score（reach 本身）不受折扣影響，只有折成金幣時才打折
      expect(discounted.l2Score, full.l2Score);
      expect(discounted.l2Coins, (full.l2Score * 0.36 * 0.9).round());
    });
  });

  group('退件局 L2 金幣為 30%', () {
    test('rejected 局的 l2Coins 是 non-rejected 的 30%', () {
      // 建構一個必然 rejected 的社畜行程：極端超支 + 極低熱度
      final it = TimelineItinerary(
        slots: [
          card(id: 'a', hypeValue: 5, cost: 5000, shotTier: ShotTier.perfect),
          null,
          null,
          null,
        ],
      );
      final stats = it.calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.0,
      );
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.budgetWorker,
        stats: stats,
        philosophy: TravelPhilosophy.midnight,
        difficulty: ShutterDifficulty.tourist,
      );
      expect(report.outcome, ReviewOutcome.rejected);

      final fPerfect = tierFactorFor(
        ShutterDifficulty.tourist,
        ShotTier.perfect,
        isSpotlight: false,
      );
      final raw = 5 * fPerfect;
      final valueIndex = (raw / 2000 * 1000).round();
      final fullCoins = (valueIndex * 0.36).round();
      final expectedRejectedCoins = (fullCoins * 0.30).round();
      expect(report.l2Coins, expectedRejectedCoins);
    });
  });

  group('AC-M5-5.8: L2 金幣硬性上界（32 張全池最壞情況）', () {
    test('4 絕景全 perfect，decisiveMoment，reach 上界 619.5，c=0.36 得 223 ≤ 225', () {
      final it = TimelineItinerary(
        slots: [
          card(id: 's1', hypeValue: 80, isSpotlight: true, shotTier: ShotTier.perfect),
          card(id: 's2', hypeValue: 80, isSpotlight: true, shotTier: ShotTier.perfect),
          card(id: 's3', hypeValue: 75, isSpotlight: true, shotTier: ShotTier.perfect),
          card(id: 's4', hypeValue: 70, isSpotlight: true, shotTier: ShotTier.perfect),
        ],
      );
      final stats = it.calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.0,
      );
      final report = ClientReviewEngine.evaluate(
        client: ClientSpec.hypeInfluencer,
        stats: stats,
        philosophy: TravelPhilosophy.midnight,
        difficulty: ShutterDifficulty.decisiveMoment,
      );
      expect(report.l2Score, 619);
      expect(report.l2Coins, lessThanOrEqualTo(225));
      expect(report.l2Coins, 223);
    });
  });
}
