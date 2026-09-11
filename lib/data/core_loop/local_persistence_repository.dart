import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/core_loop/events/curator_event.dart';
import '../../domain/core_loop/events/curator_event_replay.dart';
import '../../domain/core_loop/models/curator_save_data.dart';
import '../../domain/core_loop/models/persistence_repository.dart';

/// 使用 SharedPreferences 的本機事件日誌儲存庫實作 (CC-3 append-only)
///
/// 日誌以單一鍵值存放一個 JSON 陣列。[appendEvents] 只在陣列尾端追加，
/// 既有元素不被改寫；[loadSave] 重播整份日誌得出最終狀態。
class LocalPersistenceRepository implements PersistenceRepository {
  LocalPersistenceRepository({SharedPreferences? prefs, Uuid? uuid})
    : _prefs = prefs,
      _uuid = uuid ?? const Uuid();

  SharedPreferences? _prefs;
  final Uuid _uuid;

  /// 寫入串接鏈。SharedPreferences 沒有真正的 append API，追加只能「讀出整份 →
  /// 合併 → 整份寫回」。兩筆並行追加會讀到同一份舊資料，後寫的蓋掉前一筆，
  /// 事件就此消失。把寫入串成一條鏈，讓追加彼此互斥。
  Future<void> _writeChain = Future<void>.value();

  /// 事件日誌鍵值
  static const String eventLogKey = 'curator_event_log_v1';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<List<CuratorEvent>> loadEvents() async {
    final prefs = await _getPrefs();
    final rawJson = prefs.getString(eventLogKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawJson) as List<dynamic>;
      final events = decoded
          .map((e) => CuratorEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      events.sort((a, b) => a.seq.compareTo(b.seq));
      return events;
    } catch (e) {
      // 容錯機制：損毀日誌移至 .bak 備份，防止資料滅失並避免未捕捉崩潰。
      // 備份保留原文，日後仍可人工救回 (AC-M4-3.4)。
      await _backupCorrupted(prefs, rawJson, e);
      return const [];
    }
  }

  @override
  Future<List<CuratorEvent>> appendEvents(List<CuratorEventDraft> drafts) {
    if (drafts.isEmpty) return Future.value(const []);
    final queued = _writeChain.then((_) => _doAppend(drafts));
    // 一筆失敗不得讓後續追加全部連坐失敗，但錯誤仍要回傳給呼叫端。
    _writeChain = queued.catchError((Object _) => const <CuratorEvent>[]);
    return queued;
  }

  Future<List<CuratorEvent>> _doAppend(List<CuratorEventDraft> drafts) async {
    final prefs = await _getPrefs();
    final existing = await loadEvents();
    var nextSeq = existing.isEmpty ? 0 : existing.last.seq;
    final sealed = [for (final draft in drafts) draft.seal(++nextSeq)];
    final merged = [...existing, ...sealed];
    await prefs.setString(
      eventLogKey,
      jsonEncode(merged.map((e) => e.toJson()).toList()),
    );
    return sealed;
  }

  @override
  Future<CuratorSaveData> loadSave() async {
    final events = await loadEvents();
    if (events.isNotEmpty) {
      try {
        return replayCuratorEvents(events);
      } catch (e) {
        // 語法合法但語意壞掉的日誌 (缺身分事件、未知裝備種類) 會讓重播拋出。
        // 若讓它冒到 main()，玩家看到的是黑屏且無法自救，所以比照解析失敗
        // 備份後重建 —— 原文留在備份鍵裡，日後仍可人工救回。
        final prefs = await _getPrefs();
        final raw = prefs.getString(eventLogKey);
        if (raw != null) {
          await _backupCorrupted(prefs, raw, e);
        }
      }
    }

    // 首次啟動或日誌已損毀：落地一筆身分事件，讓日誌自始即可重播。
    final sealed = await appendEvents([
      CuratorEventDraft(
        eventId: _uuid.v4(),
        type: CuratorEventType.profileCreated,
        occurredAtUtc: DateTime.now().toUtc(),
        payload: {'profileId': _uuid.v4()},
      ),
    ]);
    return replayCuratorEvents(sealed);
  }

  @override
  Future<void> clearSave() async {
    final prefs = await _getPrefs();
    await prefs.remove(eventLogKey);
  }

  Future<void> _backupCorrupted(
    SharedPreferences prefs,
    String rawJson,
    Object error,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString('event_log_corrupted_$timestamp.bak', rawJson);
    await prefs.setString('event_log_corrupted_${timestamp}_reason', '$error');
    // 原鍵必須清掉，否則每次啟動都會再備份一次同一份壞資料，無限膨脹。
    await prefs.remove(eventLogKey);
  }
}
