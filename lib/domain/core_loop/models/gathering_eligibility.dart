import 'package:vector_math/vector_math.dart';

import '../../location/models/district_attraction.dart';
import '../../location/projection/map_manifest.dart';
import '../run/curator_run_state.dart';
import 'poi_material_resolver.dart';
import 'travel_material.dart';

/// 景點取材資格 6 態枚舉 (搬移至 Domain 層，零行為變更)
enum GatheringEligibility {
  ready, // 範圍內且資源足夠 -> 亮綠色
  inventoryFull, // 範圍內但腰包已滿 -> 亮橘色換牌
  alreadyGathered, // 本局已採線 -> 灰色已採
  outOfRange, // 超出感應半徑 -> 灰色超距
  exhausted, // 體力透支 -> 灰色透支
  unavailable, // 該景點無素材配置 -> 灰色不可採
}

/// 評估單一景點的取材資格 (純 Domain 領域規則判定)
///
/// 若 attraction.triggerRadiusPixels != null，直接以像素半徑比對且不呼叫 manifest.metersPerPixelAt；
/// 若為 null，則維持公尺半徑並透過 manifest.metersPerPixelAt 計算公尺距離。
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
  if (attraction.triggerRadiusPixels != null) {
    if (distPx > attraction.triggerRadiusPixels!) {
      return GatheringEligibility.outOfRange;
    }
  } else {
    final distM = distPx * manifest.metersPerPixelAt(playerPixel);
    if (distM > attraction.triggerRadiusMeters) {
      return GatheringEligibility.outOfRange;
    }
  }

  if (run.inventory.isFull) {
    return GatheringEligibility.inventoryFull;
  }

  return GatheringEligibility.ready;
}

/// 尋找當下最接近且可取材之景點 (AC-A1-4.3 原子取材與多窗口重疊仲裁)
///
/// 距離最近者優先；等距時依 POI id 字典序仲裁；重排輸入順序保持結果不變。
/// 僅在景點為 ready 或 inventoryFull (可換牌) 時列入候選；已採集、透支、超距、無素材者自動排除。
({DistrictAttraction attraction, TravelMaterial material})?
nearestGatherablePoi({
  required Iterable<DistrictAttraction> attractions,
  required CuratorRunState run,
  required Vector2 playerPixel,
  required OverworldMapManifest manifest,
  required PoiMaterialResolver resolver,
}) {
  ({DistrictAttraction attraction, TravelMaterial material, double dist})? best;

  for (final attraction in attractions) {
    final material = resolver.resolveMaterialFor(attraction.id);
    if (material == null) continue;

    final eligibility = evaluateAttractionEligibility(
      attraction: attraction,
      run: run,
      material: material,
      playerPixel: playerPixel,
      manifest: manifest,
    );

    // 只有在範圍內且非已採集/透支/不可用的狀態才視為可採集 POI (包含滿包換牌)
    if (eligibility != GatheringEligibility.ready &&
        eligibility != GatheringEligibility.inventoryFull) {
      continue;
    }

    final dist = (attraction.pixel - playerPixel).length;
    if (best == null) {
      best = (attraction: attraction, material: material, dist: dist);
    } else {
      if (dist < best.dist) {
        best = (attraction: attraction, material: material, dist: dist);
      } else if (dist == best.dist && attraction.id.compareTo(best.attraction.id) < 0) {
        best = (attraction: attraction, material: material, dist: dist);
      }
    }
  }

  if (best == null) return null;
  return (attraction: best.attraction, material: best.material);
}
