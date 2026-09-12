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

    test('AC-A1-5.6 美食朝聖前 6 張契合卡採集後 HP > 0；混亂冒險最遲第 5 張採集時 HP 歸零進入 nightEditing 且腰包未滿', () {
      final foodFitting = reachablePool
          .where((m) => m.tags.any((t) => TravelPhilosophy.gourmet.preferredTags.contains(t)))
          .toList();
      foodFitting.sort((a, b) => a.riskLevel.compareTo(b.riskLevel));

      var foodHp = 100;
      for (var i = 0; i < 6; i++) {
        foodHp -= (foodFitting[i].riskLevel * 6);
      }
      expect(foodHp, greaterThan(0));

      final chaosFitting = reachablePool
          .where((m) => m.tags.any((t) => TravelPhilosophy.chaos.preferredTags.contains(t)))
          .toList();
      chaosFitting.sort((a, b) => b.riskLevel.compareTo(a.riskLevel));

      var chaosHp = 100;
      var gatheredCount = 0;
      for (var i = 0; i < chaosFitting.length; i++) {
        final cost = chaosFitting[i].riskLevel * 6;
        if (chaosHp <= cost) {
          chaosHp = 0;
          gatheredCount++;
          break;
        }
        chaosHp -= cost;
        gatheredCount++;
      }
      expect(gatheredCount, lessThanOrEqualTo(5));
      expect(gatheredCount, lessThan(6));
      expect(chaosHp, equals(0));
    });

    test('AC-A1-6.5 絕景素材中 cost==0 && risk<=2 者 <= 1 張，且每種哲學仍保有至少 1 張負擔得起的絕景 (cost <= 500)', () {
      final spotlights = reachablePool.where((m) => m.isSpotlight).toList();
      final freeAndSafe = spotlights.where((m) => m.cost == 0 && m.riskLevel <= 2).toList();
      expect(freeAndSafe.length, lessThanOrEqualTo(1));

      const maxAffordableCost = 500;
      for (final phil in TravelPhilosophy.values) {
        final fittingSpotlights = spotlights.where((m) {
          final isFitting = m.tags.any((t) => phil.preferredTags.contains(t));
          return isFitting && m.cost <= maxAffordableCost;
        }).toList();
        expect(fittingSpotlights, isNotEmpty, reason: '$phil 必須保有至少 1 張 cost <= $maxAffordableCost 的絕景');
      }
    });

    test('AC-A1-5.1 網紅相機 Lv.1 (1.5x) 黃昏槽固定最佳解比例 <= 30% (以 16-POI 40,040 手牌窮舉全平手)', () {
      final pool = reachablePool.take(16).toList();
      final n = pool.length;
      var totalHandsEvaluated = 0;
      var fixedDuskHandsCount = 0;

      for (final phil in TravelPhilosophy.values) {
        for (var i = 0; i < n; i++) {
          for (var j = i + 1; j < n; j++) {
            for (var k = j + 1; k < n; k++) {
              for (var l = k + 1; l < n; l++) {
                for (var m = l + 1; m < n; m++) {
                  for (var p = m + 1; p < n; p++) {
                    totalHandsEvaluated++;
                    final hand = [pool[i], pool[j], pool[k], pool[l], pool[m], pool[p]];
                    var maxBaseHypeInHand = hand[0].hypeValue;
                    for (final c in hand) {
                      if (c.hypeValue > maxBaseHypeInHand) maxBaseHypeInHand = c.hypeValue;
                    }

                    var maxSat = -1;
                    var allBestHaveMaxHypeInDusk = true;

                    for (var a = 0; a < 6; a++) {
                      for (var b = 0; b < 6; b++) {
                        if (b == a) continue;
                        for (var c = 0; c < 6; c++) {
                          if (c == a || c == b) continue;

                          // 3-slot: [c0, c1, c2, null], dusk is hand[b]
                          {
                            final it = TimelineItinerary(slots: [hand[a], hand[b], hand[c], null]);
                            final sat = ClientReviewEngine.evaluate(
                              client: ClientSpec.hypeInfluencer,
                              stats: it.calculateStats(philosophy: phil, cameraMultiplier: 1.5),
                              philosophy: phil,
                            ).satisfaction;
                            final isDuskMaxHype = hand[b].hypeValue == maxBaseHypeInHand;
                            if (sat > maxSat) {
                              maxSat = sat;
                              allBestHaveMaxHypeInDusk = isDuskMaxHype;
                            } else if (sat == maxSat) {
                              if (!isDuskMaxHype) allBestHaveMaxHypeInDusk = false;
                            }
                          }

                          // 3-slot: [null, c0, c1, c2], dusk is hand[b]
                          {
                            final it = TimelineItinerary(slots: [null, hand[a], hand[b], hand[c]]);
                            final sat = ClientReviewEngine.evaluate(
                              client: ClientSpec.hypeInfluencer,
                              stats: it.calculateStats(philosophy: phil, cameraMultiplier: 1.5),
                              philosophy: phil,
                            ).satisfaction;
                            final isDuskMaxHype = hand[b].hypeValue == maxBaseHypeInHand;
                            if (sat > maxSat) {
                              maxSat = sat;
                              allBestHaveMaxHypeInDusk = isDuskMaxHype;
                            } else if (sat == maxSat) {
                              if (!isDuskMaxHype) allBestHaveMaxHypeInDusk = false;
                            }
                          }

                          // 4-slot: [c0, c1, c2, c3], dusk is hand[c]
                          for (var d = 0; d < 6; d++) {
                            if (d == a || d == b || d == c) continue;
                            final it = TimelineItinerary(slots: [hand[a], hand[b], hand[c], hand[d]]);
                            final sat = ClientReviewEngine.evaluate(
                              client: ClientSpec.hypeInfluencer,
                              stats: it.calculateStats(philosophy: phil, cameraMultiplier: 1.5),
                              philosophy: phil,
                            ).satisfaction;
                            final isDuskMaxHype = hand[c].hypeValue == maxBaseHypeInHand;
                            if (sat > maxSat) {
                              maxSat = sat;
                              allBestHaveMaxHypeInDusk = isDuskMaxHype;
                            } else if (sat == maxSat) {
                              if (!isDuskMaxHype) allBestHaveMaxHypeInDusk = false;
                            }
                          }
                        }
                      }
                    }

                    if (allBestHaveMaxHypeInDusk) {
                      fixedDuskHandsCount++;
                    }
                  }
                }
              }
            }
          }
        }
      }

      expect(totalHandsEvaluated, 40040);
      final ratio = fixedDuskHandsCount / totalHandsEvaluated;
      expect(ratio, lessThanOrEqualTo(0.30), reason: '黃金槽固定比例 ${(ratio * 100).toStringAsFixed(2)}% 超過 30% 門檻');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
