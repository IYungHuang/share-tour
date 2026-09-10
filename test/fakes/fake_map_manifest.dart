import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';

/// 純數學圖資模組：不載入圖檔、不含真實地理資料。
///
/// 這是解耦驗收的核心（規格 §2.2、DoD-3）：若整條管線能只靠它測完，
/// 就代表沒有城市專屬邏輯洩漏進通用引擎。
class FakeMapManifest implements OverworldMapManifest {
  FakeMapManifest._({
    required Vector2 originPixel,
    required this.pixelsPerDegree,
    required this.varyScale,
    this.fixedMpp = 1.0,
    this.geoMinLat = minLat,
    this.geoMinLng = minLng,
  }) : _origin = originPixel;

  /// 等距線性投影，公尺/像素恆為 1.0。
  factory FakeMapManifest.linear({Vector2? originPixel}) => FakeMapManifest._(
        originPixel: originPixel ?? Vector2.zero(),
        pixelsPerDegree: 100.0,
        varyScale: false,
      );

  /// 公尺/像素隨 x 線性變化，用於驗證換算的求值契約（AC-6.8、AC-15.5）。
  factory FakeMapManifest.nonLinear() => FakeMapManifest._(
        originPixel: Vector2.zero(),
        pixelsPerDegree: 100.0,
        varyScale: true,
      );

  /// 固定但非 1.0 的比例，用於驗證公尺門檻的換算（AC-6.7）。
  factory FakeMapManifest.fixedScale(double metersPerPixel) => FakeMapManifest._(
        originPixel: Vector2.zero(),
        pixelsPerDegree: 100.0,
        varyScale: false,
        fixedMpp: metersPerPixel,
      );

  /// 地理原點可移動，用於驗證換層後落在新模組範圍外（AC-15.6）。
  factory FakeMapManifest.linearAt({
    required double minLat,
    required double minLng,
  }) =>
      FakeMapManifest._(
        originPixel: Vector2.zero(),
        pixelsPerDegree: 100.0,
        varyScale: false,
        geoMinLat: minLat,
        geoMinLng: minLng,
      );

  // 座標系：經緯度 (maxLat, minLng) 對應 originPixel，
  // 每度 100 像素，緯度往北 → y 減少。
  static const double minLat = 23.0;
  static const double maxLat = 25.0; // → 高 200 px
  static const double minLng = 120.0;
  static const double maxLng = 122.0; // → 寬 200 px

  final Vector2 _origin;
  final double pixelsPerDegree;
  final bool varyScale;
  final double fixedMpp;
  final double geoMinLat;
  final double geoMinLng;

  double get _maxLat => geoMinLat + 2.0;
  double get _maxLng => geoMinLng + 2.0;

  int projectCallCount = 0;
  void resetCallCounts() {
    projectCallCount = 0;
  }

  @override
  String get mapId => 'fake';
  @override
  String get assetPath => 'fake.png';
  @override
  Vector2 get mapDimensions => Vector2(400, 400);
  @override
  int get oceanColorArgb => 0xFF000080;
  @override
  Vector2 get defaultSpawnPixel => Vector2(10, 10);
  @override
  double get dpadSpeedPixelsPerSecond => 40;

  /// 兩個 POI，間距 150 px，遠大於觸發半徑總和。
  @override
  List<PoiMarker> get poiNodes => [
        PoiMarker(
            id: 'poi_a',
            pixel: _origin + Vector2(20, 20),
            triggerRadiusMeters: 50),
        PoiMarker(
            id: 'poi_b',
            pixel: _origin + Vector2(170, 20),
            triggerRadiusMeters: 50),
      ];

  @override
  List<DistrictAttraction> get districtAttractions => [
        DistrictAttraction(
          id: 'fake_spot_1',
          title: '假地標甲',
          districtCode: 'fake_district',
          districtName: '假行政區',
          geo: const GeoPoint(24.0, 121.0),
          pixel: _origin + Vector2(50, 50),
          rating: 4.8,
          reviewCount: 10000,
          category: AttractionCategory.landmark,
          minZoom: 1.0,
        ),
      ];

  @override
  List<AdministrativeDistrict> get administrativeDistricts => [
        AdministrativeDistrict(
          code: 'fake_district',
          name: '假行政區',
          centerGeo: const GeoPoint(24.0, 121.0),
          centerPixel: _origin + Vector2(50, 50),
        ),
      ];

  @override
  bool containsGeo(double lat, double lng) =>
      lat >= geoMinLat && lat <= _maxLat && lng >= geoMinLng && lng <= _maxLng;

  @override
  Vector2 projectToPixel(double lat, double lng) {
    projectCallCount++;
    return _origin +
        Vector2((lng - geoMinLng) * pixelsPerDegree,
            (_maxLat - lat) * pixelsPerDegree);
  }

  @override
  GeoPoint unprojectToGeo(Vector2 pixel) {
    final local = pixel - _origin;
    return GeoPoint(_maxLat - local.y / pixelsPerDegree,
        geoMinLng + local.x / pixelsPerDegree);
  }

  @override
  double metersPerPixelAt(Vector2 pixel) =>
      varyScale ? 1.0 + pixel.x / 1000.0 : fixedMpp;
}
