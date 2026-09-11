import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';

void main() {
  group('五大旅行哲學系統測試 (AC-ML-2)', () {
    test('AC-A1-1.2 選定 midnight 哲學時，帶有 1 個偏好標籤 (#深夜) 的素材獲得 40% 加成貢獻', () {
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
      expect(contribution.effectiveTheme, 4); // round(10 * 0.40) = 4
      expect(contribution.flatThemePenalty, 0);
    });

    test('AC-A1-1.3 選定 antiTourism 哲學時，帶有 #大眾名店 標籤扣除 70% 負貢獻', () {
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
      expect(contribution.effectiveTheme, -14); // -round(20 * 0.70) = -14
      expect(contribution.flatThemePenalty, 0);
    });

    test('AC-A1-1.1 中性素材主題貢獻為 0，由基準 50 承接', () {
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
      expect(contribution.effectiveTheme, 0);
      expect(contribution.flatThemePenalty, 0);
    });

    test('AC-A1-1.2 命中 2 個偏好標籤獲得 90% 加成貢獻', () {
      const philosophy = TravelPhilosophy.midnight; // 偏好 #深夜, #小酌
      const material = TravelMaterial(
        id: 'test_spot_4',
        name: '深夜小酌食堂',
        tags: ['#深夜', '#小酌'],
        themeValue: 10,
        hypeValue: 30,
        cost: 0,
        riskLevel: 4,
      );

      final contribution = philosophy.evaluateMaterial(material);
      expect(contribution.effectiveTheme, 9); // round(10 * 0.90) = 9
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
      expect(contribution.effectiveTheme, -14); // 依排斥扣 70%
      expect(contribution.flatThemePenalty, 0);
    });

    test('五大旅行哲學偏好與排斥標籤符合 SPEC 附錄 A.1 詞彙表對齊方案', () {
      expect(TravelPhilosophy.midnight.preferredTags, ['#深夜', '#小酌']);
      expect(TravelPhilosophy.midnight.repelledTags, ['#拉車']);

      expect(TravelPhilosophy.slow.preferredTags, ['#散步', '#古蹟']);
      expect(TravelPhilosophy.slow.repelledTags, ['#高風險']);

      expect(TravelPhilosophy.gourmet.preferredTags, ['#美食', '#銅板美食', '#早餐']);
      expect(TravelPhilosophy.gourmet.repelledTags, ['#高風險']);

      expect(TravelPhilosophy.antiTourism.preferredTags, ['#巷弄秘境', '#怪談']);
      expect(TravelPhilosophy.antiTourism.repelledTags, ['#大眾名店']);

      expect(TravelPhilosophy.chaos.preferredTags, ['#高風險', '#拉車']);
      expect(TravelPhilosophy.chaos.repelledTags, ['#散步']);
    });
  });
}
