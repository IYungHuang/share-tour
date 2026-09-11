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
  Future<void> appendEvents(List<CuratorEvent> events) async {
    if (events.isEmpty) return;
    final prefs = await _getPrefs();
    final existing = await loadEvents();
    final merged = [...existing, ...events];
    await prefs.setString(
      eventLogKey,
      jsonEncode(merged.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<CuratorSaveData> loadSave() async {
    final events = await loadEvents();
    if (events.isEmpty) {
      // 首次啟動：落地一筆身分事件，讓日誌自始即可重播。
      final genesis = CuratorEvent(
        eventId: _uuid.v4(),
        seq: 1,
        type: CuratorEventType.profileCreated,
        occurredAtUtc: DateTime.now().toUtc(),
        payload: {'profileId': _uuid.v4()},
      );
      await appendEvents([genesis]);
      return replayCuratorEvents([genesis]);
    }
    return replayCuratorEvents(events);
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
  }
}
