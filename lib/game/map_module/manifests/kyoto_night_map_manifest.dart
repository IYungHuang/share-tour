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
          centerPixel: Vector2(400.0, 430.0),
          additionalCenters: [
            Vector2(420.0, 480.0), // 先斗町・木屋町鴨川西岸聚類
            Vector2(430.0, 370.0), // 三條星巴克納涼床聚類
            Vector2(368.0, 500.0), // 四條大宮立飲町家街區聚類
          ],
          minZoomForSpots: 0.5,
          radiusPixels: 140.0,
        ),
        AdministrativeDistrict(
          code: 'kyoto_higashiyama',
          name: '洛東・祇園清水街區',
          centerGeo: const GeoPoint(35.0000, 135.7780),
          centerPixel: Vector2(580.0, 560.0),
          additionalCenters: [
            Vector2(670.0, 525.0), // 知恩院三門巨大石階聚類
            Vector2(615.0, 435.0), // 祇園白川辰巳大明神聚類
            Vector2(625.0, 485.0), // 祇園末吉町割烹聚類
            Vector2(610.0, 615.0), // 六波羅蜜寺聚類
            Vector2(580.0, 416.0), // 四條大橋街頭藝人聚類
            Vector2(640.0, 560.0), // 二年坂・法觀寺・清水舞台坡道聚類
            Vector2(785.0, 575.0), // 八坂之塔東山五重塔聚類
          ],
          minZoomForSpots: 0.5,
          radiusPixels: 140.0,
        ),
        AdministrativeDistrict(
          code: 'kyoto_sakyo',
          name: '洛東北・左京大文字街區',
          centerGeo: const GeoPoint(35.0300, 135.7850),
          centerPixel: Vector2(560.0, 220.0),
          additionalCenters: [
            Vector2(660.0, 175.0), // 一乘寺拉麵激戰區
            Vector2(788.0, 205.0), // 大文字山「大」字火床夜爬
            Vector2(692.0, 302.0), // 無鄰菴青苔庭園
            Vector2(436.6, 240.0), // 出町柳鴨川三角洲
            Vector2(437.1, 339.2), // 鴨川跳石千鳥水系
            Vector2(620.0, 215.0), // 高野川夜行賞螢
          ],
          minZoomForSpots: 0.5,
          radiusPixels: 140.0,
        ),
        AdministrativeDistrict(
          code: 'kyoto_arashiyama',
          name: '洛西・嵐山嵯峨街區',
          centerGeo: const GeoPoint(35.0200, 135.6800),
          centerPixel: Vector2(100.0, 310.0),
          additionalCenters: [
            Vector2(250.0, 225.0), // 北野天滿宮・千本閻魔堂洛西古道
          ],
          minZoomForSpots: 0.5,
          radiusPixels: 140.0,
        ),
        AdministrativeDistrict(
          code: 'kyoto_fushimi_uji',
          name: '洛南・伏見宇治街區',
          centerGeo: const GeoPoint(34.9400, 135.7700),
          centerPixel: Vector2(416.0, 780.0),
          additionalCenters: [
            Vector2(670.0, 900.0), // 伏見稻荷千本鳥居步道聚類
            Vector2(420.0, 850.0), // 伏見清酒老窖酒造聚類
            Vector2(899.2, 954.4), // 宇治川浮島鵜飼聚類中心
            Vector2(593.1, 55.0),   // 鞍馬深山夜行列車衛星中心
          ],
          minZoomForSpots: 0.5,
          radiusPixels: 140.0,
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
