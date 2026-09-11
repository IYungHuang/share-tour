import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_tour/data/core_loop/local_persistence_repository.dart';
import 'package:share_tour/domain/core_loop/events/curator_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('事件日誌的併發與韌性 (AC-CC-3)', () {
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

    CuratorEvent event(int seq, CuratorEventType type, Map<String, Object?> p) =>
        draft(seq, type, p).seal(seq);

    test('AC-CC-3.8 並行追加不得遺失事件', () async {
      await freshRepo();
      await repo.appendEvents([
        draft(1, CuratorEventType.profileCreated, {'profileId': 'p1'}),
      ]);

      // 不 await 前一筆就發下一筆：黑市連點兩次升級就是這個形狀
      final a = repo.appendEvents([
        draft(2, CuratorEventType.equipmentUpgraded, {
          'equipment': 'sneakers',
          'cost': 300,
        }),
      ]);
      final b = repo.appendEvents([
        draft(3, CuratorEventType.equipmentUpgraded, {
          'equipment': 'camera',
          'cost': 300,
        }),
      ]);
      await Future.wait([a, b]);

      final events = await repo.loadEvents();
      expect(
        events.map((e) => e.seq),
        [1, 2, 3],
        reason: '讀-改-寫若無互斥，後寫的那筆會蓋掉前一筆',
      );
    });

    test('AC-CC-3.9 seq 由日誌指派，呼叫端無從指定或撞號', () async {
      await freshRepo();

      final first = await repo.appendEvents([
        draft(1, CuratorEventType.profileCreated, {'profileId': 'p1'}),
      ]);
      final second = await repo.appendEvents([
        draft(9, CuratorEventType.runSettled, {'earnedCoins': 10}),
        draft(9, CuratorEventType.philosophyRerolled, {'cost': 100}),
      ]);

      // 草稿上的編號完全不影響結果：日誌接著自己的最後一號往下發
      expect(first.single.seq, 1);
      expect(second.map((e) => e.seq), [2, 3]);
      expect((await repo.loadEvents()).map((e) => e.seq), [1, 2, 3]);
    });

    test('AC-CC-3.10 語意壞掉的日誌不得讓載入拋出', () async {
      // 語法合法、但缺少身分事件
      await freshRepo({
        LocalPersistenceRepository.eventLogKey: jsonEncode([
          event(1, CuratorEventType.runSettled, {'earnedCoins': 500}).toJson(),
        ]),
      });

      final loaded = await repo.loadSave();

      expect(loaded.profileId, isNotEmpty);
      expect(loaded.coins, 0, reason: '壞日誌應被備份後重建，而非讓 App 開不起來');
      expect(
        prefs.getKeys().any((k) => k.startsWith('event_log_corrupted_')),
        isTrue,
      );
    });

    test('AC-CC-3.11 未知裝備種類的日誌同樣走備份重建', () async {
      await freshRepo({
        LocalPersistenceRepository.eventLogKey: jsonEncode([
          event(1, CuratorEventType.profileCreated, {'profileId': 'p1'}).toJson(),
          event(2, CuratorEventType.equipmentUpgraded, {
            'equipment': 'jetpack',
            'cost': 1,
          }).toJson(),
        ]),
      });

      final loaded = await repo.loadSave();
      expect(loaded.coins, 0);
    });

    test('AC-CC-3.12 損毀備份後原鍵必須清除，重啟不再重複備份', () async {
      await freshRepo({
        LocalPersistenceRepository.eventLogKey: '{ 不是合法 JSON 陣列',
      });

      await repo.loadEvents();
      final afterFirst = prefs
          .getKeys()
          .where((k) => k.startsWith('event_log_corrupted_'))
          .length;

      await repo.loadEvents();
      final afterSecond = prefs
          .getKeys()
          .where((k) => k.startsWith('event_log_corrupted_'))
          .length;

      expect(afterSecond, afterFirst, reason: '原鍵沒清除會讓每次啟動都再備份一次');
    });

    test('AC-CC-3.13 genesis 只產生一次，重複載入身分不變', () async {
      await freshRepo();

      final first = await repo.loadSave();
      final second = await repo.loadSave();

      expect(second.profileId, first.profileId);
      expect((await repo.loadEvents()).length, 1);
    });

    test('AC-CC-3.14 帶時區偏移的時戳與等值 UTC 時戳重播結果相同', () async {
      final withOffset = CuratorEvent.fromJson({
        'eventId': 'e1',
        'seq': 1,
        'type': 'profileCreated',
        'occurredAtUtc': '2026-09-11T14:00:00+08:00',
        'payload': const {'profileId': 'p1'},
      });
      final asUtc = CuratorEvent.fromJson({
        'eventId': 'e1',
        'seq': 1,
        'type': 'profileCreated',
        'occurredAtUtc': '2026-09-11T06:00:00Z',
        'payload': const {'profileId': 'p1'},
      });

      expect(withOffset, asUtc);
      expect(withOffset.occurredAtUtc.isUtc, isTrue);
    });
  });
}
