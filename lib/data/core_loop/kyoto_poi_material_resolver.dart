import '../../domain/core_loop/models/poi_material_resolver.dart';
import '../../domain/core_loop/models/travel_material.dart';
import 'kyoto_night_catalog.dart';

final Map<String, TravelMaterial> _kyotoMaterialById = {
  for (final material in kyotoNightMaterials) material.id: material,
};

/// 嚴格京都 POI 旅行素材解析器 (Data DLC)
///
/// 將地圖上的景點 ID 精確映射至京都夜間素材庫 [kyotoNightMaterials]。
/// 未知景點 ID 一律回傳 `null`，禁止合成任何未定兜底素材。
class KyotoPoiMaterialResolver implements PoiMaterialResolver {
  const KyotoPoiMaterialResolver();

  @override
  TravelMaterial? resolveMaterialFor(String poiId) {
    return _kyotoMaterialById[poiId];
  }
}
