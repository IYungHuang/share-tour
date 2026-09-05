import 'package:vector_math/vector_math.dart';

import '../../../domain/location/projection/map_manifest.dart';
import '../models/geo_anchor.dart';
import '../utils/taiwan_geo_calibrator.dart';

/// 台灣圖資模組。
///
/// 現行底圖為【過渡資產】：以簡化的真實海岸線搭配等距投影生成，故公尺/像素
/// 為常數。最終手繪圖會重新引入非線性誇張，屆時錨點需重新量測，而
/// metersPerPixelAt 必須改為逐點計算。
class TaiwanMapManifest implements OverworldMapManifest {
  @override
  String get mapId => 'taiwan_overworld';

  String get displayName => 'TAIWAN: OVERWORLD';

  @override
  String get assetPath => 'taiwan_overworld.png';

  @override
  Vector2 get mapDimensions => Vector2(2048, 1152);

  @override
  int get oceanColorArgb => 0xFF1E6F9F;

  /// 自通用引擎搬來（PRE-7）：降落點是圖資的一部分，不是引擎的常數。
  @override
  Vector2 get defaultSpawnPixel => Vector2(1162, 148);

  /// 暫定值，由任務 D 依地方層尺度裁決。
  ///
  /// 以像素/秒表達而非真實速度：在 370 公尺/像素下，步行 5 km/h 要 4.4 分鐘
  /// 才移動一個像素，台北到高雄需連續操作近六小時。
  @override
  double get dpadSpeedPixelsPerSecond => 40;

  @override
  double get snapLimitMeters => 50;

  /// 過渡底圖為等距投影，故為常數；最終手繪圖需改為逐點計算。
  @override
  double metersPerPixelAt(Vector2 pixel) => 370.4;

  /// 校準錨點是台灣圖資的實作細節，不在通用契約上——通用引擎不需要、
  /// 也不應該知道某份圖資是用什麼方式做投影的。
  List<GeoAnchor> get anchors => [
        GeoAnchor(name: '基隆北端', lat: 25.150, lng: 121.750, pixelPos: Vector2(1213, 113)),
        GeoAnchor(name: '台北101', lat: 25.034, lng: 121.564, pixelPos: Vector2(1162, 148)),
        GeoAnchor(name: '台中歌劇院', lat: 24.163, lng: 120.640, pixelPos: Vector2(909, 408)),
        GeoAnchor(name: '日月潭', lat: 23.858, lng: 120.916, pixelPos: Vector2(985, 499)),
        GeoAnchor(name: '阿里山', lat: 23.510, lng: 120.803, pixelPos: Vector2(954, 603)),
        GeoAnchor(name: '台南赤崁樓', lat: 22.997, lng: 120.202, pixelPos: Vector2(789, 756)),
        GeoAnchor(name: '高雄85大樓', lat: 22.611, lng: 120.300, pixelPos: Vector2(816, 871)),
        GeoAnchor(name: '鵝鑾鼻南端', lat: 21.902, lng: 120.852, pixelPos: Vector2(967, 1083)),
      ];

  /// 觸發半徑暫定 50 公尺，最終數值由任務 A 裁決（PRE-10）。
  /// 原本是 35 像素——在此尺度下等於 12.96 公里，站在新竹就會觸發台北 101。
  @override
  List<PoiMarker> get poiNodes => [
        PoiMarker(id: 'taipei_101', pixel: Vector2(1162, 148), triggerRadiusMeters: 50),
        PoiMarker(id: 'taichung_opera', pixel: Vector2(909, 408), triggerRadiusMeters: 50),
        PoiMarker(id: 'sun_moon_lake', pixel: Vector2(985, 499), triggerRadiusMeters: 50),
        PoiMarker(id: 'kaohsiung_85', pixel: Vector2(816, 871), triggerRadiusMeters: 50),
      ];

  @override
  List<Vector2> get roadNodes => [
        Vector2(1162, 148),
        Vector2(909, 408),
        Vector2(985, 499),
        Vector2(789, 756),
        Vector2(816, 871),
      ];

  @override
  bool containsGeo(double lat, double lng) =>
      lat >= 21.4 && lat <= 25.7 && lng >= 119.7 && lng <= 122.3;

  @override
  Vector2 projectToPixel(double lat, double lng) =>
      TaiwanGeoCalibrator.calculate(lat, lng, anchors);

  @override
  GeoPoint unprojectToGeo(Vector2 pixel) =>
      TaiwanGeoCalibrator.invert(pixel, anchors);

  @override
  Vector2 snapToRoad(Vector2 pixel) => TaiwanGeoCalibrator.snapToRoad(
        pixel,
        roadNodes,
        threshold: snapLimitMeters / metersPerPixelAt(pixel),
      );
}
