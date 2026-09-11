import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/guide_resources.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';

void main() {
  group('阿導資源狀態機測試 (AC-ML-1)', () {
    test('AC-ML-1.1 球鞋 Lv.1 初始 HP 為 100；球鞋 Lv.2 初始 HP 為 125', () {
      final equipLv1 = EquipmentInventory.initial();
      final resLv1 = GuideResources.initial(
        startingBudget: 2000,
        equipment: equipLv1,
      );

      expect(resLv1.hp, 100);
      expect(resLv1.maxHp, 100);
      expect(resLv1.budget, 2000);
      expect(resLv1.theme, 50);
      expect(resLv1.hype, 0);
      expect(resLv1.isExhausted, isFalse);
      expect(resLv1.isDeficit, isFalse);

      final equipLv2 = equipLv1
          .copyWith(coins: 500)
          .upgrade(EquipmentType.sneakers);
      final resLv2 = GuideResources.initial(
        startingBudget: 8000,
        equipment: equipLv2,
      );
      expect(resLv2.hp, 125);
      expect(resLv2.maxHp, 125);
      expect(resLv2.budget, 8000);
    });

    test('AC-ML-1.2 扣除 HP 至小於等於 0 時，isExhausted 為 true 且 HP 截斷為 0', () {
      final res = GuideResources.initial(
        startingBudget: 2000,
        equipment: EquipmentInventory.initial(),
      );

      final damaged = res.consumeHp(40);
      expect(damaged.hp, 60);
      expect(damaged.isExhausted, isFalse);

      final exhausted = damaged.consumeHp(80); // 60 - 80 = -20 -> clamp to 0
      expect(exhausted.hp, 0);
      expect(exhausted.isExhausted, isTrue);
    });

    test('AC-ML-1.3 花費超過 Budget 時，isDeficit 變為 true，允許 Budget 呈現負數', () {
      final res = GuideResources.initial(
        startingBudget: 1000,
        equipment: EquipmentInventory.initial(),
      );

      final spent = res.spendBudget(1300);
      expect(spent.budget, -300);
      expect(spent.isDeficit, isTrue);
    });

    test('AC-ML-1.4 Theme 增加超過 100 自動 clamp 至 100；扣至負數自動 clamp 至 0', () {
      final res = GuideResources.initial(
        startingBudget: 2000,
        equipment: EquipmentInventory.initial(),
      );
      expect(res.theme, 50);

      final boosted = res.adjustTheme(70);
      expect(boosted.theme, 100); // 50 + 70 = 120 -> clamp to 100

      final drained = boosted.adjustTheme(-120);
      expect(drained.theme, 0); // 100 - 120 = -20 -> clamp to 0
    });
  });
}
