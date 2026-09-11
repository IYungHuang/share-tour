import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

import 'package:share_tour/data/core_loop/kyoto_night_layout.dart';
import '../support/kyoto_walk_driver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AC-A1-4.1 四分鐘邏輯步行採集實測 (Commit 14, T12)', () {
    test('AC-A1-4.1: 自 spawn 出發，僅靠方向鍵在 240 秒內採集 6 個不同 POI，腰包 6 張且 HP > 0', () async {
      final driver = await KyotoWalkDriver.create();

      // 1. 驗證起始點在 spawn (128, 112)
      expect(driver.renderedPixel, equals(kyotoSpawnPixel));
      expect(driver.runState.resources.currentHp, 100);
      expect(driver.runState.inventory.materials, isEmpty);
      expect(driver.gatherEvents, isEmpty);

      // 目標 6 個 POI 座標
      final p0 = kyotoGridPixelForIndex(0); // (160, 112)
      final p1 = kyotoGridPixelForIndex(1); // (384, 112)
      final p2 = kyotoGridPixelForIndex(2); // (608, 112)
      final p3 = kyotoGridPixelForIndex(3); // (832, 112)
      final p4 = kyotoGridPixelForIndex(4); // (832, 224)
      final p5 = kyotoGridPixelForIndex(5); // (608, 224)

      // 輔助函式：朝目標點持續前進，直到抵達其觸發半徑 (20px) 內並成功採集
      Future<void> walkToAndGather(Vector2 target, String expectedPoiId) async {
        while (true) {
          final diff = target - driver.renderedPixel;
          final dist = diff.length;

          // 若已在 trigger radius (20px) 內且尚未採集到 expectedPoiId，原地稍候平滑收斂並採集
          if (dist <= kyotoTriggerRadiusPixels) {
            await driver.tick(direction: Vector2.zero(), autoGather: true);
            if (driver.runState.gatheredPoiIds.contains(expectedPoiId)) {
              break;
            }
          }

          // 否則依方向前進一個 tick
          final dir = diff.normalized();
          await driver.tick(direction: dir, autoGather: true);

          if (driver.runState.gatheredPoiIds.contains(expectedPoiId)) {
            break;
          }

          // 安全護欄：不應超過 240 秒
          if (driver.elapsed.inSeconds > 240) {
            fail('超過 240 秒上限，當前經過時間: ${driver.elapsed}');
          }
        }
      }

      // 依序步行採集 6 個 POI
      final expectedOrder = deterministicKyotoCardOrder.take(6).toList();

      await walkToAndGather(p0, expectedOrder[0]);
      expect(driver.gatherEvents.length, 1);
      expect(driver.gatherEvents.last.attraction.id, expectedOrder[0]);

      await walkToAndGather(p1, expectedOrder[1]);
      expect(driver.gatherEvents.length, 2);
      expect(driver.gatherEvents.last.attraction.id, expectedOrder[1]);

      await walkToAndGather(p2, expectedOrder[2]);
      expect(driver.gatherEvents.length, 3);
      expect(driver.gatherEvents.last.attraction.id, expectedOrder[2]);

      await walkToAndGather(p3, expectedOrder[3]);
      expect(driver.gatherEvents.length, 4);
      expect(driver.gatherEvents.last.attraction.id, expectedOrder[3]);

      await walkToAndGather(p4, expectedOrder[4]);
      expect(driver.gatherEvents.length, 5);
      expect(driver.gatherEvents.last.attraction.id, expectedOrder[4]);

      await walkToAndGather(p5, expectedOrder[5]);
      expect(driver.gatherEvents.length, 6);
      expect(driver.gatherEvents.last.attraction.id, expectedOrder[5]);

      // 2. 斷言採集結果契約
      // (a) 邏輯時間 <= 240 秒
      expect(driver.elapsed.inSeconds, lessThanOrEqualTo(240));

      // (b) 採集 6 個不同 ID
      final gatheredIds = driver.runState.gatheredPoiIds.toList();
      expect(gatheredIds.length, 6);
      expect(gatheredIds.toSet().length, 6);
      expect(gatheredIds, equals(expectedOrder));

      // (c) 腰包 6 張卡滿額
      expect(driver.runState.inventory.isFull, isTrue);
      expect(driver.runState.inventory.materials.length, 6);

      // (d) 剩餘 HP > 0 (總成本 96, 剩餘 4)
      expect(driver.runState.resources.currentHp, greaterThan(0));
      expect(driver.runState.resources.currentHp, equals(4));

      // (e) 驗證 scope dispose 後 virtual location source 停止
      final source = driver.virtualSource;
      driver.dispose();

      // dispose 後再推進時間，確認不會再推播事件
      var emittedAfterDispose = false;
      final sub = source.fixes.listen((_) => emittedAfterDispose = true);
      await driver.clock.advanceAsync(source.interval * 5);
      await sub.cancel();
      expect(emittedAfterDispose, isFalse);
    });
  });
}
