import 'package:vector_math/vector_math.dart';

import '../../../data/core_loop/kyoto_night_layout.dart';
import '../../../domain/location/models/district_attraction.dart';
import '../../../domain/location/projection/map_manifest.dart';

/// 京都夜間街區圖資模組 (City as DLC, Commit 12, T10)
///
/// 1024x1024 獨立像素街區，以有界仿射轉換實現經緯度與像素互換。
/// 採集判定直接以像素半徑 (triggerRadiusPixels) 結算，不倚賴大地圖 mpp。
class KyotoNightMapManifest implements OverworldMapManifest {
  const KyotoNightMapManifest();

  static Future<KyotoNightMapManifest> load() async =>
      const KyotoNightMapManifest();

  static const double minLat = 34.8800;
  static const double maxLat = 35.0920;
  static const double minLng = 135.6600;
  static const double maxLng = 135.8200;

  @override
  String get mapId => 'kyoto_night_block';

  @override
  String get assetPath => 'kyoto_basin_overworld.png';

  @override
  Vector2 get mapDimensions => Vector2(1024, 1024);

  @override
  int get oceanColorArgb => 0xFF141E16;

  @override
  bool get hasOceanWaves => false;

  @override
  Vector2 get defaultSpawnPixel => kyotoSpawnPixel.clone();

  @override
  double get dpadSpeedPixelsPerSecond => kyotoDpadSpeedPixelsPerSecond;

  @override
  List<PoiMarker> get poiNodes => const [];

  @override
  List<DistrictAttraction> get districtAttractions =>
      buildKyotoNightAttractions(unproject: unprojectToGeo);

  @override
  List<AdministrativeDistrict> get administrativeDistricts => [
        AdministrativeDistrict(
          code: 'kyoto_nakagyo',
          name: '洛中・河原町街區',
          centerGeo: const GeoPoint(35.0060, 135.7680),
          centerPixel: Vector2(397.0, 434.0),
          minZoomForSpots: 0.5,
        ),
        AdministrativeDistrict(
          code: 'kyoto_higashiyama',
          name: '洛東・祇園清水街區',
          centerGeo: const GeoPoint(35.0000, 135.7780),
          centerPixel: Vector2(537.0, 561.0),
          minZoomForSpots: 0.5,
        ),
        AdministrativeDistrict(
          code: 'kyoto_sakyo',
          name: '洛東北・左京大文字街區',
          centerGeo: const GeoPoint(35.0300, 135.7850),
          centerPixel: Vector2(660.0, 240.0),
          minZoomForSpots: 0.5,
        ),
        AdministrativeDistrict(
          code: 'kyoto_arashiyama',
          name: '洛西・嵐山嵯峨街區',
          centerGeo: const GeoPoint(35.0200, 135.6800),
          centerPixel: Vector2(130.0, 293.0),
          minZoomForSpots: 0.5,
        ),
        AdministrativeDistrict(
          code: 'kyoto_fushimi_uji',
          name: '洛南・伏見宇治街區',
          centerGeo: const GeoPoint(34.9400, 135.7700),
          centerPixel: Vector2(416.0, 818.0),
          minZoomForSpots: 0.5,
        ),
      ];

  @override
  bool containsGeo(double lat, double lng) {
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  @override
  Vector2 projectToPixel(double lat, double lng) {
    final x = kyotoProjectLngToPixelX(lng);
    final y = kyotoProjectLatToPixelY(lat);
    return Vector2(x, y);
  }

  @override
  GeoPoint unprojectToGeo(Vector2 pixel) {
    final lat = kyotoUnprojectPixelYToLat(pixel.y);
    final lng = kyotoUnprojectPixelXToLng(pixel.x);
    return GeoPoint(lat, lng);
  }

  @override
  double metersPerPixelAt(Vector2 pixel) => 20.0;
}
