import 'package:flame/extensions.dart';
import '../models/geo_anchor.dart';

class TaiwanGeoCalibrator {
  /// 採用反距離加權插值 (IDW) 計算非線性手繪地圖像素
  static Vector2 calculate(double lat, double lng, List<GeoAnchor> anchors) {
    if (anchors.isEmpty) return Vector2.zero();

    double totalWeight = 0.0;
    double targetX = 0.0;
    double targetY = 0.0;
    const double power = 2.0;

    for (final anchor in anchors) {
      final dLat = lat - anchor.lat;
      final dLng = lng - anchor.lng;
      final distSq = dLat * dLat + dLng * dLng;

      // 精確命中錨點座標，避免除以零
      if (distSq < 0.000001) {
        return anchor.pixelPos.clone();
      }

      final weight = 1.0 / (distSq * power);
      totalWeight += weight;
      targetX += anchor.pixelPos.x * weight;
      targetY += anchor.pixelPos.y * weight;
    }

    return Vector2(targetX / totalWeight, targetY / totalWeight);
  }

  /// 公路網吸附檢定 (Road Snapping)
  static Vector2 snapToRoad(Vector2 rawPixel, List<Vector2> roadNodes, {double threshold = 40.0}) {
    if (roadNodes.isEmpty) return rawPixel;

    Vector2 closestNode = roadNodes.first;
    double minDistance = rawPixel.distanceTo(closestNode);

    for (final node in roadNodes) {
      final dist = rawPixel.distanceTo(node);
      if (dist < minDistance) {
        minDistance = dist;
        closestNode = node;
      }
    }

    return minDistance <= threshold ? closestNode : rawPixel;
  }
}
