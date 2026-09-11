import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_tour/data/core_loop/local_persistence_repository.dart';
import 'package:share_tour/domain/core_loop/events/curator_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M4 資料層本機事件日誌測試 (AC-M4-3, AC-CC-3)', () {
    late SharedPreferences prefs;
    late LocalPersistenceRepository repo;

    Future<void> freshRepo([Map<String, Object> initial = const {}]) async {
      SharedPreferences.setMockInitialValues(initial);
      prefs = await SharedPreferences.getInstance();
      repo = LocalPersistenceRepository(prefs: prefs);
    }

    CuratorEvent event(int seq, CuratorEventType type, Map<String, Object?> p) =>
        CuratorEvent(
          eventId: 'evt-$seq',
          seq: seq,
          type: type,
          occurredAtUtc: DateTime.utc(2026, 9, 11, 6, seq),
          payload: p,
        );

    test('AC-M4-3.3: 空日誌下 loadSave 建立身分事件並回傳初始存檔', () async {
      await freshRepo();

      final loaded = await repo.loadSave();

      expect(loaded.profileId, isNotEmpty);
      expect(loaded.coins, 0);
      expect(loaded.sneakersLevel, 1);
      expect(loaded.completedRuns, 0);
      expect(loaded.updatedAtUtc.isUtc, isTrue);

      // 身分事件必須已落地，否則重啟後身分會改變
      final events = await repo.loadEvents();
      expect(events.single.type, CuratorEventType.profileCreated);
      expect(events.single.payload['profileId'], loaded.profileId);
    });

    test('AC-CC-3.6: appendEvents 只追加，既有事件不被修改或刪除', () async {
      await freshRepo();
      final first = event(1, CuratorEventType.profileCreated, {
        'profileId': 'p1',
      });
      final second = event(2, CuratorEventType.runSettled, {
        'earnedCoins': 800,
      });

      await repo.appendEvents([first]);
      await repo.appendEvents([second]);

      final events = await repo.loadEvents();
      expect(events, [first, second]);
    });

    test('AC-M4-3.2: 重啟後由日誌重播出完全相同的局外狀態', () async {
      await freshRepo();
      await repo.appendEvents([
        event(1, CuratorEventType.profileCreated, {'profileId': 'p1'}),
        event(2, CuratorEventType.runSettled, {'earnedCoins': 1500}),
        event(3, CuratorEventType.equipmentUpgraded, {
          'equipment': 'waistBag',
          'cost': 300,
        }),
      ]);

      // 以同一份底層儲存重新建立 repo，模擬 App 重啟
      final reopened = LocalPersistenceRepository(prefs: prefs);
      final loaded = await reopened.loadSave();

      expect(loaded.profileId, 'p1');
      expect(loaded.coins, 1200);
      expect(loaded.waistBagLevel, 2);
      expect(loaded.completedRuns, 1);
      expect(loaded.lastMonotonicSeq, 3);
    });

    test('AC-CC-3.7: 亂序追加的事件，讀出時依 seq 排序', () async {
      await freshRepo();
      await repo.appendEvents([
        event(2, CuratorEventType.runSettled, {'earnedCoins': 100}),
        event(1, CuratorEventType.profileCreated, {'profileId': 'p1'}),
      ]);

      final events = await repo.loadEvents();
      expect(events.map((e) => e.seq), [1, 2]);
    });

    test('AC-M4-3.4: 日誌損毀時備份原文並回傳空日誌，無崩潰', () async {
      await freshRepo({
        LocalPersistenceRepository.eventLogKey: '{ 這不是合法的 JSON 陣列',
      });

      final events = await repo.loadEvents();
      expect(events, isEmpty);

      final backupKey = prefs
          .getKeys()
          .firstWhere((k) => k.startsWith('event_log_corrupted_'));
      expect(prefs.getString(backupKey), contains('這不是合法的 JSON 陣列'));
    });

    test('合法 JSON 但事件欄位缺漏時，同樣走損毀備份路徑', () async {
      await freshRepo({
        LocalPersistenceRepository.eventLogKey: jsonEncode([
          {'seq': 1, 'type': 'profileCreated'}, // 缺 eventId / occurredAtUtc
        ]),
      });

      expect(await repo.loadEvents(), isEmpty);
      expect(
        prefs.getKeys().any((k) => k.startsWith('event_log_corrupted_')),
        isTrue,
      );
    });

    test('clearSave 抹除事件日誌鍵值', () async {
      await freshRepo();
      await repo.appendEvents([
        event(1, CuratorEventType.profileCreated, {'profileId': 'p1'}),
      ]);

      await repo.clearSave();

      expect(prefs.getString(LocalPersistenceRepository.eventLogKey), isNull);
      expect(await repo.loadEvents(), isEmpty);
    });
  });
}
