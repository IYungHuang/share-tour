import '../projection/map_manifest.dart';

/// 檢查任兩個 POI 之間是否滿足 REQ-C-18 規則 3 的幾何約束：
/// `d(A, B) > r_A + r_B + positionErrorBound`。
///
/// 推導：玩家於 A 的觸發範圍內任一點（距 A 最遠 r_A），量測點偏離真位置
/// 最多 positionErrorBound，要求量測點距 B 超過 r_B。本約束為**對稱**式
/// （含 r_A 與 r_B 兩項），故每對 POI 驗一次即可。它不保證 A 自身觸發得到
/// （偽陰性方向屬任務 A）。
///
/// [positionErrorBound] 必填、無預設值：安全裕度的大小應由誤觸發的代價
/// 決定，只有任務 A 知道那個代價；本函式不代為裁決。
///
/// 取代已刪除的 `findSnapTriggerConflicts`（原驗證道路節點與 POI 的間距，
/// 隨道路吸附整項刪除而失去對象——見 SPEC_C_AMENDMENT_01.md 修訂三）。
List<String> findPoiProximityConflicts({
  required List<PoiMarker> pois,
  required double positionErrorBound,
  required double metersPerPixel,
}) {
  final conflicts = <String>[];
  for (var i = 0; i < pois.length; i++) {
    for (var j = i + 1; j < pois.length; j++) {
      final a = pois[i];
      final b = pois[j];
      final metersApart = a.pixel.distanceTo(b.pixel) * metersPerPixel;
      final requiredMeters =
          a.triggerRadiusMeters + b.triggerRadiusMeters + positionErrorBound;
      if (metersApart <= requiredMeters) {
        conflicts.add('POI「${a.id}」與「${b.id}」僅相距 '
            '${metersApart.toStringAsFixed(1)} m，需大於 '
            '${requiredMeters.toStringAsFixed(1)} m');
      }
    }
  }
  return conflicts;
}
