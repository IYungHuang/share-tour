import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_tour/data/core_loop/local_persistence_repository.dart';
import 'package:share_tour/domain/core_loop/models/curator_save_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M4 資料層本機存檔測試 (AC-M4-3)', () {
    test('AC-M4-3.3: 空存檔環境下呼叫 loadSave 回傳初始資料 (0幣, 全Lv.1, UUID)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalPersistenceRepository(prefs: prefs);

      final loaded = await repo.loadSave();
      expect(loaded.profileId, isNotEmpty);
      expect(loaded.saveVersion, 1);
      expect(loaded.coins, 0);
      expect(loaded.sneakersLevel, 1);
      expect(loaded.cameraLevel, 1);
      expect(loaded.waistBagLevel, 1);
      expect(loaded.completedRuns, 0);
      expect(loaded.updatedAtUtc.isUtc, isTrue);
    });

    test('AC-M4-3.2: 儲存裝備與金幣資料，重新 loadSave 100% 完整還原', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalPersistenceRepository(prefs: prefs);

      final originalData = CuratorSaveData(
        profileId: 'player-profile-uuid-001',
        saveVersion: 1,
        lastMonotonicSeq: 5,
        coins: 1200,
        sneakersLevel: 2,
        cameraLevel: 1,
        waistBagLevel: 3,
        completedRuns: 2,
        updatedAtUtc: DateTime.parse('2026-09-11T13:45:00.000Z'),
      );

      await repo.save(originalData);

      final loaded = await repo.loadSave();
      expect(loaded.profileId, 'player-profile-uuid-001');
      expect(loaded.coins, 1200);
      expect(loaded.sneakersLevel, 2);
      expect(loaded.cameraLevel, 1);
      expect(loaded.waistBagLevel, 3);
      expect(loaded.completedRuns, 2);
      expect(loaded.lastMonotonicSeq, 5);
      expect(loaded, equals(originalData));

      final inventory = loaded.toEquipmentInventory();
      expect(inventory.coins, 1200);
      expect(inventory.sneakers.maxHp, 125); // Lv.2 HP
      expect(inventory.waistBag.capacity, 10); // Lv.3 Capacity
    });

    test('AC-M4-3.4: 存檔損毀防護：JSON 格式毀損時自動備份至 .bak 並回傳初始存檔，無崩潰', () async {
      const corruptedJson = '{"coins": 9999, "corrupted_incomplete_json';
      SharedPreferences.setMockInitialValues({
        LocalPersistenceRepository.saveKey: corruptedJson,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalPersistenceRepository(prefs: prefs);

      final loaded = await repo.loadSave();
      // 成功回退為初始存檔
      expect(loaded.coins, 0);
      expect(loaded.sneakersLevel, 1);

      // 驗證已建立 .bak 備份鍵值
      final keys = prefs.getKeys();
      final bakKeys = keys.where((k) => k.startsWith('save_corrupted_'));
      expect(bakKeys.length, 1);
      final backupContent = prefs.getString(bakKeys.first);
      expect(backupContent, corruptedJson);
    });

    test('clearSave 成功抹除主存檔鍵值', () async {
      SharedPreferences.setMockInitialValues({
        LocalPersistenceRepository.saveKey: '{"profileId":"test"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalPersistenceRepository(prefs: prefs);

      await repo.clearSave();
      expect(prefs.containsKey(LocalPersistenceRepository.saveKey), isFalse);
    });
  });
}
