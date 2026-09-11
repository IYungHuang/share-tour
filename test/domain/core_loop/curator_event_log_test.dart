import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/events/curator_event.dart';
import 'package:share_tour/domain/core_loop/events/curator_event_replay.dart';

void main() {
  group('局外進度事件日誌與決定性重播 (AC-CC-3)', () {
    const profileId = 'f0e1d2c3-b4a5-4697-8899-aabbccddeeff';
    final t0 = DateTime.utc(2026, 9, 11, 6, 0, 0);

    List<CuratorEvent> buildLog() => [
      CuratorEvent(
        eventId: 'e1',
        seq: 1,
        type: CuratorEventType.profileCreated,
        occurredAtUtc: t0,
        payload: const {'profileId': profileId},
      ),
      CuratorEvent(
        eventId: 'e2',
        seq: 2,
        type: CuratorEventType.runSettled,
        occurredAtUtc: t0.add(const Duration(minutes: 8)),
        payload: const {'earnedCoins': 1500},
      ),
      CuratorEvent(
        eventId: 'e3',
        seq: 3,
        type: CuratorEventType.equipmentUpgraded,
        occurredAtUtc: t0.add(const Duration(minutes: 9)),
        payload: const {'equipment': 'sneakers', 'cost': 300},
      ),
      CuratorEvent(
        eventId: 'e4',
        seq: 4,
        type: CuratorEventType.philosophyRerolled,
        occurredAtUtc: t0.add(const Duration(minutes: 12)),
        payload: const {'cost': 100},
      ),
    ];

    test('AC-CC-3.1 同一事件序列重播兩次得出全等狀態', () {
      expect(replayCuratorEvents(buildLog()), replayCuratorEvents(buildLog()));
    });

    test('AC-CC-3.2 重播結果僅由事件決定，不受呼叫當下時間影響', () {
      final first = replayCuratorEvents(buildLog());
      final second = replayCuratorEvents(buildLog());

      // 時戳必須來自最後一個事件，而非重播當下
      expect(first.updatedAtUtc, t0.add(const Duration(minutes: 12)));
      expect(first.updatedAtUtc.isUtc, isTrue);
      expect(first.updatedAtUtc, second.updatedAtUtc);
    });

    test('AC-CC-3.3 重播正確累積金幣、裝備等級與完成局數', () {
      final save = replayCuratorEvents(buildLog());

      expect(save.profileId, profileId);
      expect(save.coins, 1500 - 300 - 100);
      expect(save.sneakersLevel, 2);
      expect(save.cameraLevel, 1);
      expect(save.waistBagLevel, 1);
      expect(save.completedRuns, 1);
      expect(save.lastMonotonicSeq, 4);
    });

    test('AC-CC-3.4 重播順序敏感：事件亂序輸入仍依 seq 決定結果', () {
      final shuffled = buildLog().reversed.toList();
      expect(replayCuratorEvents(shuffled), replayCuratorEvents(buildLog()));
    });

    test('AC-CC-3.5 事件 JSON 往返不失真', () {
      for (final event in buildLog()) {
        expect(CuratorEvent.fromJson(event.toJson()), event);
      }
    });

    test('空事件序列重播得出初始存檔但缺少身分時拋出', () {
      expect(() => replayCuratorEvents(const []), throwsA(isA<StateError>()));
    });

    test('重播結果可直接轉為局外裝備清單', () {
      final save = replayCuratorEvents(buildLog());
      final equipment = save.toEquipmentInventory();

      expect(equipment.coins, 1100);
      expect(equipment.sneakers.level, 2);
      expect(equipment.camera.level, 1);
    });
  });
}
