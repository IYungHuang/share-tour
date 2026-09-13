import 'package:vector_math/vector_math.dart';
import '../../domain/location/models/district_attraction.dart';
import '../../domain/location/projection/map_manifest.dart';
import 'kyoto_night_catalog.dart';

/// 降落點像素座標 (AC-A1-4.1)
final Vector2 kyotoSpawnPixel = Vector2(128.0, 112.0);

/// 觸發窗口半徑像素 (AC-A1-4.2: 直徑 40px >= 40px/s * 0.25s = 10px)
const double kyotoTriggerRadiusPixels = 20.0;

/// 方向鍵移動速度 (像素/秒)
const double kyotoDpadSpeedPixelsPerSecond = 40.0;

/// 京都景點真實地理座標與行政分區元資料
class KyotoPoiGeoInfo {
  final String id;
  final double lat;
  final double lng;
  final String districtCode;
  final String districtName;

  const KyotoPoiGeoInfo({
    required this.id,
    required this.lat,
    required this.lng,
    required this.districtCode,
    required this.districtName,
  });
}

/// 京都夜間 32 處景點真實經緯度與所屬 5 大分區對照表
const List<KyotoPoiGeoInfo> kyotoPoiGeoTable = [
  // 1. 洛中・河原町街區 (Nakagyo / Shimogyo)
  KyotoPoiGeoInfo(
    id: 'kyoto_pontocho_cat',
    lat: 35.0063,
    lng: 135.7714,
    districtCode: 'kyoto_nakagyo',
    districtName: '洛中・河原町街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_ghost_vending',
    lat: 35.0051,
    lng: 135.7678,
    districtCode: 'kyoto_nakagyo',
    districtName: '洛中・河原町街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_kiyamachi_ramen',
    lat: 35.0042,
    lng: 135.7709,
    districtCode: 'kyoto_nakagyo',
    districtName: '洛中・河原町街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_sanjo_starbucks',
    lat: 35.0090,
    lng: 135.7718,
    districtCode: 'kyoto_nakagyo',
    districtName: '洛中・河原町街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_teramachi_record',
    lat: 35.0075,
    lng: 135.7669,
    districtCode: 'kyoto_nakagyo',
    districtName: '洛中・河原町街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_nishiki_closed',
    lat: 35.0050,
    lng: 135.7649,
    districtCode: 'kyoto_nakagyo',
    districtName: '洛中・河原町街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_inoda_coffee',
    lat: 35.0089,
    lng: 135.7629,
    districtCode: 'kyoto_nakagyo',
    districtName: '洛中・河原町街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_kyogoku_stand',
    lat: 35.0062,
    lng: 135.7675,
    districtCode: 'kyoto_nakagyo',
    districtName: '洛中・河原町街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_omiya_tachinomi',
    lat: 35.0036,
    lng: 135.7495,
    districtCode: 'kyoto_nakagyo',
    districtName: '洛中・河原町街區',
  ),

  // 2. 洛東・祇園清水街區 (Higashiyama)
  KyotoPoiGeoInfo(
    id: 'kyoto_gion_tatsumi',
    lat: 35.0055,
    lng: 135.7745,
    districtCode: 'kyoto_higashiyama',
    districtName: '洛東・祇園清水街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_gion_kappo',
    lat: 35.0031,
    lng: 135.7760,
    districtCode: 'kyoto_higashiyama',
    districtName: '洛東・祇園清水街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_shijo_bridge_busker',
    lat: 35.0037,
    lng: 135.7725,
    districtCode: 'kyoto_higashiyama',
    districtName: '洛東・祇園清水街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_chionin_stairs',
    lat: 35.0058,
    lng: 135.7828,
    districtCode: 'kyoto_higashiyama',
    districtName: '洛東・祇園清水街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_yasaka_pagoda',
    lat: 34.9985,
    lng: 135.7792,
    districtCode: 'kyoto_higashiyama',
    districtName: '洛東・祇園清水街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_ninenzaka_tatami',
    lat: 34.9992,
    lng: 135.7814,
    districtCode: 'kyoto_higashiyama',
    districtName: '洛東・祇園清水街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_hokanji_slope',
    lat: 34.9972,
    lng: 135.7810,
    districtCode: 'kyoto_higashiyama',
    districtName: '洛東・祇園清水街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_kiyomizu_stage',
    lat: 34.9949,
    lng: 135.7850,
    districtCode: 'kyoto_higashiyama',
    districtName: '洛東・祇園清水街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_rokuharamitsuji',
    lat: 34.9968,
    lng: 135.7728,
    districtCode: 'kyoto_higashiyama',
    districtName: '洛東・祇園清水街區',
  ),

  // 3. 洛東北・左京大文字街區 (Sakyo)
  KyotoPoiGeoInfo(
    id: 'kyoto_kamogawa_delta',
    lat: 35.0300,
    lng: 135.7718,
    districtCode: 'kyoto_sakyo',
    districtName: '洛東北・左京大文字街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_kamo_kamome',
    lat: 35.0125,
    lng: 135.7719,
    districtCode: 'kyoto_sakyo',
    districtName: '洛東北・左京大文字街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_murin_an_night_moss',
    lat: 35.0116,
    lng: 135.7877,
    districtCode: 'kyoto_sakyo',
    districtName: '洛東北・左京大文字街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_daimonji_night_hike',
    lat: 35.0250,
    lng: 135.8055,
    districtCode: 'kyoto_sakyo',
    districtName: '洛東北・左京大文字街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_takano_river_firefly',
    lat: 35.0360,
    lng: 135.7780,
    districtCode: 'kyoto_sakyo',
    districtName: '洛東北・左京大文字街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_ichijoji_ramen_street',
    lat: 35.0440,
    lng: 135.7890,
    districtCode: 'kyoto_sakyo',
    districtName: '洛東北・左京大文字街區',
  ),

  // 4. 洛西・嵐山嵯峨街區 (Ukyo / Kamigyo)
  KyotoPoiGeoInfo(
    id: 'kyoto_arashiyama_bamboo',
    lat: 35.0167,
    lng: 135.6713,
    districtCode: 'kyoto_arashiyama',
    districtName: '洛西・嵐山嵯峨街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_sagano_torokko',
    lat: 35.0189,
    lng: 135.6775,
    districtCode: 'kyoto_arashiyama',
    districtName: '洛西・嵐山嵯峨街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_kitano_tenmangu_market',
    lat: 35.0314,
    lng: 135.7352,
    districtCode: 'kyoto_arashiyama',
    districtName: '洛西・嵐山嵯峨街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_senbon_enmado',
    lat: 35.0315,
    lng: 135.7420,
    districtCode: 'kyoto_arashiyama',
    districtName: '洛西・嵐山嵯峨街區',
  ),

  // 5. 洛南・伏見宇治街區 (Fushimi / Uji)
  KyotoPoiGeoInfo(
    id: 'kyoto_fushimi_torii',
    lat: 34.9671,
    lng: 135.7727,
    districtCode: 'kyoto_fushimi_uji',
    districtName: '洛南・伏見宇治街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_shinsei_sake',
    lat: 34.9312,
    lng: 135.7608,
    districtCode: 'kyoto_fushimi_uji',
    districtName: '洛南・伏見宇治街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_ujigawa_night',
    lat: 34.9000,
    lng: 135.8080,
    districtCode: 'kyoto_fushimi_uji',
    districtName: '洛南・伏見宇治街區',
  ),
  KyotoPoiGeoInfo(
    id: 'kyoto_kurama_night_train',
    lat: 35.0800,
    lng: 135.7812,
    districtCode: 'kyoto_fushimi_uji',
    districtName: '洛南・伏見宇治街區',
  ),
];

final Map<String, KyotoPoiGeoInfo> kyotoPoiGeoMap = {
  for (final info in kyotoPoiGeoTable) info.id: info,
};

/// 宏觀京都盆地經度控制錨點（對齊手繪像素地圖特徵：西方山區、中央棋盤格、鴨川中軸、東山山麓、大文字山）
const List<double> kyotoLngAnchors = [
  135.6600, // 0.0: 西方山巒邊界（嵐山以西）
  135.6800, // 130.0: 嵐山嵯峨野風景區
  135.7400, // 240.0: 洛西北（北野天滿宮、千本閻魔堂）
  135.7495, // 368.0: 四條大宮（洛中西側町家街區起點，避免落入西側桂川河道）
  135.7600, // 380.0: 烏丸古城棋盤格中心
  135.7725, // 440.0: 鴨川中心水系軸線（四條大橋、河原町、先斗町河畔）
  135.7850, // 660.0: 洛東坡道與古寺群（祇園、八坂塔、二年坂、清水寺）
  135.8200, // 1024.0: 東方如意嶽與大文字山東界
];

const List<double> kyotoPixelXAnchors = [
  0.0,
  130.0,
  240.0,
  368.0,
  380.0,
  440.0,
  660.0,
  1024.0,
];

/// 將真實經度投影為宏觀地圖像素 X 座標（單調雙射分段線性配準）
double kyotoProjectLngToPixelX(double lng) {
  if (lng <= kyotoLngAnchors.first) return kyotoPixelXAnchors.first;
  if (lng >= kyotoLngAnchors.last) return kyotoPixelXAnchors.last;
  for (int i = 0; i < kyotoLngAnchors.length - 1; i++) {
    if (lng <= kyotoLngAnchors[i + 1]) {
      final t = (lng - kyotoLngAnchors[i]) /
          (kyotoLngAnchors[i + 1] - kyotoLngAnchors[i]);
      return kyotoPixelXAnchors[i] +
          t * (kyotoPixelXAnchors[i + 1] - kyotoPixelXAnchors[i]);
    }
  }
  return kyotoPixelXAnchors.last;
}

/// 將宏觀地圖像素 X 座標逆投影為真實經度（嚴格可逆，誤差 < 0.0001 px）
double kyotoUnprojectPixelXToLng(double x) {
  if (x <= kyotoPixelXAnchors.first) return kyotoLngAnchors.first;
  if (x >= kyotoPixelXAnchors.last) return kyotoLngAnchors.last;
  for (int i = 0; i < kyotoPixelXAnchors.length - 1; i++) {
    if (x <= kyotoPixelXAnchors[i + 1]) {
      final t = (x - kyotoPixelXAnchors[i]) /
          (kyotoPixelXAnchors[i + 1] - kyotoPixelXAnchors[i]);
      return kyotoLngAnchors[i] +
          t * (kyotoLngAnchors[i + 1] - kyotoLngAnchors[i]);
    }
  }
  return kyotoLngAnchors.last;
}

/// 宏觀京都盆地緯度控制錨點（對齊手繪像素地圖特徵：北方深山、鞍馬山區、一乘寺、出町柳三角洲、丸太町北門、三條商圈、錦市場核心、四條南緣、下京、伏見鳥居、伏見酒造、宇治川）
const List<double> kyotoLatAnchors = [
  35.0920, // 0.0: 北方深山山麓邊界（鞍馬以北北山林區）
  35.0800, // 55.0: 北方鞍馬深山
  35.0440, // 160.0: 左京一乘寺
  35.0300, // 240.0: 出町柳三角洲／北野
  35.0150, // 320.0: 平安京北城牆／丸太町
  35.0085, // 370.0: 三條商圈（星巴克、伊野田）
  35.0050, // 460.0: 洛中核心（錦市場、寺町通、新京極、幽靈自販機）
  35.0020, // 550.0: 四條南緣（四條大宮、先斗町南端、木屋町）
  34.9850, // 640.0: 下京區／京都站／東寺外城
  34.9670, // 730.0: 伏見稻荷千本鳥居
  34.9300, // 850.0: 伏見酒造運河區
  34.8800, // 1024.0: 南方宇治川南緣
];

const List<double> kyotoPixelYAnchors = [
  0.0,
  55.0,
  160.0,
  240.0,
  320.0,
  370.0,
  460.0,
  550.0,
  640.0,
  730.0,
  850.0,
  1024.0,
];

/// 將真實緯度投影為宏觀地圖像素 Y 座標（單調雙射分段線性配準）
double kyotoProjectLatToPixelY(double lat) {
  if (lat >= kyotoLatAnchors.first) return kyotoPixelYAnchors.first;
  if (lat <= kyotoLatAnchors.last) return kyotoPixelYAnchors.last;
  for (int i = 0; i < kyotoLatAnchors.length - 1; i++) {
    if (lat >= kyotoLatAnchors[i + 1]) {
      final t = (kyotoLatAnchors[i] - lat) /
          (kyotoLatAnchors[i] - kyotoLatAnchors[i + 1]);
      return kyotoPixelYAnchors[i] +
          t * (kyotoPixelYAnchors[i + 1] - kyotoPixelYAnchors[i]);
    }
  }
  return kyotoPixelYAnchors.last;
}

/// 將宏觀地圖像素 Y 座標逆投影為真實緯度（嚴格可逆，誤差 < 0.0001 px）
double kyotoUnprojectPixelYToLat(double y) {
  if (y <= kyotoPixelYAnchors.first) return kyotoLatAnchors.first;
  if (y >= kyotoPixelYAnchors.last) return kyotoLatAnchors.last;
  for (int i = 0; i < kyotoPixelYAnchors.length - 1; i++) {
    if (y <= kyotoPixelYAnchors[i + 1]) {
      final t = (y - kyotoPixelYAnchors[i]) /
          (kyotoPixelYAnchors[i + 1] - kyotoPixelYAnchors[i]);
      return kyotoLatAnchors[i] -
          t * (kyotoLatAnchors[i] - kyotoLatAnchors[i + 1]);
    }
  }
  return kyotoLatAnchors.last;
}

/// 依真實地理經緯度投影至 1024x1024 地圖像素座標（分段美術雙軸配準）
Vector2 kyotoPixelForSpotId(String id) {
  final info = kyotoPoiGeoMap[id];
  if (info == null) {
    throw ArgumentError('未知的京都 POI ID: $id');
  }

  final x = kyotoProjectLngToPixelX(info.lng);
  final y = kyotoProjectLatToPixelY(info.lat);
  return Vector2(x, y);
}

/// 相容既有索引介面（依 deterministicKyotoCardOrder 映射至真實地理像素座標）
Vector2 kyotoGridPixelForIndex(int index) {
  final order = deterministicKyotoCardOrder;
  if (index >= 0 && index < order.length) {
    return kyotoPixelForSpotId(order[index]);
  }
  return Vector2(128.0, 112.0);
}

/// 依規範決定京都 32 張素材的網格排布順序：
/// 1. 前 6 格：所有「6 張採後 HP > 0 (總體力 < 100)」組合中，排序後 ID 字典序第一組
/// 2. 後 26 格：其餘卡按 ID 字典序排列
List<String> get deterministicKyotoCardOrder {
  const first6 = [
    'kyoto_arashiyama_bamboo', // risk 4, 24 HP
    'kyoto_chionin_stairs',     // risk 1, 6 HP
    'kyoto_daimonji_night_hike',// risk 5, 30 HP
    'kyoto_fushimi_torii',      // risk 4, 24 HP
    'kyoto_gion_kappo',         // risk 1, 6 HP
    'kyoto_gion_tatsumi',       // risk 1, 6 HP
    // Total HP cost = 96, HP remaining = 4 > 0
  ];
  final first6Set = first6.toSet();

  final remaining = kyotoNightMaterials
      .map((m) => m.id)
      .where((id) => !first6Set.contains(id))
      .toList()
    ..sort();

  return [...first6, ...remaining];
}

/// 建立京都夜間街區景點清單
List<DistrictAttraction> buildKyotoNightAttractions({
  required GeoPoint Function(Vector2 pixel) unproject,
}) {
  final materialById = {for (final m in kyotoNightMaterials) m.id: m};
  final order = deterministicKyotoCardOrder;

  return List.generate(order.length, (index) {
    final id = order[index];
    final material = materialById[id]!;
    final geoInfo = kyotoPoiGeoMap[id]!;
    final pixel = kyotoPixelForSpotId(id);
    final geo = GeoPoint(geoInfo.lat, geoInfo.lng);

    return DistrictAttraction(
      id: id,
      title: material.name,
      districtCode: geoInfo.districtCode,
      districtName: geoInfo.districtName,
      geo: geo,
      pixel: pixel,
      rating: 4.8,
      reviewCount: 1000,
      category: material.isSpotlight
          ? AttractionCategory.landmark
          : AttractionCategory.sightseeing,
      description: material.description,
      minZoom: 0.5,
      triggerRadiusMeters: 50.0,
      triggerRadiusPixels: kyotoTriggerRadiusPixels,
    );
  });
}
