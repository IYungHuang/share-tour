import '../models/curator_save_data.dart';
import 'curator_event.dart';

/// 由事件日誌重播出局外存檔狀態 (CC-3)。
///
/// 決定性保證：結果只由 [events] 決定。此函式不讀取當下時間、不使用亂數、
/// 不依賴任何外部狀態；相同的事件序列必定重播出全等的 [CuratorSaveData]。
/// 事件依 `seq` 排序後套用，因此輸入順序不影響結果。
CuratorSaveData replayCuratorEvents(Iterable<CuratorEvent> events) {
  // Dart 的 List.sort 不保證穩定，seq 撞號時 ordered.last 會是未定義的。
  // 以 eventId 當第二鍵給出全序，重播結果才真的與輸入順序無關。
  final ordered = events.toList()
    ..sort((a, b) {
      final bySeq = a.seq.compareTo(b.seq);
      return bySeq != 0 ? bySeq : a.eventId.compareTo(b.eventId);
    });
  if (ordered.isEmpty) {
    throw StateError('事件日誌為空，無法重播出玩家身分');
  }

  String? profileId;
  var coins = 0;
  var sneakersLevel = 1;
  var cameraLevel = 1;
  var waistBagLevel = 1;
  var completedRuns = 0;

  for (final event in ordered) {
    switch (event.type) {
      case CuratorEventType.profileCreated:
        profileId = event.payload['profileId'] as String?;
      case CuratorEventType.philosophyRerolled:
        coins -= (event.payload['cost'] as int?) ?? 0;
      case CuratorEventType.equipmentUpgraded:
        coins -= (event.payload['cost'] as int?) ?? 0;
        switch (event.payload['equipment'] as String?) {
          case 'sneakers':
            sneakersLevel += 1;
          case 'camera':
            cameraLevel += 1;
          case 'waistBag':
            waistBagLevel += 1;
          default:
            throw FormatException(
              '未知的裝備種類: ${event.payload['equipment']}',
            );
        }
      case CuratorEventType.runSettled:
        coins += (event.payload['earnedCoins'] as int?) ?? 0;
        completedRuns += 1;
    }
  }

  if (profileId == null) {
    throw StateError('事件日誌缺少 profileCreated，無法決定玩家身分');
  }

  return CuratorSaveData(
    profileId: profileId,
    lastMonotonicSeq: ordered.last.seq,
    coins: coins,
    sneakersLevel: sneakersLevel,
    cameraLevel: cameraLevel,
    waistBagLevel: waistBagLevel,
    completedRuns: completedRuns,
    // 時戳取自最後一個事件，而非重播當下，否則重播不再決定性。
    updatedAtUtc: ordered.last.occurredAtUtc,
  );
}
