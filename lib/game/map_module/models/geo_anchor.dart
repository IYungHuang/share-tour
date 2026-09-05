import 'package:flame/extensions.dart';

/// 地理校準錨點：記錄真實經緯度與手繪地圖像素座標之對應關係
class GeoAnchor {
  final String name;
  final double lat;
  final double lng;
  final Vector2 pixelPos;

  const GeoAnchor({
    required this.name,
    required this.lat,
    required this.lng,
    required this.pixelPos,
  });
}
