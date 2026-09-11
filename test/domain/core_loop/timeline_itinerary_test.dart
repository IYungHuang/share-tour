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
      expect(stats.fatiguePairs.contains(0), isTrue); // (0, 1) 相鄰對
      // finalTheme = base(50) + materialThemes(m0:15, m1:15) - fatigue(10) = 70
      expect(stats.finalTheme, 70);
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
  });
}
