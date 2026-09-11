import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';

void main() {
  group('五大旅行哲學系統測試 (AC-ML-2)', () {
    test('AC-ML-2.1 選定 midnight 哲學時，帶有 #深夜 標籤的素材 themeValue 獲得 +50% 加成', () {
      const philosophy = TravelPhilosophy.midnight;
      const material = TravelMaterial(
        id: 'test_spot_1',
        name: '凌晨關東煮',
        tags: ['#深夜', '#溫暖'],
        themeValue: 10,
        hypeValue: 20,
        cost: 300,
        riskLevel: 1,
      );

      final contribution = philosophy.evaluateMaterial(material);
      expect(contribution.effectiveTheme, 15); // 10 * 1.5 = 15
      expect(contribution.flatThemePenalty, 0);
    });

    test('AC-ML-2.2 選定 antiTourism 哲學時，帶有 #大眾名店 標籤扣除 50% 且額外罰 5 點', () {
      const philosophy = TravelPhilosophy.antiTourism;
      const material = TravelMaterial(
        id: 'test_spot_2',
        name: '排隊千人名店',
        tags: ['#大眾名店', '#網紅'],
        themeValue: 20,
        hypeValue: 50,
        cost: 1500,
        riskLevel: 2,
      );

      final contribution = philosophy.evaluateMaterial(material);
      expect(contribution.effectiveTheme, 10); // 20 * 0.5 = 10
      expect(contribution.flatThemePenalty, 5); // 額外扣除 5 點 Theme
    });

    test('AC-ML-2.3 中性素材按原始 themeValue 計算，不觸發額外獎懲', () {
      const philosophy = TravelPhilosophy.slow;
      const material = TravelMaterial(
        id: 'test_spot_3',
        name: '一般雜貨店',
        tags: ['#日常', '#便利'],
        themeValue: 12,
        hypeValue: 10,
        cost: 100,
        riskLevel: 1,
      );

      final contribution = philosophy.evaluateMaterial(material);
      expect(contribution.effectiveTheme, 12);
      expect(contribution.flatThemePenalty, 0);
    });

    test('多重標籤命中偏好標籤僅一次性獲得 +50% 加成（不重複累計）', () {
      const philosophy = TravelPhilosophy.midnight; // 偏好 #深夜, #怪談, #孤獨
      const material = TravelMaterial(
        id: 'test_spot_4',
        name: '深夜幽靈廢墟',
        tags: ['#深夜', '#怪談', '#孤獨'],
        themeValue: 10,
        hypeValue: 30,
        cost: 0,
        riskLevel: 4,
      );

      final contribution = philosophy.evaluateMaterial(material);
      expect(contribution.effectiveTheme, 15); // 仍為 +50%
      expect(contribution.flatThemePenalty, 0);
    });

    test('同時命中偏好與排斥標籤時，以排斥懲罰為準', () {
      const philosophy = TravelPhilosophy.antiTourism; // 偏好 #巷弄秘境, 排斥 #大眾名店
      const material = TravelMaterial(
        id: 'test_spot_5',
        name: '排隊名店後巷',
        tags: ['#巷弄秘境', '#大眾名店'],
        themeValue: 20,
        hypeValue: 20,
        cost: 500,
        riskLevel: 2,
      );

      final contribution = philosophy.evaluateMaterial(material);
      expect(contribution.effectiveTheme, 10); // 依排斥打五折
      expect(contribution.flatThemePenalty, 5); // 依排斥額外扣 5
    });
  });
}
