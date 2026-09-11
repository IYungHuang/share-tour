import 'travel_material.dart';

/// 景點素材解析器純領域介面
///
/// 遵循「城市即實體 DLC」原則，通用引擎透過此介面依據 POI ID
/// 解析對應的旅行素材卡牌，通用層零具名城市依賴。
abstract class PoiMaterialResolver {
  TravelMaterial? resolveMaterialFor(String poiId);
}
