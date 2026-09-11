import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';

void main() {
  group('京都最終可達素材池契約與聯合收口驗證 (Commit 13, T11)', () {
    late final List<TravelMaterial> reachablePool;

    setUpAll(() {
      const manifest = KyotoNightMapManifest();
      const resolver = KyotoPoiMaterialResolver();

      // 由正式 Kyoto manifest districtAttractions 經正式 resolver 導出可達池 (禁止手抄池)
      reachablePool = manifest.districtAttractions
          .map((a) => resolver.resolveMaterialFor(a.id)!)
          .toList();
    });

    test('AC-A1-4.4 可達 POI 數量 >= 16 且景點 ID 與素材 ID 一對一完全吻合', () {
      expect(reachablePool.length, greaterThanOrEqualTo(16));
      expect(reachablePool.length, 32);

      final ids = reachablePool.map((m) => m.id).toSet();
      expect(ids.length, equals(reachablePool.length));
    });

    test('AC-A1-0.1 每一種旅行哲學的每一個偏好標籤，素材承載數 >= 2', () {
      for (final phil in TravelPhilosophy.values) {
        for (final tag in phil.preferredTags) {
          final count = reachablePool.where((m) => m.tags.contains(tag)).length;
          expect(
            count,
            greaterThanOrEqualTo(2),
            reason: '${phil.name} 偏好標籤 $tag 在可達池中僅有 $count 張 (需 >= 2)',
          );
        }
      }
    });

    test('AC-A1-0.2 每一種旅行哲學的排斥標籤聯集，素材承載數 >= 4', () {
      for (final phil in TravelPhilosophy.values) {
        final count = reachablePool
            .where((m) => m.tags.any((t) => phil.repelledTags.contains(t)))
            .length;
        expect(
          count,
          greaterThanOrEqualTo(4),
          reason: '${phil.name} 排斥標籤聯集在可達池中僅涵蓋 $count 張 (需 >= 4)',
        );
      }
    });

    test('AC-A1-0.3 素材池標籤集合 100% 涵蓋五大哲學的所有偏好與排斥標籤', () {
      final poolTags = reachablePool.expand((m) => m.tags).toSet();
      for (final phil in TravelPhilosophy.values) {
        for (final tag in [...phil.preferredTags, ...phil.repelledTags]) {
          expect(poolTags.contains(tag), isTrue, reason: '可達池遺漏標籤 $tag');
        }
      }
    });

    test('AC-A1-0.4 (回歸護欄) 僅帶未使用標籤的卡片數 <= 全池的 1/3 (實測為 0 張)', () {
      final allPhilTags = TravelPhilosophy.values
          .expand((p) => [...p.preferredTags, ...p.repelledTags])
          .toSet();

      final unusedOnlyCards = reachablePool.where(
        (m) => !m.tags.any((t) => allPhilTags.contains(t)),
      ).toList();

      expect(unusedOnlyCards.length, 0);
      expect(unusedOnlyCards.length, lessThanOrEqualTo(reachablePool.length ~/ 3));
    });

    test('AC-A1-4.5 可達 POI 涵蓋全部 5 種旅行哲學的每一個偏好標籤，行前抽牌無死牌', () {
      final poolTags = reachablePool.expand((m) => m.tags).toSet();
      for (final phil in TravelPhilosophy.values) {
        for (final tag in phil.preferredTags) {
          expect(poolTags.contains(tag), isTrue);
        }
      }
    });

    test('AC-A1-4.6 每一種旅行哲學的契合卡集至少含 1 張 isSpotlight 素材', () {
      for (final phil in TravelPhilosophy.values) {
        final fittingSpotlights = reachablePool.where((m) {
          final isPreferred = m.tags.any((t) => phil.preferredTags.contains(t));
          final isRepelled = m.tags.any((t) => phil.repelledTags.contains(t));
          return isPreferred && !isRepelled && m.isSpotlight;
        }).toList();

        expect(
          fittingSpotlights,
          isNotEmpty,
          reason: '哲學 ${phil.name} 的契合卡集中無任何 isSpotlight 素材',
        );
      }
    });

    test('AC-A1-2.5 在社畜客戶下，母體 4,612,800 行程之四級評判皆有且 Perfect <= 15%', () {
      var perfectCount = 0;
      var passCount = 0;
      var nearMissCount = 0;
      var rejectedCount = 0;

      final n = reachablePool.length;
      for (final phil in TravelPhilosophy.values) {
        // 3-slot
        for (var i = 0; i < n; i++) {
          final m0 = reachablePool[i];
          for (var j = 0; j < n; j++) {
            if (j == i) continue;
            final m1 = reachablePool[j];
            for (var k = 0; k < n; k++) {
              if (k == i || k == j) continue;
              final m2 = reachablePool[k];

              for (final slots in [
                [m0, m1, m2, null],
                [null, m0, m1, m2],
              ]) {
                final it = TimelineItinerary(slots: slots);
                final report = ClientReviewEngine.evaluate(
                  client: ClientSpec.budgetWorker,
                  stats: it.calculateStats(philosophy: phil, cameraMultiplier: 1.5),
                  philosophy: phil,
                );
                switch (report.outcome) {
                  case ReviewOutcome.perfect:
                    perfectCount++;
                  case ReviewOutcome.pass:
                    passCount++;
                  case ReviewOutcome.nearMiss:
                    nearMissCount++;
                  case ReviewOutcome.rejected:
                    rejectedCount++;
                }
              }
            }
          }
        }

        // 4-slot
        for (var i = 0; i < n; i++) {
          final m0 = reachablePool[i];
          for (var j = 0; j < n; j++) {
            if (j == i) continue;
            final m1 = reachablePool[j];
            for (var k = 0; k < n; k++) {
              if (k == i || k == j) continue;
              final m2 = reachablePool[k];
              for (var l = 0; l < n; l++) {
                if (l == i || l == j || l == k) continue;
                final m3 = reachablePool[l];

                final it = TimelineItinerary(slots: [m0, m1, m2, m3]);
                final report = ClientReviewEngine.evaluate(
                  client: ClientSpec.budgetWorker,
                  stats: it.calculateStats(philosophy: phil, cameraMultiplier: 1.5),
                  philosophy: phil,
                );
                switch (report.outcome) {
                  case ReviewOutcome.perfect:
                    perfectCount++;
                  case ReviewOutcome.pass:
                    passCount++;
                  case ReviewOutcome.nearMiss:
                    nearMissCount++;
                  case ReviewOutcome.rejected:
                    rejectedCount++;
                }
              }
            }
          }
        }
      }

      final total = perfectCount + passCount + nearMissCount + rejectedCount;
      expect(total, equals(4612800));
      expect(perfectCount, greaterThan(0));
      expect(passCount, greaterThan(0));
      expect(nearMissCount, greaterThan(0));
      expect(rejectedCount, greaterThan(0));

      final perfectRatio = perfectCount / total;
      expect(perfectRatio, lessThanOrEqualTo(0.15));
      expect(perfectRatio, closeTo(0.0632, 0.005));
    });

    test('AC-A1-5.4 社畜 Pass 收入中位數對應三件套升至滿級總價需 6..10 局 (命中 8 局)', () {
      final passCoinsHist = List<int>.filled(10000, 0);
      var passCount = 0;
      final n = reachablePool.length;

      for (final phil in TravelPhilosophy.values) {
        for (var i = 0; i < n; i++) {
          final m0 = reachablePool[i];
          for (var j = 0; j < n; j++) {
            if (j == i) continue;
            final m1 = reachablePool[j];
            for (var k = 0; k < n; k++) {
              if (k == i || k == j) continue;
              final m2 = reachablePool[k];

              for (final slots in [
                [m0, m1, m2, null],
                [null, m0, m1, m2],
              ]) {
                final it = TimelineItinerary(slots: slots);
                final report = ClientReviewEngine.evaluate(
                  client: ClientSpec.budgetWorker,
                  stats: it.calculateStats(philosophy: phil, cameraMultiplier: 1.5),
                  philosophy: phil,
                );
                if (report.outcome == ReviewOutcome.pass) {
                  passCount++;
                  passCoinsHist[report.earnedCoins]++;
                }
              }

              for (var l = 0; l < n; l++) {
                if (l == i || l == j || l == k) continue;
                final m3 = reachablePool[l];
                final it = TimelineItinerary(slots: [m0, m1, m2, m3]);
                final report = ClientReviewEngine.evaluate(
                  client: ClientSpec.budgetWorker,
                  stats: it.calculateStats(philosophy: phil, cameraMultiplier: 1.5),
                  philosophy: phil,
                );
                if (report.outcome == ReviewOutcome.pass) {
                  passCount++;
                  passCoinsHist[report.earnedCoins]++;
                }
              }
            }
          }
        }
      }

      final half = passCount ~/ 2;
      var accumulated = 0;
      double passMedian = 0;
      int? firstMid;

      for (var c = 0; c < passCoinsHist.length; c++) {
        final count = passCoinsHist[c];
        if (count == 0) continue;
        accumulated += count;

        if (firstMid == null && accumulated >= half) {
          firstMid = c;
        }
        if (accumulated >= half + 1) {
          passMedian = (firstMid! + c) / 2.0;
          break;
        }
      }

      expect(passMedian, 1070.0);

      // 三件裝備自 Lv.1 升至 Lv.3 的總價
      final item = EquipmentItem(type: EquipmentType.sneakers, level: 1);
      final cost12 = item.nextUpgradeCost!;
      final cost23 = item.copyWith(level: 2).nextUpgradeCost!;
      final totalUpgradeCost = 3 * (cost12 + cost23);

      final runsToMax = (totalUpgradeCost / passMedian).ceil();
      expect(runsToMax, inInclusiveRange(6, 10));
      expect(runsToMax, equals(8));
    });

    test('AC-A1-6.4 兩位客戶 Rejected 最高收入 <= Near Miss 最低收入 x 30%，且集合非空', () {
      var bwMinNearMissCoins = 999999;
      var bwMaxRejectedCoins = 0;
      var hiMinNearMissCoins = 999999;
      var hiMaxRejectedCoins = 0;

      final n = reachablePool.length;

      for (final phil in TravelPhilosophy.values) {
        for (var i = 0; i < n; i++) {
          final m0 = reachablePool[i];
          for (var j = 0; j < n; j++) {
            if (j == i) continue;
            final m1 = reachablePool[j];
            for (var k = 0; k < n; k++) {
              if (k == i || k == j) continue;
              final m2 = reachablePool[k];

              for (final slots in [
                [m0, m1, m2, null],
                [null, m0, m1, m2],
              ]) {
                final it = TimelineItinerary(slots: slots);
                final stats = it.calculateStats(philosophy: phil, cameraMultiplier: 1.5);

                final rBw = ClientReviewEngine.evaluate(
                  client: ClientSpec.budgetWorker,
                  stats: stats,
                  philosophy: phil,
                );
                if (rBw.outcome == ReviewOutcome.nearMiss && rBw.earnedCoins < bwMinNearMissCoins) {
                  bwMinNearMissCoins = rBw.earnedCoins;
                } else if (rBw.outcome == ReviewOutcome.rejected && rBw.earnedCoins > bwMaxRejectedCoins) {
                  bwMaxRejectedCoins = rBw.earnedCoins;
                }

                final rHi = ClientReviewEngine.evaluate(
                  client: ClientSpec.hypeInfluencer,
                  stats: stats,
                  philosophy: phil,
                );
                if (rHi.outcome == ReviewOutcome.nearMiss && rHi.earnedCoins < hiMinNearMissCoins) {
                  hiMinNearMissCoins = rHi.earnedCoins;
                } else if (rHi.outcome == ReviewOutcome.rejected && rHi.earnedCoins > hiMaxRejectedCoins) {
                  hiMaxRejectedCoins = rHi.earnedCoins;
                }
              }

              for (var l = 0; l < n; l++) {
                if (l == i || l == j || l == k) continue;
                final m3 = reachablePool[l];
                final it = TimelineItinerary(slots: [m0, m1, m2, m3]);
                final stats = it.calculateStats(philosophy: phil, cameraMultiplier: 1.5);

                final rBw = ClientReviewEngine.evaluate(
                  client: ClientSpec.budgetWorker,
                  stats: stats,
                  philosophy: phil,
                );
                if (rBw.outcome == ReviewOutcome.nearMiss && rBw.earnedCoins < bwMinNearMissCoins) {
                  bwMinNearMissCoins = rBw.earnedCoins;
                } else if (rBw.outcome == ReviewOutcome.rejected && rBw.earnedCoins > bwMaxRejectedCoins) {
                  bwMaxRejectedCoins = rBw.earnedCoins;
                }

                final rHi = ClientReviewEngine.evaluate(
                  client: ClientSpec.hypeInfluencer,
                  stats: stats,
                  philosophy: phil,
                );
                if (rHi.outcome == ReviewOutcome.nearMiss && rHi.earnedCoins < hiMinNearMissCoins) {
                  hiMinNearMissCoins = rHi.earnedCoins;
                } else if (rHi.outcome == ReviewOutcome.rejected && rHi.earnedCoins > hiMaxRejectedCoins) {
                  hiMaxRejectedCoins = rHi.earnedCoins;
                }
              }
            }
          }
        }
      }

      expect(bwMinNearMissCoins, isPositive);
      expect(bwMaxRejectedCoins, isPositive);
      expect(hiMinNearMissCoins, isPositive);
      expect(hiMaxRejectedCoins, isPositive);

      expect(bwMaxRejectedCoins, lessThanOrEqualTo((bwMinNearMissCoins * 0.30).floor()));
      expect(hiMaxRejectedCoins, lessThanOrEqualTo((hiMinNearMissCoins * 0.30).floor()));
    });

    test('AC-A1-6.8b 當局可達素材池下，五哲學在網紅客戶之最佳滿意度相差 <= 15 且至少 2 種達 Perfect (>= 90)', () {
      final bestSatisfactions = <TravelPhilosophy, int>{};
      final n = reachablePool.length;

      for (final phil in TravelPhilosophy.values) {
        var maxSat = -1;
        // 3-slot
        for (var i = 0; i < n; i++) {
          final m0 = reachablePool[i];
          for (var j = 0; j < n; j++) {
            if (j == i) continue;
            final m1 = reachablePool[j];
            for (var k = 0; k < n; k++) {
              if (k == i || k == j) continue;
              final m2 = reachablePool[k];

              for (final slots in [
                [m0, m1, m2, null],
                [null, m0, m1, m2],
              ]) {
                final it = TimelineItinerary(slots: slots);
                final sat = ClientReviewEngine.evaluate(
                  client: ClientSpec.hypeInfluencer,
                  stats: it.calculateStats(philosophy: phil, cameraMultiplier: 1.5),
                  philosophy: phil,
                ).satisfaction;
                if (sat > maxSat) maxSat = sat;
              }

              for (var l = 0; l < n; l++) {
                if (l == i || l == j || l == k) continue;
                final m3 = reachablePool[l];
                final it = TimelineItinerary(slots: [m0, m1, m2, m3]);
                final sat = ClientReviewEngine.evaluate(
                  client: ClientSpec.hypeInfluencer,
                  stats: it.calculateStats(philosophy: phil, cameraMultiplier: 1.5),
                  philosophy: phil,
                ).satisfaction;
                if (sat > maxSat) maxSat = sat;
              }
            }
          }
        }
        bestSatisfactions[phil] = maxSat;
      }

      final values = bestSatisfactions.values.toList();
      final minSat = values.reduce((a, b) => a < b ? a : b);
      final maxSat = values.reduce((a, b) => a > b ? a : b);

      expect(maxSat - minSat, lessThanOrEqualTo(15));
      final perfectCount = values.where((s) => s >= 90).length;
      expect(perfectCount, greaterThanOrEqualTo(2));
    });
  });
}
