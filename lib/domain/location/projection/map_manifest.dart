import 'package:vector_math/vector_math.dart';

/// 一個地理座標點。
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

/// 地圖上的互動點。觸發半徑以【公尺】表達，不以像素——像素在非線性地圖上
/// 隨區域改變意義，35 像素在大地圖上是 13 公里。
class PoiMarker {
  const PoiMarker({
    required this.id,
    required this.pixel,
    required this.triggerRadiusMeters,
  });

  final String id;
  final Vector2 pixel;
  final double triggerRadiusMeters;
}

/// 圖資模組契約。「城市即實體 DLC」——底圖、投影、路網與範圍全部由外部注入，
/// 通用引擎不得含任何特定城市的演算法。
///
/// 刻意不做介面拆分：唯一需要隔離的框架型別是海洋顏色，改用 ARGB int 即可。
/// 為一個顏色欄位新增一整層繼承，擋不住任何已知會變的軸。
abstract class OverworldMapManifest {
  String get mapId;
  String get assetPath;
  Vector2 get mapDimensions;
  int get oceanColorArgb;

  /// 冷啟動的起始顯示點。不查詢平台的最後已知位置。
  Vector2 get defaultSpawnPixel;

  /// 方向鍵移動速度，以像素/秒表達。
  ///
  /// 不用真實世界速度：在 370 公尺/像素的大地圖上，步行 5 km/h 要 4.4 分鐘
  /// 才移動一個像素。速度屬於圖層的尺度，故由圖層宣告。
  double get dpadSpeedPixelsPerSecond;

  List<PoiMarker> get poiNodes;

  /// 地理範圍判定，由模組宣告的分類遮罩實作（修訂四，v6）。方向鍵驅動的
  /// 虛擬 Fix 與真實 GPS 的 Fix 共用同一條判定路徑，不得分歧。
  bool containsGeo(double lat, double lng);
  Vector2 projectToPixel(double lat, double lng);
  GeoPoint unprojectToGeo(Vector2 pixel);

  /// 該像素處的公尺/像素比例。非線性地圖上隨位置變化，故需帶位置查詢。
  double metersPerPixelAt(Vector2 pixel);
}
