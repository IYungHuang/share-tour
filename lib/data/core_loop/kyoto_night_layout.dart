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

/// 4x8 蛇形網格像素座標生成
///
/// column: 0..3, row: 0..7
/// (x, y) = (160 + 224 * col, 112 + 112 * row)
/// 偶數 row: col 0 -> 3
/// 奇數 row: col 3 -> 0
Vector2 kyotoGridPixelForIndex(int index) {
  final row = index ~/ 4;
  final colInRow = index % 4;
  final col = (row % 2 == 0) ? colInRow : (3 - colInRow);
  final x = 160.0 + 224.0 * col;
  final y = 112.0 + 112.0 * row;
  return Vector2(x, y);
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
    final pixel = kyotoGridPixelForIndex(index);
    final geo = unproject(pixel);

    return DistrictAttraction(
      id: id,
      title: material.name,
      districtCode: 'kyoto_central',
      districtName: '京都夜間街區',
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
