import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';

import 'curator_run_controller.dart';

/// 抽象素材池 DLC 注入點 (守護 Clean Architecture，由 main.dart 或測試注入具體圖資素材)
final curatorMaterialPoolProvider = Provider<List<TravelMaterial>>((ref) {
  throw UnimplementedError('curatorMaterialPoolProvider 必須由最外層注入圖資 DLC 素材庫');
});

/// 策展單局控制器 Provider (常駐非 autoDispose，守護玩家草稿不被 GC 銷毀)
final curatorRunControllerProvider =
    StateNotifierProvider<CuratorRunController, CuratorRunState>((ref) {
      final pool = ref.watch(curatorMaterialPoolProvider);
      return CuratorRunController(materialPool: pool);
    });

/// 即時行程表試算指標衍生 Provider (具備 Riverpod Memoization，供 HUD 與光軌共享)
final itineraryStatsProvider = Provider<ItineraryStats>((ref) {
  final state = ref.watch(curatorRunControllerProvider);
  return state.currentStats;
});
