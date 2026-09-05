import 'package:vector_math/vector_math.dart';

import '../../../domain/location/projection/map_manifest.dart';
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

  /// 反投影：像素 → 經緯度。
  ///
  /// IDW 不是自身的逆函數——正逆兩個方向都往錨點的加權均值收縮，所以把公式
  /// 對稱套用得不到原點。改用迭代修正：從錨點的像素距離加權平均起猜，
  /// 每輪以差分估計局部雅可比，把像素誤差換回度數。
  static GeoPoint invert(Vector2 target, List<GeoAnchor> anchors,
      {int maxIterations = 24, double tolerancePixels = 0.25}) {
    if (anchors.isEmpty) return const GeoPoint(0, 0);

    // 初猜：以像素距離的倒數平方加權
    double wSum = 0, lat = 0, lng = 0;
    for (final a in anchors) {
      final d2 = target.distanceToSquared(a.pixelPos);
      if (d2 < 1e-6) return GeoPoint(a.lat, a.lng);
      final w = 1.0 / d2;
      wSum += w;
      lat += a.lat * w;
      lng += a.lng * w;
    }
    lat /= wSum;
    lng /= wSum;

    const h = 0.0005; // 差分步長（度）
    for (var i = 0; i < maxIterations; i++) {
      final p = calculate(lat, lng, anchors);
      final err = target - p;
      if (err.length < tolerancePixels) break;

      final dLat = (calculate(lat + h, lng, anchors) - p) / h;
      final dLng = (calculate(lat, lng + h, anchors) - p) / h;

      // 解 2x2：[dLat dLng] · [dl, dg]^T = err
      final det = dLat.x * dLng.y - dLng.x * dLat.y;
      if (det.abs() < 1e-12) break;
      final dl = (err.x * dLng.y - dLng.x * err.y) / det;
      final dg = (dLat.x * err.y - err.x * dLat.y) / det;
      lat += dl;
      lng += dg;
    }
    return GeoPoint(lat, lng);
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
