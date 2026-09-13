import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/time/diurnal_resonance_rule.dart';
import 'package:share_tour/domain/core_loop/time/tour_period.dart';

void main() {
  group('Task 2: DiurnalResonanceRule 時段順行體力共鳴測試', () {
    const walkMaterial = TravelMaterial(
      id: 'mat_kamogawa_walk',
      name: '鴨川清晨漫步',
      tags: ['#散步', '#京都日常'],
      riskLevel: 1,
      hypeValue: 20,
      themeValue: 40,
      cost: 0,
    );

    const cafeMaterial = TravelMaterial(
      id: 'mat_inoda_coffee',
      name: '町家老舖手沖咖啡',
      tags: ['#咖啡', '#名店'],
      riskLevel: 2,
      hypeValue: 25,
      themeValue: 45,
      cost: 600,
    );

    const scenicMaterial = TravelMaterial(
      id: 'mat_yasaka_dusk',
      name: '八坂之塔黃昏金調',
      tags: ['#絕景', '#古道'],
      riskLevel: 2,
      hypeValue: 50,
      themeValue: 50,
      cost: 500,
      isSpotlight: true,
    );

    const barMaterial = TravelMaterial(
      id: 'mat_pontocho_bar',
      name: '先斗町深夜居酒屋',
      tags: ['#深夜', '#居酒屋'],
      riskLevel: 4,
      hypeValue: 45,
      themeValue: 45,
      cost: 1200,
    );

    test('晨曦時段 (dawn) 命中 #散步 標籤享受 3 HP 折讓', () {
      expect(
        DiurnalResonanceRule.hasResonance(
          currentPeriod: TourPeriod.dawn,
          material: walkMaterial,
        ),
        isTrue,
      );
      expect(
        DiurnalResonanceRule.calculateDiscount(
          currentPeriod: TourPeriod.dawn,
          material: walkMaterial,
        ),
        3,
      );
      // 午後對 #散步 不共鳴
      expect(
        DiurnalResonanceRule.calculateDiscount(
          currentPeriod: TourPeriod.midday,
          material: walkMaterial,
        ),
        0,
      );
    });

    test('午後時段 (midday) 命中 #名店、#咖啡 標籤享受 3 HP 折讓', () {
      expect(
        DiurnalResonanceRule.calculateDiscount(
          currentPeriod: TourPeriod.midday,
          material: cafeMaterial,
        ),
        3,
      );
    });

    test('黃昏時段 (dusk) 命中 #絕景 標籤享受 3 HP 折讓', () {
      expect(
        DiurnalResonanceRule.calculateDiscount(
          currentPeriod: TourPeriod.dusk,
          material: scenicMaterial,
        ),
        3,
      );
    });

    test('深夜時段 (night) 命中 #深夜、#居酒屋 標籤享受 3 HP 折讓', () {
      expect(
        DiurnalResonanceRule.calculateDiscount(
          currentPeriod: TourPeriod.night,
          material: barMaterial,
        ),
        3,
      );
    });

    test('折讓後實扣計算正確，且嚴格守住 1 HP 最低消耗底線', () {
      // risk 2 baseHpCost = 12 -> 折讓後 9
      final costA = DiurnalResonanceRule.calculateActualCost(
        baseHpCost: 12,
        currentPeriod: TourPeriod.dusk,
        material: scenicMaterial,
      );
      expect(costA, 9);

      // 極端邊界值: baseHpCost = 2 -> 2 - 3 = -1 -> 夾緊至 1 HP
      final costFloor = DiurnalResonanceRule.calculateActualCost(
        baseHpCost: 2,
        currentPeriod: TourPeriod.dawn,
        material: walkMaterial,
      );
      expect(costFloor, 1);
    });

    test('素材本體不可變性：計算過程中不變更 TravelMaterial 任何屬性', () {
      final beforeTags = List<String>.from(scenicMaterial.tags);
      final beforeCost = scenicMaterial.cost;
      final beforeHype = scenicMaterial.hypeValue;

      DiurnalResonanceRule.calculateActualCost(
        baseHpCost: 12,
        currentPeriod: TourPeriod.dusk,
        material: scenicMaterial,
      );

      expect(scenicMaterial.tags, beforeTags);
      expect(scenicMaterial.cost, beforeCost);
      expect(scenicMaterial.hypeValue, beforeHype);
      expect(scenicMaterial.isSpotlight, isTrue);
    });
  });
}
