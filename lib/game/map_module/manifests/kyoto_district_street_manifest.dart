import 'package:vector_math/vector_math.dart';

import '../../../data/core_loop/kyoto_night_catalog.dart';
import '../../../data/core_loop/kyoto_night_layout.dart';
import '../../../domain/location/models/district_attraction.dart';
import '../../../domain/location/projection/map_manifest.dart';

/// 京都五大行政區中觀散步街區枚舉
enum KyotoDistrictType {
  nakagyo(
    code: 'kyoto_nakagyo',
    name: '洛中・河原町街區',
    hudLabel: 'KYOTO: NAKAGYO MACHIYA',
    badgeIcon: '🏮',
    spotCount: 9,
    description: '町家、霓虹夜市、立飲與居酒屋',
    assetPath: 'kyoto_night_block.png',
    defaultSpawnX: 512.0,
    defaultSpawnY: 512.0,
    minLat: 35.0000,
    maxLat: 35.0120,
    minLng: 135.7480,
    maxLng: 135.7760,
  ),
  higashiyama(
    code: 'kyoto_higashiyama',
    name: '洛東・祇園清水街區',
    hudLabel: 'KYOTO: HIGASHIYAMA STONE',
    badgeIcon: '⛩️',
    spotCount: 9,
    description: '石疊坡道、傳統木造茶屋與千年月夜古剎',
    assetPath: 'kyoto_higashiyama_block.png',
    defaultSpawnX: 512.0,
    defaultSpawnY: 680.0,
    minLat: 34.9920,
    maxLat: 35.0080,
    minLng: 135.7700,
    maxLng: 135.7880,
  ),
  arashiyama(
    code: 'kyoto_arashiyama',
    name: '洛西・嵐山嵯峨街區',
    hudLabel: 'KYOTO: ARASHIYAMA BAMBOO',
    badgeIcon: '🎋',
    spotCount: 4,
    description: '幽靜竹林道、柴油小火車與古老神域',
    assetPath: 'kyoto_arashiyama_block.png',
    defaultSpawnX: 480.0,
    defaultSpawnY: 600.0,
    minLat: 35.0140,
    maxLat: 35.0340,
    minLng: 135.6680,
    maxLng: 135.7450,
  ),
  sakyo(
    code: 'kyoto_sakyo',
    name: '洛東北・左京大文字街區',
    hudLabel: 'KYOTO: SAKYO DAIMONJI',
    badgeIcon: '⛰️',
    spotCount: 6,
    description: '鴨川跳烏龜、大文字夜行眺望與拉麵激戰區',
    assetPath: 'kyoto_sakyo_block.png',
    defaultSpawnX: 512.0,
    defaultSpawnY: 780.0,
    minLat: 35.0100,
    maxLat: 35.0460,
    minLng: 135.7680,
    maxLng: 135.8080,
  ),
  fushimiUji(
    code: 'kyoto_fushimi_uji',
    name: '洛南・伏見宇治街區',
    hudLabel: 'KYOTO: FUSHIMI TORII',
    badgeIcon: '🍶',
    spotCount: 4,
    description: '朱紅千本鳥居迴廊、清酒酒藏白壁與宇治川',
    assetPath: 'kyoto_fushimi_block.png',
    defaultSpawnX: 460.0,
    defaultSpawnY: 680.0,
    minLat: 34.8950,
    maxLat: 35.0820,
    minLng: 135.7550,
    maxLng: 135.8120,
  );

  const KyotoDistrictType({
    required this.code,
    required this.name,
    required this.hudLabel,
    required this.badgeIcon,
    required this.spotCount,
    required this.description,
    required this.assetPath,
    required this.defaultSpawnX,
    required this.defaultSpawnY,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final String code;
  final String name;
  final String hudLabel;
  final String badgeIcon;
  final int spotCount;
  final String description;
  final String assetPath;
  final double defaultSpawnX;
  final double defaultSpawnY;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  Vector2 get defaultSpawnPixel => Vector2(defaultSpawnX, defaultSpawnY);

  static KyotoDistrictType? fromCode(String code) {
    for (final type in values) {
      if (type.code == code || code.contains(type.code)) {
        return type;
      }
    }
    return null;
  }
}

/// 京都中觀街區圖資模組（支援五大行政分區）
///
/// 每個分區以專屬 1024x1024 獨立像素街區呈現所屬 POI 景點，
/// 解決宏觀與中觀的尺度崩潰問題。
class KyotoDistrictStreetManifest implements OverworldMapManifest {
  const KyotoDistrictStreetManifest(this.districtType);

  final KyotoDistrictType districtType;

  @override
  String get mapId => districtType == KyotoDistrictType.nakagyo
      ? 'kyoto_street_block'
      : 'kyoto_street_${districtType.code}';

  @override
  String get assetPath => districtType.assetPath;

  @override
  Vector2 get mapDimensions => Vector2(1024, 1024);

  @override
  int get oceanColorArgb => 0xFF10141E;

  @override
  bool get hasOceanWaves => false;

  @override
  Vector2 get defaultSpawnPixel => districtType.defaultSpawnPixel;

  @override
  double get dpadSpeedPixelsPerSecond => 40.0;

  @override
  List<PoiMarker> get poiNodes => const [];

  @override
  List<DistrictAttraction> get districtAttractions => _buildStreetAttractions();

  @override
  List<AdministrativeDistrict> get administrativeDistricts => [
        AdministrativeDistrict(
          code: '${districtType.code}_block',
          name: districtType.name,
          centerGeo: GeoPoint(
            (districtType.minLat + districtType.maxLat) / 2,
            (districtType.minLng + districtType.maxLng) / 2,
          ),
          centerPixel: districtType.defaultSpawnPixel,
          minZoomForSpots: 0.5,
        ),
      ];

  static final Map<String, Vector2> _allStreetSpotPixels = {
    // 1. 洛中・河原町街區 (Nakagyo, 9)
    'kyoto_sanjo_starbucks': Vector2(760.0, 240.0),
    'kyoto_pontocho_cat': Vector2(680.0, 360.0),
    'kyoto_kiyamachi_ramen': Vector2(680.0, 520.0),
    'kyoto_teramachi_record': Vector2(420.0, 340.0),
    'kyoto_inoda_coffee': Vector2(280.0, 260.0),
    'kyoto_nishiki_closed': Vector2(320.0, 580.0),
    'kyoto_kyogoku_stand': Vector2(480.0, 560.0),
    'kyoto_ghost_vending': Vector2(560.0, 720.0),
    'kyoto_omiya_tachinomi': Vector2(180.0, 750.0),

    // 2. 洛東・祇園清水街區 (Higashiyama, 9)
    'kyoto_yasaka_pagoda': Vector2(720.0, 200.0),
    'kyoto_hokanji_slope': Vector2(600.0, 420.0),
    'kyoto_kiyomizu_stage': Vector2(400.0, 320.0),
    'kyoto_gion_kappo': Vector2(220.0, 520.0),
    'kyoto_chionin_stairs': Vector2(440.0, 620.0),
    'kyoto_ninenzaka_tatami': Vector2(820.0, 680.0),
    'kyoto_rokuharamitsuji': Vector2(200.0, 680.0),
    'kyoto_shijo_bridge_busker': Vector2(460.0, 720.0),
    'kyoto_gion_tatsumi': Vector2(240.0, 840.0),

    // 3. 洛西・嵐山嵯峨街區 (Arashiyama, 4)
    'kyoto_arashiyama_bamboo': Vector2(550.0, 320.0),
    'kyoto_kitano_tenmangu_market': Vector2(850.0, 520.0),
    'kyoto_senbon_enmado': Vector2(220.0, 520.0),
    'kyoto_sagano_torokko': Vector2(380.0, 650.0),

    // 4. 洛東北・左京大文字街區 (Sakyo, 6)
    'kyoto_daimonji_night_hike': Vector2(640.0, 150.0),
    'kyoto_kamo_kamome': Vector2(175.0, 555.0), // 鴨川西岸散步道長椅與復古路燈旁（脫離深藍河水中央）
    'kyoto_kamogawa_delta': Vector2(490.0, 490.0),
    'kyoto_ichijoji_ramen_street': Vector2(480.0, 650.0),
    'kyoto_takano_river_firefly': Vector2(780.0, 720.0),
    'kyoto_murin_an_night_moss': Vector2(240.0, 820.0),

    // 5. 洛南・伏見宇治街區 (Fushimi/Uji, 4)
    'kyoto_shinsei_sake': Vector2(200.0, 320.0),
    'kyoto_fushimi_torii': Vector2(620.0, 580.0),
    'kyoto_kurama_night_train': Vector2(360.0, 780.0),
    'kyoto_ujigawa_night': Vector2(480.0, 840.0),
  };

  List<DistrictAttraction> _buildStreetAttractions() {
    final materialById = {for (final m in kyotoNightMaterials) m.id: m};

    final districtPois = kyotoPoiGeoTable
        .where((info) => info.districtCode == districtType.code)
        .toList();

    return districtPois.map((geoInfo) {
      final id = geoInfo.id;
      final pixel = _allStreetSpotPixels[id] ?? Vector2(512.0, 512.0);
      final material = materialById[id]!;
      final geo = GeoPoint(geoInfo.lat, geoInfo.lng);

      return DistrictAttraction(
        id: id,
        title: material.name,
        districtCode: '${districtType.code}_block',
        districtName: districtType.name,
        geo: geo,
        pixel: pixel,
        rating: 4.8,
        reviewCount: 1200,
        category: material.isSpotlight
            ? AttractionCategory.landmark
            : AttractionCategory.sightseeing,
        description: material.description,
        minZoom: 0.5,
        triggerRadiusMeters: 25.0,
        triggerRadiusPixels: 25.0,
      );
    }).toList();
  }

  @override
  bool containsGeo(double lat, double lng) {
    return lat >= districtType.minLat &&
        lat <= districtType.maxLat &&
        lng >= districtType.minLng &&
        lng <= districtType.maxLng;
  }

  @override
  Vector2 projectToPixel(double lat, double lng) {
    final x = (lng - districtType.minLng) /
        (districtType.maxLng - districtType.minLng) *
        1024.0;
    final y = (districtType.maxLat - lat) /
        (districtType.maxLat - districtType.minLat) *
        1024.0;
    return Vector2(x, y);
  }

  @override
  GeoPoint unprojectToGeo(Vector2 pixel) {
    final lat = districtType.maxLat -
        (pixel.y / 1024.0) * (districtType.maxLat - districtType.minLat);
    final lng = districtType.minLng +
        (pixel.x / 1024.0) * (districtType.maxLng - districtType.minLng);
    return GeoPoint(lat, lng);
  }

  @override
  double metersPerPixelAt(Vector2 pixel) => 1.0;
}
