import 'package:flame/extensions.dart';
import '../overworld_map_manifest.dart';
import '../models/geo_anchor.dart';
import '../models/overworld_poi_node.dart';
import '../utils/taiwan_geo_calibrator.dart';

class TaiwanMapManifest implements OverworldMapManifest {
  @override
  String get mapId => 'taiwan_overworld';

  @override
  String get displayName => 'TAIWAN: OVERWORLD';

  @override
  String get assetPath => 'taiwan_overworld.png';

  @override
  Vector2 get mapDimensions => Vector2(2048, 1152);

  @override
  Color get oceanColor => const Color(0xFF1E6F9F);

  @override
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

  @override
  List<OverworldPoiNode> get poiNodes => [
    OverworldPoiNode(
      id: 'taipei_101',
      title: '台北 101',
      pixelPosition: Vector2(1162, 148),
      encounterType: EncounterType.boss,
    ),
    OverworldPoiNode(
      id: 'taichung_opera',
      title: '台中歌劇院',
      pixelPosition: Vector2(909, 408),
      encounterType: EncounterType.sightseeing,
    ),
    OverworldPoiNode(
      id: 'sun_moon_lake',
      title: '日月潭',
      pixelPosition: Vector2(985, 499),
      encounterType: EncounterType.rest,
    ),
    OverworldPoiNode(
      id: 'kaohsiung_85',
      title: '高雄 85 大樓',
      pixelPosition: Vector2(816, 871),
      encounterType: EncounterType.shop,
    ),
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
  Vector2 projectGpsToPixel(double lat, double lng) {
    return TaiwanGeoCalibrator.calculate(lat, lng, anchors);
  }
}
