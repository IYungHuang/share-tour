import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';

import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';

void main() {
  group('京都全卡表平衡收斂測試 (AC-A1-6)', () {
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
