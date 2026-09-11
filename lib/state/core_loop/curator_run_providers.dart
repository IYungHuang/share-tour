import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/gathering_eligibility.dart';
import 'package:share_tour/domain/core_loop/models/persistence_repository.dart';
import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/state/location/location_providers.dart';

export 'package:share_tour/domain/core_loop/models/gathering_eligibility.dart';

import 'curator_run_controller.dart';
import 'persistence_providers.dart';

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
      PersistenceRepository? persistenceRepo;
      try {
        persistenceRepo = ref.watch(persistenceRepositoryProvider);
      } catch (_) {
        // 在未注入 persistence 的測試環境中容錯降級
      }
      final initialSave = ref.watch(initialSaveDataProvider);

      return CuratorRunController(
        materialPool: pool,
        resolver: resolver,
        persistenceRepository: persistenceRepo,
        initialSaveData: initialSave,
      );
    });

/// 即時行程表試算指標衍生 Provider (具備 Riverpod Memoization，供 HUD 與光軌共享)
final itineraryStatsProvider = Provider<ItineraryStats>((ref) {
  final state = ref.watch(curatorRunControllerProvider);
  return state.currentStats;
});

/// 單向探索許可 Provider (控制 DPad / GPS 小人移動；僅在 fieldTrip 踩線且未透支時允許)
final canExploreProvider = Provider<bool>((ref) {
  final state = ref.watch(curatorRunControllerProvider);
  return state.phase == CuratorRunPhase.fieldTrip &&
      !state.resources.isExhausted;
});

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
      final runState = ref.watch(curatorRunControllerProvider);
      final locationState = ref.watch(locationControllerProvider);
      final manifest = ref.watch(mapManifestProvider);

      return evaluateAttractionEligibility(
        attraction: attraction,
        run: runState,
        material: material,
        playerPixel: locationState.renderedPixel,
        manifest: manifest,
      );
    });

/// 審查比較報告 Family Provider (AC-FIX-5.1: 供頁籤唯讀對照)
final comparisonReviewReportProvider =
    Provider.family<ReviewReport, ClientType>((ref, clientType) {
  final state = ref.watch(curatorRunControllerProvider);
  final latest = state.latestReport;
  if (latest != null && latest.clientType == clientType.name) return latest;
  final client = switch (clientType) {
    ClientType.budgetWorker => ClientSpec.budgetWorker,
    ClientType.hypeInfluencer => ClientSpec.hypeInfluencer,
  };
  return ClientReviewEngine.evaluate(
    client: client,
    stats: state.currentStats,
    philosophy: state.philosophy,
  );
});

/// 本局指派客戶審查報告 Provider
final assignedReviewReportProvider = Provider<ReviewReport>((ref) {
  final assignedType = ref.watch(
    curatorRunControllerProvider.select((state) => state.client.type),
  );
  return ref.watch(comparisonReviewReportProvider(assignedType));
});
