import 'package:vector_math/vector_math.dart';

enum EncounterType {
  sightseeing, // 觀光打卡 / SAN 提升
  rest,        // 旅店宿點 / HP 回復
  shop,        // 黑市商店 / 購買裝備
  challenge,   // 換乘 QTE / 敏捷檢定
  boss,        // 深夜居酒屋 / 魔王對決
}

/// 地圖上 POI 互動節點
class OverworldPoiNode {
  final String id;
  final String title;
  final Vector2 pixelPosition;
  final double triggerRadius;
  final EncounterType encounterType;

  const OverworldPoiNode({
    required this.id,
    required this.title,
    required this.pixelPosition,
    this.triggerRadius = 35.0,
    required this.encounterType,
  });
}
