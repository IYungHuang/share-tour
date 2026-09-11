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

    CuratorEventDraft draft(
      int n,
      CuratorEventType type,
      Map<String, Object?> p,
    ) => CuratorEventDraft(
      eventId: 'evt-$n',
      type: type,
      occurredAtUtc: DateTime.utc(2026, 9, 11, 6, n),
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
      final first = await repo.appendEvents([
        draft(1, CuratorEventType.profileCreated, {'profileId': 'p1'}),
      ]);
      final second = await repo.appendEvents([
        draft(2, CuratorEventType.runSettled, {'earnedCoins': 800}),
      ]);

      final events = await repo.loadEvents();
      expect(events, [...first, ...second]);
    });

    test('AC-M4-3.2: 重啟後由日誌重播出完全相同的局外狀態', () async {
      await freshRepo();
      await repo.appendEvents([
        draft(1, CuratorEventType.profileCreated, {'profileId': 'p1'}),
        draft(2, CuratorEventType.runSettled, {'earnedCoins': 1500}),
        draft(3, CuratorEventType.equipmentUpgraded, {
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

    test('AC-CC-3.7: 讀出的事件一律依 seq 遞增排序', () async {
      await freshRepo();
      await repo.appendEvents([
        draft(1, CuratorEventType.profileCreated, {'profileId': 'p1'}),
        draft(2, CuratorEventType.runSettled, {'earnedCoins': 100}),
      ]);

      final events = await repo.loadEvents();
      expect(events.map((e) => e.seq), [1, 2]);
      expect(events.first.type, CuratorEventType.profileCreated);
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
        draft(1, CuratorEventType.profileCreated, {'profileId': 'p1'}),
      ]);

      await repo.clearSave();

      expect(prefs.getString(LocalPersistenceRepository.eventLogKey), isNull);
      expect(await repo.loadEvents(), isEmpty);
    });

    test('舊版日誌 JSON fixture 載入與重啟驗證：無 corrupted backup、重播正確且可追加新事件', () async {
      const historicalJson = '''[
        {"eventId":"h1","seq":1,"type":"profileCreated","occurredAtUtc":"2026-09-10T12:00:00.000Z","payload":{"profileId":"hist-p1"}},
        {"eventId":"h2","seq":2,"type":"runSettled","occurredAtUtc":"2026-09-10T12:30:00.000Z","payload":{"earnedCoins":2000}},
        {"eventId":"h3","seq":3,"type":"equipmentUpgraded","occurredAtUtc":"2026-09-10T12:35:00.000Z","payload":{"equipment":"sneakers","cost":300}}
      ]''';

      await freshRepo({
        LocalPersistenceRepository.eventLogKey: historicalJson,
      });

      // 載入舊日誌存檔
      final save1 = await repo.loadSave();
      expect(save1.profileId, 'hist-p1');
      expect(save1.coins, 1700); // 2000 - 300
      expect(save1.sneakersLevel, 2);
      expect(save1.completedRuns, 1);
      expect(save1.lastMonotonicSeq, 3);

      // 驗證未產生損毀備份
      expect(
        prefs.getKeys().any((k) => k.startsWith('event_log_corrupted_')),
        isFalse,
      );

      // 重開 repo，確認舊日誌未被覆蓋或修改
      final repo2 = LocalPersistenceRepository(prefs: prefs);
      final rawBefore = prefs.getString(LocalPersistenceRepository.eventLogKey);
      final save2 = await repo2.loadSave();
      expect(save2, save1);
      expect(prefs.getString(LocalPersistenceRepository.eventLogKey), rawBefore);

      // 載入後新增一筆新價格事件 (500)
      final appended = await repo2.appendEvents([
        draft(4, CuratorEventType.equipmentUpgraded, {
          'equipment': 'sneakers',
          'cost': 500,
        }),
      ]);
      expect(appended.single.seq, 4);

      final save3 = await repo2.loadSave();
      expect(save3.coins, 1200); // 1700 - 500
      expect(save3.sneakersLevel, 3);
      expect(save3.lastMonotonicSeq, 4);
    });
  });
}
