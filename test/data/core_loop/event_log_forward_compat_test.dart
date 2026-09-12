import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_tour/data/core_loop/local_persistence_repository.dart';
import 'package:share_tour/domain/core_loop/events/curator_event.dart';
import 'package:share_tour/domain/core_loop/events/curator_event_replay.dart';

/// 事件日誌的前向相容：舊建置讀到含新事件種類的日誌時不得毀損存檔。
///
/// 未修復前的行為鏈：`fromJson` 對未知 type 拋 `FormatException`
/// → `loadEvents` 把整份日誌搬去 `.bak` 並回空 → `loadSave` 重建全新身分
/// → 玩家金幣與裝備歸零。
///
/// 即使改成「跳過未知事件」仍不夠：`_doAppend` 是「讀出 → 合併 → 整份寫回」，
/// 被跳過的事件不在 `existing` 裡，會在下一次追加時被永久抹掉，且新事件的
/// `seq` 會與被抹掉那些撞號。故契約是**原文保留**。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('事件日誌前向相容 (未知事件種類原文保留)', () {
    late SharedPreferences prefs;
    late LocalPersistenceRepository repo;

    /// 由較新建置寫出的日誌：第 2 筆是本建置不認得的種類。
    String logWithUnknownType() => jsonEncode([
      {
        'eventId': 'evt-1',
        'seq': 1,
        'type': 'profileCreated',
        'occurredAtUtc': '2026-09-12T06:01:00.000Z',
        'payload': {'profileId': 'p1'},
      },
      {
        'eventId': 'evt-2',
        'seq': 2,
        'type': 'difficultySelected',
        'occurredAtUtc': '2026-09-12T06:02:00.000Z',
        'payload': {'difficulty': 'photographer'},
      },
      {
        'eventId': 'evt-3',
        'seq': 3,
        'type': 'runSettled',
        'occurredAtUtc': '2026-09-12T06:03:00.000Z',
        'payload': {'earnedCoins': 1200},
      },
    ]);

    Future<void> freshRepo(String log) async {
      SharedPreferences.setMockInitialValues({
        LocalPersistenceRepository.eventLogKey: log,
      });
      prefs = await SharedPreferences.getInstance();
      repo = LocalPersistenceRepository(prefs: prefs);
    }

    test('未知事件種類不觸發損毀備份，日誌原樣載入', () async {
      await freshRepo(logWithUnknownType());

      final events = await repo.loadEvents();

      expect(events.length, 3, reason: '未知事件必須保留在序列中');
      expect(events[1].type, isNull, reason: '無法對應列舉時 type 為 null');
      expect(events[1].rawTypeName, 'difficultySelected');
      expect(events[1].seq, 2);
      expect(events[1].payload['difficulty'], 'photographer');
      expect(
        prefs.getKeys().where((k) => k.contains('bak')),
        isEmpty,
        reason: '未知種類是前向相容情形，不是日誌損毀',
      );
    });

    test('重播忽略未知事件，已知事件照常結算', () async {
      await freshRepo(logWithUnknownType());

      final save = replayCuratorEvents(await repo.loadEvents());

      expect(save.profileId, 'p1');
      expect(save.coins, 1200);
      expect(save.completedRuns, 1);
      expect(save.lastMonotonicSeq, 3);
    });

    test('loadSave 不重建身分，金幣不歸零', () async {
      await freshRepo(logWithUnknownType());

      final save = await repo.loadSave();

      expect(save.profileId, 'p1');
      expect(save.coins, 1200);
    });

    test('追加之後未知事件仍在日誌中，且新事件不與它撞號', () async {
      await freshRepo(logWithUnknownType());

      final sealed = await repo.appendEvents([
        CuratorEventDraft(
          eventId: 'evt-4',
          type: CuratorEventType.runSettled,
          occurredAtUtc: DateTime.utc(2026, 9, 12, 6, 4),
          payload: const {'earnedCoins': 800},
        ),
      ]);

      expect(sealed.single.seq, 4, reason: 'seq 須接續未知事件之後');

      final reloaded = await repo.loadEvents();
      expect(reloaded.length, 4);
      expect(
        reloaded.map((e) => e.seq).toList(),
        [1, 2, 3, 4],
        reason: '未知事件被抹掉會讓 seq 塌陷並與新事件撞號',
      );
      expect(reloaded[1].rawTypeName, 'difficultySelected');
      expect(
        reloaded[1].payload['difficulty'],
        'photographer',
        reason: 'payload 須原文保留，日後升版才救得回來',
      );
    });

    test('未知事件寫回磁碟時 type 欄位維持原文', () async {
      await freshRepo(logWithUnknownType());

      await repo.appendEvents([
        CuratorEventDraft(
          eventId: 'evt-4',
          type: CuratorEventType.runSettled,
          occurredAtUtc: DateTime.utc(2026, 9, 12, 6, 4),
          payload: const {'earnedCoins': 800},
        ),
      ]);

      final raw = jsonDecode(
        prefs.getString(LocalPersistenceRepository.eventLogKey)!,
      ) as List<dynamic>;
      final types = raw.map((e) => (e as Map)['type']).toList();
      expect(types, [
        'profileCreated',
        'difficultySelected',
        'runSettled',
        'runSettled',
      ]);
    });

    test('真正損毀的日誌仍走備份路徑，未被前向相容放行', () async {
      await freshRepo('{ this is not json');

      final events = await repo.loadEvents();

      expect(events, isEmpty);
      expect(prefs.getKeys().where((k) => k.contains('bak')), isNotEmpty);
    });

    test('缺少必要欄位仍視為損毀，不當成未知種類吞掉', () async {
      await freshRepo(
        jsonEncode([
          {'type': 'somethingNew', 'payload': const <String, Object?>{}},
        ]),
      );

      final events = await repo.loadEvents();

      expect(events, isEmpty);
      expect(prefs.getKeys().where((k) => k.contains('bak')), isNotEmpty);
    });
  });
}
