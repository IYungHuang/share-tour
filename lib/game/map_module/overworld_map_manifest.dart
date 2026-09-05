import 'package:flame/extensions.dart';
import 'models/geo_anchor.dart';
import 'models/overworld_poi_node.dart';

/// 地圖資產包抽象介面 (Map Manifest Contract)
abstract class OverworldMapManifest {
  String get mapId;
  String get displayName;
  String get assetPath;
  Vector2 get mapDimensions;
  Color get oceanColor;

  List<GeoAnchor> get anchors;
  List<Vector2> get roadNodes;
  List<OverworldPoiNode> get poiNodes;

  /// 經緯度投影算法介面
  Vector2 projectGpsToPixel(double lat, double lng);
}
