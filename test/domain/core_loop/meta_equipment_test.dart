import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';

void main() {
  group('局外三件套裝備數值與升級測試 (AC-ML-6)', () {
    test('AC-ML-6.1 佣金充足時可升級，扣除對應金額且等級遞增', () {
      final state = EquipmentInventory(
        coins: 1000,
        sneakers: EquipmentItem(type: EquipmentType.sneakers, level: 1),
        camera: EquipmentItem(type: EquipmentType.camera, level: 1),
        waistBag: EquipmentItem(type: EquipmentType.waistBag, level: 1),
      );

      final upgraded = state.upgrade(EquipmentType.sneakers);

      expect(upgraded.sneakers.level, 2);
      expect(upgraded.coins, 500); // 1000 - 500
      expect(upgraded.sneakers.maxHp, 115);
    });

    test('AC-ML-6.2 佣金不足時升級拋出異常，金額與等級不變', () {
      final state = EquipmentInventory(
        coins: 400, // 不足 500
        sneakers: EquipmentItem(type: EquipmentType.sneakers, level: 1),
        camera: EquipmentItem(type: EquipmentType.camera, level: 1),
        waistBag: EquipmentItem(type: EquipmentType.waistBag, level: 1),
      );

      expect(
        () => state.upgrade(EquipmentType.sneakers),
        throwsA(isA<InsufficientCoinsException>()),
      );
      expect(state.coins, 400);
      expect(state.sneakers.level, 1);
    });

    test('AC-ML-6.3 已達 Lv.3 的裝備無法再升級', () {
      final state = EquipmentInventory(
        coins: 5000,
        sneakers: EquipmentItem(type: EquipmentType.sneakers, level: 3),
        camera: EquipmentItem(type: EquipmentType.camera, level: 1),
        waistBag: EquipmentItem(type: EquipmentType.waistBag, level: 1),
      );

      expect(
        () => state.upgrade(EquipmentType.sneakers),
        throwsA(isA<MaxLevelReachedException>()),
      );
      expect(state.sneakers.level, 3);
      expect(state.coins, 5000);
    });

    test('三件套裝備等級映射數值完全符合規格', () {
      final lv1 = EquipmentInventory.initial();
      expect(lv1.sneakers.maxHp, 100);
      expect(lv1.camera.cameraMultiplier, 1.5);
      expect(lv1.waistBag.capacity, 6);

      final lv2 = lv1
          .copyWith(coins: 10000)
          .upgrade(EquipmentType.sneakers)
          .upgrade(EquipmentType.camera)
          .upgrade(EquipmentType.waistBag);
      expect(lv2.sneakers.maxHp, 115);
      expect(lv2.camera.cameraMultiplier, 1.8);
      expect(lv2.waistBag.capacity, 8);

      final lv3 = lv2
          .upgrade(EquipmentType.sneakers)
          .upgrade(EquipmentType.camera)
          .upgrade(EquipmentType.waistBag);
      expect(lv3.sneakers.maxHp, 130);
      expect(lv3.camera.cameraMultiplier, 2.2);
      expect(lv3.waistBag.capacity, 10);
    });
  });
}
