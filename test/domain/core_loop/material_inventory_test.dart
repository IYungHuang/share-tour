import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/material_inventory.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';

void main() {
  group('腰包容量與素材庫存管理測試 (AC-ML-3)', () {
    TravelMaterial createMaterial(String id) => TravelMaterial(
      id: id,
      name: '素材 $id',
      tags: ['#測試'],
      themeValue: 10,
      hypeValue: 10,
    );

    test('AC-ML-3.1 腰包 Lv.1 上限為 6，滿額時直接加入拋出 InventoryFullException', () {
      final inventory = MaterialInventory(capacity: 6);

      var current = inventory;
      for (var i = 1; i <= 6; i++) {
        current = current.add(createMaterial('m_$i'));
      }

      expect(current.count, 6);
      expect(current.isFull, isTrue);

      expect(
        () => current.add(createMaterial('m_7')),
        throwsA(isA<InventoryFullException>()),
      );
      expect(current.count, 6);
    });

    test('AC-ML-3.2 滿額時執行替換 (replace)，剔除指定索引素材並存入新素材，總數不變', () {
      var current = MaterialInventory(capacity: 6);
      for (var i = 1; i <= 6; i++) {
        current = current.add(createMaterial('m_$i'));
      }

      // 替換索引 2 (即 m_3) 為 new_m
      final replaced = current.replace(
        dropIndex: 2,
        newItem: createMaterial('new_m'),
      );

      expect(replaced.count, 6);
      expect(replaced.materials.any((m) => m.id == 'm_3'), isFalse);
      expect(replaced.materials.any((m) => m.id == 'new_m'), isTrue);
      expect(replaced.materials[2].id, 'new_m');
    });

    test('AC-ML-3.3 腰包升級至 Lv.2 後容量上限擴增為 8，可容納第 7、8 個素材', () {
      final equipLv2 = EquipmentInventory.initial()
          .copyWith(coins: 1000)
          .upgrade(EquipmentType.waistBag);
      expect(equipLv2.waistBag.capacity, 8);

      var inventory = MaterialInventory(capacity: equipLv2.waistBag.capacity);
      for (var i = 1; i <= 8; i++) {
        inventory = inventory.add(createMaterial('m_$i'));
      }

      expect(inventory.count, 8);
      expect(inventory.isFull, isTrue);

      expect(
        () => inventory.add(createMaterial('m_9')),
        throwsA(isA<InventoryFullException>()),
      );
    });
  });
}
