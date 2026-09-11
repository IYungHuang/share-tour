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
