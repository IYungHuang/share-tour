import '../../domain/location/models/geo_fix.dart';

/// 定位來源抽象。
///
/// 真實 GPS 與虛擬來源實作同一個介面，下游完全不知道差異——這正是整條管線
/// 能在沒有裝置的條件下被測試的原因，也是方向鍵玩法與除錯工具共用一條路徑
/// 的原因。
abstract class LocationSource {
  Stream<GeoFix> get fixes;
  Future<void> start();
  Future<void> stop();
}
