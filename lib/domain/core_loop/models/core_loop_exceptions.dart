export 'material_inventory.dart' show InventoryFullException;

/// POI 本局已踩線異常
class PoiAlreadyGatheredException implements Exception {
  const PoiAlreadyGatheredException(this.poiId);
  final String poiId;

  @override
  String toString() => 'PoiAlreadyGatheredException: POI $poiId 本局已踩線，不可重複採集';
}

/// 阿導體力已透支異常
class CuratorExhaustedException implements Exception {
  const CuratorExhaustedException();

  @override
  String toString() => 'CuratorExhaustedException: 阿導體力已透支，無法繼續踩線取材';
}

/// POI 無可用素材異常
class PoiUnavailableException implements Exception {
  const PoiUnavailableException(this.poiId);
  final String poiId;

  @override
  String toString() => 'PoiUnavailableException: 景點 $poiId 無可採集之素材';
}

/// QTE 判定完成後，目標 POI 已與鎖定時不符（REQ-M5-07.1）。
///
/// 用擲例而非回傳 `null`：`gatherPoi()` 的既有呼叫端（未提供
/// `expectedPoiId`）不需要改動任何一行——這條例外只在提供了
/// `expectedPoiId` 且真的失配時才會被拋出。
class PoiTargetChangedException implements Exception {
  const PoiTargetChangedException(this.expectedPoiId, this.actualPoiId);
  final String expectedPoiId;
  final String? actualPoiId;

  @override
  String toString() =>
      'PoiTargetChangedException: 鎖定的 $expectedPoiId 已不是目前可取材的 POI'
      '（現為 $actualPoiId），本次取材取消';
}

/// 前置條件未滿足異常 (例如未選哲學即嘗試出發)
class PreconditionFailedException implements Exception {
  const PreconditionFailedException(this.message);
  final String message;

  @override
  String toString() => 'PreconditionFailedException: $message';
}

