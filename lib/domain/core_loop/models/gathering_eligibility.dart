import 'package:vector_math/vector_math.dart';

import '../../location/models/district_attraction.dart';
import '../../location/projection/map_manifest.dart';
import '../run/curator_run_state.dart';
import 'travel_material.dart';

/// 景點取材資格 6 態枚舉 (搬移至 Domain 層，零行為變更)
enum GatheringEligibility {
  ready, // 範圍內且資源足夠 -> 亮綠色
  inventoryFull, // 範圍內但腰包已滿 -> 亮橘色換牌
  alreadyGathered, // 本局已採線 -> 灰色已採
  outOfRange, // 超出 50m 感應半徑 -> 灰色超距
  exhausted, // 體力透支 -> 灰色透支
  unavailable, // 該景點無素材配置 -> 灰色不可採
}

/// 評估單一景點的取材資格 (純 Domain 領域規則判定)
GatheringEligibility evaluateAttractionEligibility({
  required DistrictAttraction attraction,
  required CuratorRunState run,
  required TravelMaterial? material,
  required Vector2 playerPixel,
  required OverworldMapManifest manifest,
}) {
  if (material == null) {
    return GatheringEligibility.unavailable;
  }

  if (run.gatheredPoiIds.contains(attraction.id)) {
    return GatheringEligibility.alreadyGathered;
  }

  if (run.resources.isExhausted || run.resources.currentHp <= 0) {
    return GatheringEligibility.exhausted;
  }

  final distPx = (attraction.pixel - playerPixel).length;
  final distM = distPx * manifest.metersPerPixelAt(playerPixel);

  if (distM > attraction.triggerRadiusMeters) {
    return GatheringEligibility.outOfRange;
  }

  if (run.inventory.isFull) {
    return GatheringEligibility.inventoryFull;
  }

  return GatheringEligibility.ready;
}
