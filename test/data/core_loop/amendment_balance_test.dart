import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';

import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';

void main() {
  group('京都全卡表平衡收斂測試 (AC-A1-6, AC-A1-3.6)', () {
    test(
      'AC-A1-3.6 固定 hypeInfluencer，對五種哲學逐一以全卡表中 riskLevel >= 3 的全部素材為候選域，窮舉合法 3 槽與 4 槽行程；3 槽的全域最佳滿意度不得高於 4 槽的全域最佳滿意度',
      () {
        final highRiskMaterials =
            kyotoNightMaterials.where((m) => m.riskLevel >= 3).toList();
        final n = highRiskMaterials.length;

        for (final phil in TravelPhilosophy.values) {
          var maxSat3 = -1;
          // 3-slot: [0, 1, 2, null] & [null, 0, 1, 2]
          for (var i = 0; i < n; i++) {
            final m0 = highRiskMaterials[i];
            for (var j = 0; j < n; j++) {
              if (j == i) continue;
              final m1 = highRiskMaterials[j];
              for (var k = 0; k < n; k++) {
                if (k == i || k == j) continue;
                final m2 = highRiskMaterials[k];

                for (final slots in [
                  [m0, m1, m2, null],
                  [null, m0, m1, m2],
                ]) {
                  final it = TimelineItinerary(slots: slots);
                  final stats = it.calculateStats(
                    philosophy: phil,
                    cameraMultiplier: 1.5,
                  );
                  final report = ClientReviewEngine.evaluate(
                    client: ClientSpec.hypeInfluencer,
                    stats: stats,
                    philosophy: phil,
                  );
                  if (report.satisfaction > maxSat3) {
                    maxSat3 = report.satisfaction;
                  }
                }
              }
            }
          }

          var maxSat4 = -1;
          // 4-slot
          for (var i = 0; i < n; i++) {
            final m0 = highRiskMaterials[i];
            for (var j = 0; j < n; j++) {
              if (j == i) continue;
              final m1 = highRiskMaterials[j];
              for (var k = 0; k < n; k++) {
                if (k == i || k == j) continue;
                final m2 = highRiskMaterials[k];
                for (var l = 0; l < n; l++) {
                  if (l == i || l == j || l == k) continue;
                  final m3 = highRiskMaterials[l];

                  final it = TimelineItinerary(slots: [m0, m1, m2, m3]);
                  final stats = it.calculateStats(
                    philosophy: phil,
                    cameraMultiplier: 1.5,
                  );
                  final report = ClientReviewEngine.evaluate(
                    client: ClientSpec.hypeInfluencer,
                    stats: stats,
                    philosophy: phil,
                  );
                  if (report.satisfaction > maxSat4) {
                    maxSat4 = report.satisfaction;
                  }
                }
              }
            }
          }

          expect(
            maxSat3,
            lessThanOrEqualTo(maxSat4),
            reason: '$phil 下 3 槽最佳滿意度 ($maxSat3) 不得高於 4 槽最佳滿意度 ($maxSat4)',
          );
        }
      },
    );

    test(
      'AC-A1-6.8a 在網紅客戶下，對五種哲學分別以全卡表全部素材窮舉合法 3/4 槽行程，母體合計 4,612,800，五哲學最佳滿意度相差 <= 15 分且至少 2 種達 Perfect (>= 90)',
      () {
        final materials = kyotoNightMaterials;
        final n = materials.length;
        var totalItinerariesTested = 0;
        final bestSats = <int>[];

        for (final phil in TravelPhilosophy.values) {
          var philTested = 0;
          var maxSat = -1;

          // 4-slot: 32 * 31 * 30 * 29 = 863,040
          for (var i = 0; i < n; i++) {
            final m0 = materials[i];
            for (var j = 0; j < n; j++) {
              if (j == i) continue;
              final m1 = materials[j];
              for (var k = 0; k < n; k++) {
                if (k == i || k == j) continue;
                final m2 = materials[k];
                for (var l = 0; l < n; l++) {
                  if (l == i || l == j || l == k) continue;
                  final m3 = materials[l];
                  philTested++;

                  final it = TimelineItinerary(slots: [m0, m1, m2, m3]);
                  final stats = it.calculateStats(
                    philosophy: phil,
                    cameraMultiplier: 1.5,
                  );
                  final report = ClientReviewEngine.evaluate(
                    client: ClientSpec.hypeInfluencer,
                    stats: stats,
                    philosophy: phil,
                  );
                  if (report.satisfaction > maxSat) {
                    maxSat = report.satisfaction;
                  }
                }
              }
            }
          }

          // 3-slot: 2 * (32 * 31 * 30) = 59,520
          for (var i = 0; i < n; i++) {
            final m0 = materials[i];
            for (var j = 0; j < n; j++) {
              if (j == i) continue;
              final m1 = materials[j];
              for (var k = 0; k < n; k++) {
                if (k == i || k == j) continue;
                final m2 = materials[k];

                // [0, 1, 2, null]
                philTested++;
                {
                  final it = TimelineItinerary(slots: [m0, m1, m2, null]);
                  final stats = it.calculateStats(
                    philosophy: phil,
                    cameraMultiplier: 1.5,
                  );
                  final report = ClientReviewEngine.evaluate(
                    client: ClientSpec.hypeInfluencer,
                    stats: stats,
                    philosophy: phil,
                  );
                  if (report.satisfaction > maxSat) {
                    maxSat = report.satisfaction;
                  }
                }

                // [null, 0, 1, 2]
                philTested++;
                {
                  final it = TimelineItinerary(slots: [null, m0, m1, m2]);
                  final stats = it.calculateStats(
                    philosophy: phil,
                    cameraMultiplier: 1.5,
                  );
                  final report = ClientReviewEngine.evaluate(
                    client: ClientSpec.hypeInfluencer,
                    stats: stats,
                    philosophy: phil,
                  );
                  if (report.satisfaction > maxSat) {
                    maxSat = report.satisfaction;
                  }
                }
              }
            }
          }

          expect(
            philTested,
            equals(922560),
            reason: '$phil 合法行程母體必須剛好為 922,560 (不得先依偏好或排斥過濾)',
          );
          totalItinerariesTested += philTested;
          bestSats.add(maxSat);
        }

        expect(
          totalItinerariesTested,
          equals(4612800),
          reason: '五哲學合法行程母體總和必須剛好為 4,612,800',
        );

        final minSat = bestSats.reduce((a, b) => a < b ? a : b);
        final maxSat = bestSats.reduce((a, b) => a > b ? a : b);
        expect(
          maxSat - minSat,
          lessThanOrEqualTo(15),
          reason: '五哲學最佳滿意度極差不得超過 15 分 (min: $minSat, max: $maxSat)',
        );

        final perfectCount = bestSats.where((s) => s >= 90).length;
        expect(
          perfectCount,
          greaterThanOrEqualTo(2),
          reason: '五哲學中至少須有 2 種達到 Perfect (>= 90) 評價 (實際: $perfectCount)',
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
    test('AC-A1-6.7 混亂冒險的最佳四張熱度組合，在網紅客戶下可達 Pass 或以上 (驗全部最高 totalHype 平手四槽解)', () {
      final materials = kyotoNightMaterials;
      final n = materials.length;
      var maxHype = -1;
      final bestItineraries = <TimelineItinerary>[];

      // 枚舉全部 4 槽行程尋找最高 totalHype
      for (var i = 0; i < n; i++) {
        final m0 = materials[i];
        for (var j = 0; j < n; j++) {
          if (j == i) continue;
          final m1 = materials[j];
          for (var k = 0; k < n; k++) {
            if (k == i || k == j) continue;
            final m2 = materials[k];
            for (var l = 0; l < n; l++) {
              if (l == i || l == j || l == k) continue;
              final m3 = materials[l];

              final it = TimelineItinerary(slots: [m0, m1, m2, m3]);
              final stats = it.calculateStats(
                philosophy: TravelPhilosophy.chaos,
                cameraMultiplier: 1.5,
              );

              if (stats.totalHype > maxHype) {
                maxHype = stats.totalHype;
                bestItineraries.clear();
                bestItineraries.add(it);
              } else if (stats.totalHype == maxHype) {
                bestItineraries.add(it);
              }
            }
          }
        }
      }

      expect(bestItineraries, isNotEmpty);

      // 全部最高 totalHype 平手四槽解，在網紅客戶下均須達到 Pass (satisfaction >= 70) 或以上
      for (final it in bestItineraries) {
        final stats = it.calculateStats(
          philosophy: TravelPhilosophy.chaos,
          cameraMultiplier: 1.5,
        );
        final report = ClientReviewEngine.evaluate(
          client: ClientSpec.hypeInfluencer,
          stats: stats,
          philosophy: TravelPhilosophy.chaos,
        );

        expect(
          report.satisfaction,
          greaterThanOrEqualTo(70),
          reason: '混亂冒險最佳熱度解 (Hype: $maxHype) 滿意度為 ${report.satisfaction}，必須 >= 70 (Pass)',
        );
        expect(
          report.outcome.index,
          lessThanOrEqualTo(ReviewOutcome.pass.index),
        );
      }
    });

    test('AC-A1-6.9 對混亂冒險，以全卡表窮舉所有至少含 1 組相鄰高風險對的合法 3/4 槽行程，finalTheme 恆等於 clamp(themeBeforeFatigue - 10 * pairs, 0, 100)', () {
      final materials = kyotoNightMaterials;
      final n = materials.length;

      var testedCount = 0;

      void checkItinerary(TimelineItinerary it) {
        final stats = it.calculateStats(
          philosophy: TravelPhilosophy.chaos,
          cameraMultiplier: 1.5,
        );

        if (stats.fatiguePairs.isNotEmpty) {
          testedCount++;
          final expectedTheme =
              (stats.themeBeforeFatigue - 10 * stats.fatiguePairs.length)
                  .clamp(0, 100);
          expect(
            stats.finalTheme,
            equals(expectedTheme),
            reason: '冒險連段只能改變 Hype 側，不得減免、反轉或重複計入 Theme 側疲勞',
          );
        }
      }

      // 4-slot
      for (var i = 0; i < n; i++) {
        final m0 = materials[i];
        for (var j = 0; j < n; j++) {
          if (j == i) continue;
          final m1 = materials[j];
          for (var k = 0; k < n; k++) {
            if (k == i || k == j) continue;
            final m2 = materials[k];
            for (var l = 0; l < n; l++) {
              if (l == i || l == j || l == k) continue;
              final m3 = materials[l];
              checkItinerary(TimelineItinerary(slots: [m0, m1, m2, m3]));
            }
          }
        }
      }

      // 3-slot
      for (var i = 0; i < n; i++) {
        final m0 = materials[i];
        for (var j = 0; j < n; j++) {
          if (j == i) continue;
          final m1 = materials[j];
          for (var k = 0; k < n; k++) {
            if (k == i || k == j) continue;
            final m2 = materials[k];
            checkItinerary(TimelineItinerary(slots: [m0, m1, m2, null]));
            checkItinerary(TimelineItinerary(slots: [null, m0, m1, m2]));
          }
        }
      }

      expect(testedCount, greaterThan(0), reason: '必須驗證至少一個包含疲勞對的行程');
    });
  });
}
