import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/state/location/location_providers.dart';

import 'curator_run_controller.dart';

/// 抽象素材池 DLC 注入點 (守護 Clean Architecture，由 main.dart 或測試注入具體圖資素材)
final curatorMaterialPoolProvider = Provider<List<TravelMaterial>>((ref) {
  return const [];
});

/// 景點素材解析器純領域介面注入點 (城市即實體 DLC)
final poiMaterialResolverProvider = Provider<PoiMaterialResolver>((ref) {
  throw UnimplementedError('poiMaterialResolverProvider 必須由最外層注入');
});

/// 策展單局控制器 Provider (常駐非 autoDispose，守護玩家草稿不被 GC 銷毀)
final curatorRunControllerProvider =
    StateNotifierProvider<CuratorRunController, CuratorRunState>((ref) {
      final pool = ref.watch(curatorMaterialPoolProvider);
      PoiMaterialResolver? resolver;
      try {
        resolver = ref.watch(poiMaterialResolverProvider);
      } catch (_) {
        // 在未注入 resolver 的環境中容錯降級
      }
      return CuratorRunController(
        materialPool: pool,
        resolver: resolver,
      );
    });

/// 即時行程表試算指標衍生 Provider (具備 Riverpod Memoization，供 HUD 與光軌共享)
final itineraryStatsProvider = Provider<ItineraryStats>((ref) {
  final state = ref.watch(curatorRunControllerProvider);
  return state.currentStats;
});

/// 單向探索許可 Provider (控制 DPad / GPS 小人移動)
final canExploreProvider = Provider<bool>((ref) {
  final state = ref.watch(curatorRunControllerProvider);
  return (state.phase == CuratorRunPhase.fieldTrip ||
          state.phase == CuratorRunPhase.philosophizing) &&
      !state.resources.isExhausted;
});

/// 景點取材資格 6 態枚舉
enum GatheringEligibility {
  ready,            // 範圍內且資源足夠 -> 亮綠色
  inventoryFull,    // 範圍內但腰包已滿 -> 亮橘色換牌
  alreadyGathered,  // 本局已採線 -> 灰色已採
  outOfRange,       // 超出 50m 感應半徑 -> 灰色超距
  exhausted,        // 體力透支 -> 灰色透支
  unavailable,      // 該景點無素材配置 -> 灰色不可採
}

/// 單一景點取材資格 Family Provider
final attractionEligibilityProvider =
    Provider.family<GatheringEligibility, DistrictAttraction>((ref, attraction) {
      PoiMaterialResolver? resolver;
      try {
        resolver = ref.watch(poiMaterialResolverProvider);
      } catch (_) {
        return GatheringEligibility.unavailable;
      }
      if (resolver == null) {
        return GatheringEligibility.unavailable;
      }

      final material = resolver.resolveMaterialFor(attraction.id);
      if (material == null) {
        return GatheringEligibility.unavailable;
      }

      final runState = ref.watch(curatorRunControllerProvider);
      if (runState.gatheredPoiIds.contains(attraction.id)) {
        return GatheringEligibility.alreadyGathered;
      }
      if (runState.resources.isExhausted || runState.resources.currentHp <= 0) {
        return GatheringEligibility.exhausted;
      }

      final locationState = ref.watch(locationControllerProvider);
      final manifest = ref.watch(mapManifestProvider);
      final playerPixel = locationState.renderedPixel;
      final distPx = (attraction.pixel - playerPixel).length;
      final distM = distPx * manifest.metersPerPixelAt(playerPixel);

      if (distM > attraction.triggerRadiusMeters) {
        return GatheringEligibility.outOfRange;
      }

      if (runState.inventory.isFull) {
        return GatheringEligibility.inventoryFull;
      }

      return GatheringEligibility.ready;
    });
