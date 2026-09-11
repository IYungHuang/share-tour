import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/curator_save_data.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';

void main() {
  group('Milestone M4 領域層存檔與數值階梯測試 (AC-M4-2, AC-M4-3)', () {
    test('AC-FIX-4.1: fromJson 必須決定性；缺少身分或時戳的存檔視為損毀', () {
      const completeJson = <String, dynamic>{
        'profileId': 'f0e1d2c3-b4a5-4697-8899-aabbccddeeff',
        'saveVersion': 1,
        'lastMonotonicSeq': 3,
        'coins': 720,
        'sneakersLevel': 2,
        'cameraLevel': 1,
        'waistBagLevel': 1,
        'completedRuns': 4,
        'updatedAtUtc': '2026-09-11T06:30:00.000Z',
      };

      // 決定性：同一份 JSON 解析兩次必須全等 (AC-CC-3.1)
      expect(
        CuratorSaveData.fromJson(completeJson),
        equals(CuratorSaveData.fromJson(completeJson)),
      );

      for (final missing in ['profileId', 'updatedAtUtc']) {
        final broken = Map<String, dynamic>.from(completeJson)..remove(missing);
        expect(
          () => CuratorSaveData.fromJson(broken),
          throwsA(isA<FormatException>()),
          reason: '缺少 $missing 時不得就地捏造身分或當下時間',
        );
      }
    });

    test('AC-M4-2.1: 升級球鞋 Lv.1 -> Lv.2 需 300 幣，扣款後 HP 升至 125', () {
      final inventory = EquipmentInventory.initial().copyWith(coins: 350);
      expect(inventory.sneakers.level, 1);
      expect(inventory.sneakers.maxHp, 100);
      expect(inventory.sneakers.nextUpgradeCost, 300);
      expect(inventory.sneakers.isMaxLevel, isFalse);
      expect(inventory.sneakers.canAffordUpgrade(inventory.coins), isTrue);

      final upgraded = inventory.upgrade(EquipmentType.sneakers);
      expect(upgraded.coins, 50);
      expect(upgraded.sneakers.level, 2);
      expect(upgraded.sneakers.maxHp, 125);
      expect(upgraded.sneakers.nextUpgradeCost, 1200);
      expect(upgraded.sneakers.canAffordUpgrade(upgraded.coins), isFalse);
    });

    test('AC-M4-2.2: 金幣不足升級時拋出 InsufficientCoinsException 且零副作用', () {
      final inventory = EquipmentInventory.initial().copyWith(coins: 200);
      expect(inventory.camera.level, 1);
      expect(inventory.camera.nextUpgradeCost, 300);
      expect(inventory.camera.canAffordUpgrade(inventory.coins), isFalse);

      expect(
        () => inventory.upgrade(EquipmentType.camera),
        throwsA(isA<InsufficientCoinsException>()),
      );
      expect(inventory.coins, 200);
      expect(inventory.camera.level, 1);
    });

    test('AC-M4-2.3: 滿級 Lv.3 nextUpgradeCost 為 null，再升級拋出 MaxLevelReachedException', () {
      final maxInventory = EquipmentInventory(
        coins: 10000,
        sneakers: const EquipmentItem(type: EquipmentType.sneakers, level: 3),
        camera: const EquipmentItem(type: EquipmentType.camera, level: 3),
        waistBag: const EquipmentItem(type: EquipmentType.waistBag, level: 3),
      );

      expect(maxInventory.sneakers.maxHp, 155);
      expect(maxInventory.camera.cameraMultiplier, 2.2);
      expect(maxInventory.waistBag.capacity, 10);

      expect(maxInventory.waistBag.isMaxLevel, isTrue);
      expect(maxInventory.waistBag.nextUpgradeCost, isNull);
      expect(maxInventory.waistBag.canAffordUpgrade(maxInventory.coins), isFalse);

      expect(
        () => maxInventory.upgrade(EquipmentType.waistBag),
        throwsA(isA<MaxLevelReachedException>()),
      );
      expect(maxInventory.coins, 10000);
    });

    test('CuratorSaveData 序列化、反序列化與 UTC / CC-1 / CC-2 / CC-3 檢查', () {
      final nowUtc = DateTime.parse('2026-09-11T12:00:00.000Z');
      final initialData = CuratorSaveData.initial(
        profileId: 'test-uuid-v4-0001',
        nowUtc: nowUtc,
      );

      expect(initialData.profileId, 'test-uuid-v4-0001');
      expect(initialData.saveVersion, 1);
      expect(initialData.lastMonotonicSeq, 0);
      expect(initialData.coins, 0);
      expect(initialData.sneakersLevel, 1);
      expect(initialData.cameraLevel, 1);
      expect(initialData.waistBagLevel, 1);
      expect(initialData.completedRuns, 0);
      expect(initialData.updatedAtUtc.isUtc, isTrue);

      final json = initialData.toJson();
      final restored = CuratorSaveData.fromJson(json);
      expect(restored, equals(initialData));
      expect(restored.updatedAtUtc.isUtc, isTrue);
    });

    test('CuratorSaveData 與 EquipmentInventory 雙向轉換正確性', () {
      final inventory = EquipmentInventory(
        coins: 800,
        sneakers: const EquipmentItem(type: EquipmentType.sneakers, level: 2),
        camera: const EquipmentItem(type: EquipmentType.camera, level: 1),
        waistBag: const EquipmentItem(type: EquipmentType.waistBag, level: 3),
      );

      final saveData = CuratorSaveData.fromEquipment(
        profileId: 'uuid-1234',
        equipment: inventory,
        completedRuns: 3,
        lastMonotonicSeq: 15,
        updatedAtUtc: DateTime.utc(2026, 9, 11, 10, 30),
      );

      expect(saveData.coins, 800);
      expect(saveData.sneakersLevel, 2);
      expect(saveData.cameraLevel, 1);
      expect(saveData.waistBagLevel, 3);
      expect(saveData.completedRuns, 3);
      expect(saveData.lastMonotonicSeq, 15);

      final restoredInventory = saveData.toEquipmentInventory();
      expect(restoredInventory, equals(inventory));
    });

    test('CuratorSaveData 非 UTC 時間拋出 AssertionError', () {
      final localTime = DateTime(2026, 9, 11, 12, 0); // 非 UTC
      if (!localTime.isUtc) {
        expect(
          () => CuratorSaveData(
            profileId: 'id',
            saveVersion: 1,
            lastMonotonicSeq: 0,
            coins: 0,
            sneakersLevel: 1,
            cameraLevel: 1,
            waistBagLevel: 1,
            completedRuns: 0,
            updatedAtUtc: localTime,
          ),
          throwsA(isA<AssertionError>()),
        );
      }
    });
  });
}
