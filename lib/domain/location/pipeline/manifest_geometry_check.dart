import 'package:vector_math/vector_math.dart';

import '../projection/map_manifest.dart';

/// 檢查道路節點與 POI 的幾何間距。
///
/// 吸附把玩家拉到最近的道路上。若道路節點就坐在 POI 上，吸附會把玩家瞬移到
/// POI 正中央，距離變成 0，於是必然落入觸發半徑——遭遇會從數公里外被觸發。
///
/// 正確的防護條件是這條幾何約束，不是「吸附上限小於觸發半徑」：後者在節點與
/// POI 同座標時完全擋不住，只給出一種安全的假象。
///
/// 門檻由呼叫端注入，因為觸發半徑的公尺數值屬遊戲設計（任務 A），不在此裁定。
/// 這讓「規則寫得對不對」與「某份圖資合不合格」成為兩個可分別驗證的問題。
List<String> findSnapTriggerConflicts({
  required List<Vector2> roadNodes,
  required List<PoiMarker> pois,
  required double snapLimitMeters,
  required double metersPerPixel,
}) {
  final conflicts = <String>[];
  for (final poi in pois) {
    final requiredMeters = poi.triggerRadiusMeters + snapLimitMeters;
    for (var i = 0; i < roadNodes.length; i++) {
      final metersApart = roadNodes[i].distanceTo(poi.pixel) * metersPerPixel;
      if (metersApart <= requiredMeters) {
        conflicts.add(
            '道路節點 #$i 距 POI「${poi.id}」僅 ${metersApart.toStringAsFixed(1)} m，'
            '需大於 ${requiredMeters.toStringAsFixed(1)} m');
      }
    }
  }
  return conflicts;
}
