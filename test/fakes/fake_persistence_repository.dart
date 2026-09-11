import 'package:share_tour/domain/core_loop/events/curator_event.dart';
import 'package:share_tour/domain/core_loop/events/curator_event_replay.dart';
import 'package:share_tour/domain/core_loop/models/curator_save_data.dart';
import 'package:share_tour/domain/core_loop/models/persistence_repository.dart';

/// 事件日誌持久化純記憶體 Fake 實作 (供秒級單元測試)
class FakePersistenceRepository implements PersistenceRepository {
  FakePersistenceRepository({List<CuratorEvent>? initialEvents})
    : _events = [...?initialEvents];

  final List<CuratorEvent> _events;

  /// 模擬日誌損毀：讀取時回傳空日誌
  bool simulateCorruption = false;

  /// 模擬寫入失敗 (磁碟滿、平台通道錯誤)，驗證呼叫端不會靜默吞掉錯誤
  bool simulateWriteFailure = false;

  /// 追加呼叫次數
  int appendCount = 0;

  /// 已落地的事件 (唯讀檢視)
  List<CuratorEvent> get events => List.unmodifiable(_events);

  @override
  Future<List<CuratorEvent>> loadEvents() async {
    if (simulateCorruption) return const [];
    return List.unmodifiable(_events);
  }

  @override
  Future<List<CuratorEvent>> appendEvents(List<CuratorEventDraft> drafts) async {
    if (simulateWriteFailure) {
      throw StateError('模擬事件寫入失敗');
    }
    appendCount++;
    var nextSeq = _events.isEmpty ? 0 : _events.last.seq;
    final sealed = [for (final d in drafts) d.seal(++nextSeq)];
    _events.addAll(sealed);
    // Fake 主動守住不變量，否則它會比真實實作寬鬆，測試就失去意義。
    for (var i = 1; i < _events.length; i++) {
      assert(
        _events[i].seq > _events[i - 1].seq,
        'seq 必須嚴格遞增：${_events[i - 1].seq} → ${_events[i].seq}',
      );
    }
    return sealed;
  }

  @override
  Future<CuratorSaveData> loadSave() async {
    final events = await loadEvents();
    if (events.isEmpty) {
      final sealed = await appendEvents([
        CuratorEventDraft(
          eventId: 'fake-genesis',
          type: CuratorEventType.profileCreated,
          occurredAtUtc: DateTime.utc(2026, 1, 1),
          payload: const {'profileId': 'fake-profile'},
        ),
      ]);
      return replayCuratorEvents(sealed);
    }
    return replayCuratorEvents(events);
  }

  @override
  Future<void> clearSave() async {
    _events.clear();
  }
}
