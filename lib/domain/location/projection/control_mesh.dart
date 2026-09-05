import 'package:vector_math/vector_math.dart';

import 'map_manifest.dart';

/// 一個校準控制點：真實經緯度與地圖像素的對應。
class ControlPoint {
  const ControlPoint({
    required this.name,
    required this.lat,
    required this.lng,
    required this.pixel,
  });

  final String name;
  final double lat;
  final double lng;
  final Vector2 pixel;
}

/// 控制網：控制點加上三角化。
///
/// 用三角形內的重心座標插值做投影，而不是反距離加權（IDW）。
///
/// IDW 的權重 1/d² 在控制點處發散，使插值函數在每個控制點附近變成**局部常數**
/// ——玩家走 100 公尺，投影位移是 0.00 像素。那不是可以調參數解決的瑕疵，而是
/// 該權重形式的必然結果：不論控制點怎麼佈、地圖怎麼畫，死區都在。
///
/// 重心座標插值沒有這個問題：
///   - 控制點處**精確**通過
///   - 三角形內部是**線性**的，局部解析度處處均勻
///   - 反投影是**閉式解**（在像素空間找三角形，用同一組權重回推經緯度），
///     不需迭代、不會不收斂
///   - 支援任意非線性誇張——手繪地圖要的正是這個
///
/// 三角化本身是**圖資資料**，由各圖資模組自行宣告：控制網怎麼佈，取決於那張圖
/// 哪裡誇張、哪裡忠實，通用引擎不需要知道。
class ControlMesh {
  const ControlMesh({required this.points, required this.triangles});

  final List<ControlPoint> points;

  /// 每個三角形是三個控制點的索引。
  final List<List<int>> triangles;

  Vector2 projectToPixel(double lat, double lng) {
    final (tri, weights) = _locate(
      target: Vector2(lng, lat),
      vertexOf: (i) => Vector2(points[i].lng, points[i].lat),
    );
    return _blend(tri, weights, (i) => points[i].pixel);
  }

  GeoPoint unprojectToGeo(Vector2 pixel) {
    final (tri, weights) = _locate(
      target: pixel,
      vertexOf: (i) => points[i].pixel,
    );
    final geo = _blend(tri, weights, (i) => Vector2(points[i].lng, points[i].lat));
    return GeoPoint(geo.y, geo.x);
  }

  /// 找出包含目標點的三角形並回傳其重心座標。
  ///
  /// 目標落在凸包外時，取「最不負」的那個三角形做線性外插，而不是拒絕。
  /// 玩家可能站在海上或圖資邊緣，投影仍必須有定義；是否算在範圍內由
  /// containsGeo 另行判定，那是不同的問題。
  (List<int>, Vector3) _locate({
    required Vector2 target,
    required Vector2 Function(int) vertexOf,
  }) {
    List<int>? best;
    Vector3? bestWeights;
    var bestScore = double.negativeInfinity;

    for (final tri in triangles) {
      final w = _barycentric(target, vertexOf(tri[0]), vertexOf(tri[1]), vertexOf(tri[2]));
      if (w == null) continue; // 退化三角形
      final score = [w.x, w.y, w.z].reduce((a, b) => a < b ? a : b);
      if (score >= 0) return (tri, w); // 命中
      if (score > bestScore) {
        bestScore = score;
        best = tri;
        bestWeights = w;
      }
    }
    return (best ?? triangles.first, bestWeights ?? Vector3(1, 0, 0));
  }

  Vector3? _barycentric(Vector2 p, Vector2 a, Vector2 b, Vector2 c) {
    final denom = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y);
    if (denom.abs() < 1e-15) return null;
    final u = ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / denom;
    final v = ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / denom;
    return Vector3(u, v, 1 - u - v);
  }

  Vector2 _blend(List<int> tri, Vector3 w, Vector2 Function(int) valueOf) =>
      valueOf(tri[0]) * w.x + valueOf(tri[1]) * w.y + valueOf(tri[2]) * w.z;
}
