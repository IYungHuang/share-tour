import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';

void main() {
  group('4 槽位時間線行程表與擊穿流水線測試 (AC-ML-4)', () {
    TravelMaterial createMaterial({
      required String id,
      required String name,
      List<String> tags = const ['#常規'],
      int theme = 10,
      int hype = 20,
      int cost = 100,
      int risk = 1,
      int story = 1,
      bool isSpotlight = false,
    }) => TravelMaterial(
      id: id,
      name: name,
      tags: tags,
      themeValue: theme,
      hypeValue: hype,
      cost: cost,
      riskLevel: risk,
      storyValue: story,
      isSpotlight: isSpotlight,
    );

    test('AC-ML-4.1 未滿 4 槽位時 canSubmit 為 false，填滿 4 槽位時為 true', () {
      final empty = TimelineItinerary.empty();
      expect(empty.canSubmit, isFalse);

      final partial = empty
          .setSlot(0, createMaterial(id: 'm1', name: '晨曦'))
          .setSlot(1, createMaterial(id: 'm2', name: '午後'));
      expect(partial.canSubmit, isFalse);

      final full = partial
          .setSlot(2, createMaterial(id: 'm3', name: '黃昏'))
          .setSlot(3, createMaterial(id: 'm4', name: '深夜'));
      expect(full.canSubmit, isTrue);
    });

    test('AC-ML-4.2 Slot 2 (黃昏槽位) 素材基礎 Hype 享有 cameraMultiplier (1.5x)', () {
      final itinerary = TimelineItinerary.empty().setSlot(
        2,
        createMaterial(id: 'm_sunset', name: '黃昏絕景', hype: 30),
      );

      final stats = itinerary.calculateStats(
        philosophy: TravelPhilosophy.slow,
        cameraMultiplier: 1.5,
      );

      // Slot 2 Hype: 30 * 1.5 = 45
      expect(stats.slotEffectiveHypes[2], 45);
      expect(stats.totalHype, 45);
    });

    test('AC-ML-4.3 相鄰槽位具備相同標籤時，後者 Hype 享有 20% Combo 加成 (獨立 round)', () {
      final itinerary = TimelineItinerary.empty()
          .setSlot(
            0,
            createMaterial(id: 'm0', name: '鴨川散步', tags: ['#散步'], hype: 20),
          )
          .setSlot(
            1,
            createMaterial(id: 'm1', name: '哲學之道散步', tags: ['#散步'], hype: 35),
          );

      final stats = itinerary.calculateStats(
        philosophy: TravelPhilosophy.slow,
        cameraMultiplier: 1.5,
      );

      // Slot 1 與 Slot 0 皆有 #散步 -> Slot 1 Hype: (35 * 1.2).round() = 42
      expect(stats.slotEffectiveHypes[0], 20);
      expect(stats.slotEffectiveHypes[1], 42);
      expect(stats.comboActiveSlots.contains(1), isTrue);
    });

    test('AC-ML-4.4 相鄰兩槽位 riskLevel 皆 >= 3 時觸發拉車疲勞，Theme 扣除 10 點', () {
      final itinerary = TimelineItinerary.empty()
          .setSlot(
            0,
            createMaterial(id: 'm0', name: '高空飛索', tags: ['#高風險'], risk: 4),
          )
          .setSlot(
            1,
            createMaterial(id: 'm1', name: '夜間深山鬼屋', tags: ['#高風險'], risk: 3),
          );

      final stats = itinerary.calculateStats(
        philosophy: TravelPhilosophy.chaos,
        cameraMultiplier: 1.5,
      );

      expect(stats.fatiguePairs.length, 1);
      // themeBaseline = 50 + ((4 + 4) / 2).round() = 54
      // themeBeforeFatigue = 54
      // finalTheme = 54 - fatigue(10) = 44
      expect(stats.themeBaseline, 54);
      expect(stats.themeBeforeFatigue, 54);
      expect(stats.finalTheme, 44);
    });

    test(
      'AC-ML-4.5 Slot 0 放入帶有 #散步 且 risk <= 2 素材，Theme 額外 +5；risk >= 3 不給分',
      () {
        final validMorning = TimelineItinerary.empty().setSlot(
          0,
          createMaterial(
            id: 'm0',
            name: '清晨鴨川散步',
            tags: ['#散步'],
            risk: 1,
            theme: 0,
          ),
        );
        final statsValid = validMorning.calculateStats(
          philosophy: TravelPhilosophy.slow,
          cameraMultiplier: 1.5,
        );
        expect(statsValid.slotThemeBonuses[0], 5);
        expect(statsValid.finalTheme, 55); // 50 + 5

        final riskyMorning = TimelineItinerary.empty().setSlot(
          0,
          createMaterial(
            id: 'm0_risk',
            name: '清晨懸崖攀岩',
            tags: ['#散步'],
            risk: 3,
            theme: 0,
          ),
        );
        final statsRisky = riskyMorning.calculateStats(
          philosophy: TravelPhilosophy.slow,
          cameraMultiplier: 1.5,
        );
        expect(statsRisky.slotThemeBonuses.containsKey(0), isFalse);
        expect(statsRisky.finalTheme, 50); // 無額外 5 分
      },
    );

    test('AC-ML-4.6 Slot 1 放入帶有 #美食 且 risk <= 2 素材，Theme 獲得額外 5 點午後中繼加分', () {
      final validNoon = TimelineItinerary.empty().setSlot(
        1,
        createMaterial(
          id: 'm1',
          name: '午間蕎麥麵',
          tags: ['#美食'],
          risk: 1,
          theme: 0,
        ),
      );
      final stats = validNoon.calculateStats(
        philosophy: TravelPhilosophy.slow,
        cameraMultiplier: 1.5,
      );
      expect(stats.slotThemeBonuses[1], 5);
      expect(stats.finalTheme, 55); // 50 + 5
    });

    test('完整 4 槽位綜合計算流水線與擊穿資訊自洽', () {
      final fullItinerary = TimelineItinerary.empty()
          .setSlot(
            0,
            createMaterial(
              id: 'm0',
              name: '晨散步',
              tags: ['#散步', '#老街'],
              risk: 1,
              theme: 10,
              hype: 10,
              cost: 100,
            ),
          )
          .setSlot(
            1,
            createMaterial(
              id: 'm1',
              name: '午餐老街食堂',
              tags: ['#老街', '#美食'],
              risk: 2,
              theme: 10,
              hype: 20,
              cost: 500,
            ),
          )
          .setSlot(
            2,
            createMaterial(
              id: 'm2',
              name: '黃昏神木絕景',
              tags: ['#老街', '#絕景'],
              risk: 3,
              theme: 20,
              hype: 40,
              cost: 300,
              isSpotlight: true,
            ),
          )
          .setSlot(
            3,
            createMaterial(
              id: 'm3',
              name: '深夜居酒屋',
              tags: ['#深夜', '#小酌'],
              risk: 3,
              theme: 10,
              hype: 30,
              cost: 1000,
            ),
          );

      final stats = fullItinerary.calculateStats(
        philosophy: TravelPhilosophy.slow, // 偏好 #老街 (+50%)
        cameraMultiplier: 1.5,
      );

      expect(stats.totalCost, 1900); // 100 + 500 + 300 + 1000
      expect(stats.canSubmit, isTrue);

      // Slot 0 Hype: 10
      // Slot 1 Hype: (20 * 1.2 Combo with #老街).round() = 24
      // Slot 2 Hype: (40 * 1.5 * 1.2 Combo with #老街).round() = 72
      // Slot 3 Hype: 30 (無共鳴)
      // Total Hype: 10 + 24 + 72 + 30 = 136
      expect(stats.slotEffectiveHypes, [10, 24, 72, 30]);
      expect(stats.totalHype, 136);

      // 拉車疲勞：(2, 3) 兩者 risk 皆為 3 -> 疲勞 1 次扣 10 點
      expect(stats.fatiguePairs, {2});
    });

    group('AC-A1-1 主題契合度分級、正規化與疲勞計算 (T2)', () {
      test('AC-A1-1.1 四槽皆為中性素材時，契合度基準分等於 50', () {
        final itinerary = TimelineItinerary(slots: [
          createMaterial(id: 'n0', name: '中性0', tags: ['#日常'], risk: 1, theme: 20),
          createMaterial(id: 'n1', name: '中性1', tags: ['#日常'], risk: 1, theme: 20),
          createMaterial(id: 'n2', name: '中性2', tags: ['#日常'], risk: 1, theme: 20),
          createMaterial(id: 'n3', name: '中性3', tags: ['#日常'], risk: 1, theme: 20),
        ]);

        for (final philosophy in TravelPhilosophy.values) {
          final stats = itinerary.calculateStats(
            philosophy: philosophy,
            cameraMultiplier: 1.0,
          );
          expect(stats.themeBaseline, equals(50));
          expect(stats.finalTheme, equals(50));
        }
      });

      test('AC-A1-1.2 命中 >=2 偏好標籤基準分介於 88 與 92，僅命中 1 標籤基準分 <= 75', () {
        // 2 標籤命中 (midnight: #深夜, #小酌)
        final twoHit = TimelineItinerary(slots: [
          createMaterial(id: 'm0', name: '雙中0', tags: ['#深夜', '#小酌'], risk: 1, theme: 45),
          createMaterial(id: 'm1', name: '雙中1', tags: ['#深夜', '#小酌'], risk: 1, theme: 45),
          createMaterial(id: 'm2', name: '雙中2', tags: ['#深夜', '#小酌'], risk: 1, theme: 45),
          createMaterial(id: 'm3', name: '雙中3', tags: ['#深夜', '#小酌'], risk: 1, theme: 45),
        ]);
        final statsTwo = twoHit.calculateStats(
          philosophy: TravelPhilosophy.midnight,
          cameraMultiplier: 1.0,
        );
        expect(statsTwo.themeBaseline, inInclusiveRange(88, 92));

        // 3 標籤命中 (gourmet: #美食, #銅板美食, #早餐)
        final threeHit = TimelineItinerary(slots: [
          createMaterial(id: 'g0', name: '三中0', tags: ['#美食', '#銅板美食', '#早餐'], risk: 1, theme: 45),
          createMaterial(id: 'g1', name: '三中1', tags: ['#美食', '#銅板美食', '#早餐'], risk: 1, theme: 45),
          createMaterial(id: 'g2', name: '三中2', tags: ['#美食', '#銅板美食', '#早餐'], risk: 1, theme: 45),
          createMaterial(id: 'g3', name: '三中3', tags: ['#美食', '#銅板美食', '#早餐'], risk: 1, theme: 45),
        ]);
        final statsThree = threeHit.calculateStats(
          philosophy: TravelPhilosophy.gourmet,
          cameraMultiplier: 1.0,
        );
        expect(statsThree.themeBaseline, inInclusiveRange(88, 92));

        // 1 標籤命中 (midnight: 僅 #深夜)
        final oneHit = TimelineItinerary(slots: [
          createMaterial(id: 'o0', name: '單中0', tags: ['#深夜'], risk: 1, theme: 45),
          createMaterial(id: 'o1', name: '單中1', tags: ['#深夜'], risk: 1, theme: 45),
          createMaterial(id: 'o2', name: '單中2', tags: ['#深夜'], risk: 1, theme: 45),
          createMaterial(id: 'o3', name: '單中3', tags: ['#深夜'], risk: 1, theme: 45),
        ]);
        final statsOne = oneHit.calculateStats(
          philosophy: TravelPhilosophy.midnight,
          cameraMultiplier: 1.0,
        );
        expect(statsOne.themeBaseline, lessThanOrEqualTo(75));
      });

      test('AC-A1-1.3 對每一種旅行哲學，均存在四槽全排斥使基準分 <= 20', () {
        for (final philosophy in TravelPhilosophy.values) {
          final repelledTag = philosophy.repelledTags.first;
          final allRepelled = TimelineItinerary(slots: [
            createMaterial(id: 'r0', name: '排斥0', tags: [repelledTag], risk: 1, theme: 45),
            createMaterial(id: 'r1', name: '排斥1', tags: [repelledTag], risk: 1, theme: 45),
            createMaterial(id: 'r2', name: '排斥2', tags: [repelledTag], risk: 1, theme: 45),
            createMaterial(id: 'r3', name: '排斥3', tags: [repelledTag], risk: 1, theme: 45),
          ]);
          final stats = allRepelled.calculateStats(
            philosophy: philosophy,
            cameraMultiplier: 1.0,
          );
          expect(
            stats.themeBaseline,
            lessThanOrEqualTo(20),
            reason: '${philosophy.displayName} 全排斥組合基準分需 <= 20',
          );
        }
      });

      test('AC-A1-1.4 存在一組素材與兩種哲學，使其契合度基準分相差 >= 25', () {
        // 同一組素材帶有 #深夜 與 #散步
        // midnight 偏好 #深夜 (+40) -> baseline 90
        // chaos 排斥 #散步 (-32) -> baseline 18
        final itinerary = TimelineItinerary(slots: [
          createMaterial(id: 'x0', name: '複合0', tags: ['#深夜', '#小酌', '#散步'], risk: 1, theme: 45),
          createMaterial(id: 'x1', name: '複合1', tags: ['#深夜', '#小酌', '#散步'], risk: 1, theme: 45),
          createMaterial(id: 'x2', name: '複合2', tags: ['#深夜', '#小酌', '#散步'], risk: 1, theme: 45),
          createMaterial(id: 'x3', name: '複合3', tags: ['#深夜', '#小酌', '#散步'], risk: 1, theme: 45),
        ]);

        final statsMidnight = itinerary.calculateStats(
          philosophy: TravelPhilosophy.midnight,
          cameraMultiplier: 1.0,
        );
        final statsChaos = itinerary.calculateStats(
          philosophy: TravelPhilosophy.chaos,
          cameraMultiplier: 1.0,
        );

        final diff = (statsMidnight.themeBaseline - statsChaos.themeBaseline).abs();
        expect(diff, greaterThanOrEqualTo(25));
      });

      test('AC-A1-1.5 對每一種旅行哲學，恰有 1 組相鄰高風險對且疲勞前 Theme 在 40~80 時，finalTheme 等於疲勞前 Theme - 10', () {
        for (final philosophy in TravelPhilosophy.values) {
          // 中性卡，基準 50，無時段加成
          // 槽位 1 與 2 為高風險 (risk 3)，其餘 risk 1 -> 恰好 1 組疲勞 (1, 2)
          final itinerary = TimelineItinerary(slots: [
            createMaterial(id: 'f0', name: '低0', tags: ['#常規'], risk: 1, theme: 10),
            createMaterial(id: 'f1', name: '高1', tags: ['#常規'], risk: 3, theme: 10),
            createMaterial(id: 'f2', name: '高2', tags: ['#常規'], risk: 3, theme: 10),
            createMaterial(id: 'f3', name: '低3', tags: ['#常規'], risk: 1, theme: 10),
          ]);

          final stats = itinerary.calculateStats(
            philosophy: philosophy,
            cameraMultiplier: 1.0,
          );

          expect(stats.fatiguePairs.length, equals(1));
          expect(stats.themeBeforeFatigue, inInclusiveRange(40, 80));
          expect(stats.finalTheme, equals(stats.themeBeforeFatigue - 10));
        }
      });

      test('AC-A1-1.6 對每一種旅行哲學，強 Build (基準分>=88, 疲勞前 90~100) finalTheme 必須等於疲勞前 Theme - 10', () {
        for (final philosophy in TravelPhilosophy.values) {
          final prefTags = philosophy.preferredTags.take(2).toList();
          // 槽位 0 與 1 為 risk 3 (恰一組疲勞 (0,1))，槽位 2 為 risk 2 (恰一組節奏 (1,2) +10)
          // 槽位 3 為空 (D1 空槽不進分母，各槽位無時段加成干擾)
          final strongBuild = TimelineItinerary(slots: [
            createMaterial(id: 's0', name: '強0', tags: prefTags, risk: 3, theme: 43),
            createMaterial(id: 's1', name: '強1', tags: prefTags, risk: 3, theme: 43),
            createMaterial(id: 's2', name: '強2', tags: prefTags, risk: 2, theme: 43),
            null,
          ]);

          final stats = strongBuild.calculateStats(
            philosophy: philosophy,
            cameraMultiplier: 1.0,
          );

          expect(stats.fatiguePairs.length, equals(1));
          expect(stats.themeBaseline, greaterThanOrEqualTo(88));
          expect(stats.themeBeforeFatigue, inInclusiveRange(90, 100));
          expect(
            stats.finalTheme,
            equals(stats.themeBeforeFatigue - 10),
            reason: '${philosophy.displayName} 強 Build 不得被 clamp 吃掉 -10 疲勞懲罰',
          );
        }
      });
    });
  });
}
