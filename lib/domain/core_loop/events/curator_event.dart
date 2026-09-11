/// 局外進度事件種類 (CC-3 append-only 事件日誌)
enum CuratorEventType {
  /// 首次建立玩家檔案，payload: {profileId}
  profileCreated,

  /// 靈感重擲，payload: {cost}
  philosophyRerolled,

  /// 黑市裝備升級，payload: {equipment, cost}
  equipmentUpgraded,

  /// 單局結算收下佣金，payload: {earnedCoins}
  runSettled,
}

/// 尚未編號的事件草稿。
///
/// `seq` 是**日誌的屬性**，不是操作的屬性：它必須由持有日誌的一方決定，
/// 否則呼叫端得自行猜測「日誌現在到第幾號」，而那份猜測來自另一個可獨立
/// 覆寫的來源，兩者一旦脫鉤就會撞號，撞號則重播順序未定義。
///
/// 讓呼叫端只能產生草稿，它就無從指定 `seq`，這個耦合在型別上即不存在。
class CuratorEventDraft {
  CuratorEventDraft({
    required this.eventId,
    required this.type,
    required this.occurredAtUtc,
    this.payload = const {},
  }) : assert(occurredAtUtc.isUtc, 'occurredAtUtc must be in UTC');

  final String eventId;
  final CuratorEventType type;
  final DateTime occurredAtUtc;
  final Map<String, Object?> payload;

  /// 由日誌編號後封緘為正式事件。
  CuratorEvent seal(int seq) => CuratorEvent(
    eventId: eventId,
    seq: seq,
    type: type,
    occurredAtUtc: occurredAtUtc,
    payload: payload,
  );
}

/// 局外進度事件 (CC-1 UUID 識別、CC-2 UTC 時戳、CC-3 一經寫入不得修改)
///
/// 事件是存檔的唯一真實來源；最終狀態一律由 [replayCuratorEvents] 重播得出。
/// payload 不得攜帶原始 GPS 座標 (CC-5)。
class CuratorEvent {
  CuratorEvent({
    required this.eventId,
    required this.seq,
    required this.type,
    required this.occurredAtUtc,
    this.payload = const {},
  }) : assert(occurredAtUtc.isUtc, 'occurredAtUtc must be in UTC'),
       assert(seq >= 1, 'seq 為 1 起算的單調序號');

  /// 事件唯一識別 (UUID v4, CC-1)
  final String eventId;

  /// 單調遞增序號，決定重播順序
  final int seq;

  final CuratorEventType type;

  /// 事件發生時間 (UTC, CC-2)
  final DateTime occurredAtUtc;

  /// 事件酬載。重播只讀此處，不得依賴任何外部狀態 (CC-3)
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'eventId': eventId,
    'seq': seq,
    'type': type.name,
    'occurredAtUtc': occurredAtUtc.toIso8601String(),
    'payload': payload,
  };

  factory CuratorEvent.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String?;
    if (rawType == null) {
      throw const FormatException('事件缺少 type 欄位');
    }
    final type = CuratorEventType.values.where((t) => t.name == rawType);
    if (type.isEmpty) {
      throw FormatException('未知的事件種類: $rawType');
    }
    final rawOccurred = json['occurredAtUtc'] as String?;
    final eventId = json['eventId'] as String?;
    final seq = json['seq'] as int?;
    if (rawOccurred == null || eventId == null || seq == null) {
      throw const FormatException('事件缺少 eventId / seq / occurredAtUtc 欄位');
    }

    return CuratorEvent(
      eventId: eventId,
      seq: seq,
      type: type.first,
      occurredAtUtc: DateTime.parse(rawOccurred).toUtc(),
      payload: Map<String, Object?>.from(
        (json['payload'] as Map?) ?? const <String, Object?>{},
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CuratorEvent &&
          other.eventId == eventId &&
          other.seq == seq &&
          other.type == type &&
          other.occurredAtUtc == occurredAtUtc &&
          _payloadEquals(other.payload, payload);

  @override
  int get hashCode => Object.hash(eventId, seq, type, occurredAtUtc);

  static bool _payloadEquals(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() => 'CuratorEvent(#$seq ${type.name} @$occurredAtUtc)';
}
