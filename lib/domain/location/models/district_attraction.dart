import 'package:vector_math/vector_math.dart';
import '../projection/map_manifest.dart';

/// 景點類別（觀光打卡、歷史文化、自然生態、休閒娛樂、美食商圈、指標地標）
enum AttractionCategory {
  sightseeing, // 觀光打卡
  culture,     // 歷史文化 / 古蹟
  nature,      // 自然生態 / 國家公園 / 海岸
  recreation,  // 休閒娛樂 / 溫泉 / 樂園
  food,        // 特色美食 / 老街 / 夜市
  landmark,    // 標誌性地標
}

/// 地理行政區熱門旅遊景點模型
class DistrictAttraction {
  const DistrictAttraction({
    required this.id,
    required this.title,
    required this.districtCode,
    required this.districtName,
    required this.geo,
    required this.pixel,
    required this.rating,
    required this.reviewCount,
    required this.category,
    this.description = '',
    this.minZoom = 1.2,
    this.triggerRadiusMeters = 50.0,
  });

  /// 景點唯一代碼
  final String id;

  /// 景點名稱（如：高美濕地、中正紀念堂）
  final String title;

  /// 行政區代碼（如：taipei, taichung）
  final String districtCode;

  /// 行政區中文名稱（如：台北市、台中市）
  final String districtName;

  /// 真實地理座標
  final GeoPoint geo;

  /// 投影於地圖上的像素位置
  final Vector2 pixel;

  /// Google Maps 評分（例如 4.6）
  final double rating;

  /// Google Maps 評價數量（例如 62000）
  final int reviewCount;

  /// 景點類型
  final AttractionCategory category;

  /// 景點描述特色
  final String description;

  /// 顯示該景點所需的最低縮放階層（雙手放大時逐步揭露）
  /// - 0.5: 宏觀國家級地標
  /// - 1.2: 區域級主要景點
  /// - 1.8: 行政區熱門深度景點
  /// - 2.5+: 在地私房深度景點
  final double minZoom;

  /// 遭遇/打卡觸發半徑（公尺）
  final double triggerRadiusMeters;

  /// 計算與某像素座標的平面距離
  double distancePixelsTo(Vector2 targetPixel) => pixel.distanceTo(targetPixel);

  /// 轉為標準 POI Marker
  PoiMarker toPoiMarker() => PoiMarker(
        id: id,
        pixel: pixel.clone(),
        triggerRadiusMeters: triggerRadiusMeters,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DistrictAttraction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 地理行政區模型
class AdministrativeDistrict {
  const AdministrativeDistrict({
    required this.code,
    required this.name,
    required this.centerGeo,
    required this.centerPixel,
    this.minZoomForSpots = 1.2,
  });

  /// 行政區代碼
  final String code;

  /// 行政區名稱
  final String name;

  /// 中心經緯度
  final GeoPoint centerGeo;

  /// 中心像素座標
  final Vector2 centerPixel;

  /// 放大至何種縮放倍率時開始顯現該區密集景點
  final double minZoomForSpots;

  /// 計算相機中心距此行政區中心的像素距離
  double distanceToPixel(Vector2 point) => centerPixel.distanceTo(point);
}

/// 縮放過濾與行政區景點篩選邏輯
class AttractionFilter {
  /// 根據當前相機縮放階層過濾可見景點
  static List<DistrictAttraction> visibleAttractions({
    required List<DistrictAttraction> attractions,
    required double currentZoom,
  }) {
    return attractions
        .where((attraction) => currentZoom >= attraction.minZoom)
        .toList();
  }

  /// 篩選屬於特定行政區的景點
  static List<DistrictAttraction> byDistrict({
    required List<DistrictAttraction> attractions,
    required String districtCode,
  }) {
    return attractions
        .where((attraction) => attraction.districtCode == districtCode)
        .toList();
  }

  /// 根據相機中心像素尋找當前最聚焦的行政區
  static AdministrativeDistrict? findFocusedDistrict({
    required List<AdministrativeDistrict> districts,
    required Vector2 cameraCenter,
    double maxFocusDistancePixels = 300.0,
  }) {
    if (districts.isEmpty) return null;

    AdministrativeDistrict? closest;
    double minDistance = double.infinity;

    for (final district in districts) {
      final dist = district.distanceToPixel(cameraCenter);
      if (dist < minDistance) {
        minDistance = dist;
        closest = district;
      }
    }

    if (minDistance <= maxFocusDistancePixels) {
      return closest;
    }
    return null;
  }
}
