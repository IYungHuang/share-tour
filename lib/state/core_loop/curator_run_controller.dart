import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/core_loop_exceptions.dart';
import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';

/// 策展單局控制器 (Riverpod StateNotifier，管理單局完整狀態機)
class CuratorRunController extends StateNotifier<CuratorRunState> {
  CuratorRunController({
    required List<TravelMaterial> materialPool,
    PoiMaterialResolver? resolver,
    CuratorRunState? initialState,
  }) : _materialPool = materialPool,
       _resolver = resolver,
       super(initialState ?? CuratorRunState.initial());

  final List<TravelMaterial> _materialPool;
  PoiMaterialResolver? _resolver;

  /// 設定景點素材解析器
  void setResolver(PoiMaterialResolver resolver) {
    _resolver = resolver;
  }

  /// 開始踩線取材階段 (推進至 fieldTrip)
  void startFieldTrip() {
    state = state.copyWith(phase: CuratorRunPhase.fieldTrip);
  }

  /// 踩線取材發動 (REQ-M3-03, AC-M3-3)
  void gatherPoi(String poiId) {
    final resolver = _resolver;
    if (resolver == null) {
      throw StateError('PoiMaterialResolver 尚未注入');
    }
    final material = resolver.resolveMaterialFor(poiId);
    if (material == null) {
      throw PoiUnavailableException(poiId);
    }
    state = state.gatherPoiMaterial(poiId: poiId, material: material);
  }

  /// 腰包滿額現場換牌發動 (REQ-M3-03, AC-M3-4)
  void replaceGatheredPoi({required String poiId, required int dropIndex}) {
    final resolver = _resolver;
    if (resolver == null) {
      throw StateError('PoiMaterialResolver 尚未注入');
    }
    final material = resolver.resolveMaterialFor(poiId);
    if (material == null) {
      throw PoiUnavailableException(poiId);
    }
    state = state.replaceGatheredMaterial(
      poiId: poiId,
      dropIndex: dropIndex,
      newMaterial: material,
    );
  }

  /// 選定當局旅行哲學 (推進至 nightEditing)
  void selectPhilosophy(TravelPhilosophy philosophy) {
    state = state.copyWith(
      philosophy: philosophy,
      phase: CuratorRunPhase.nightEditing,
    );
  }

  /// 抽取測試樣本素材 (支援 Random 種子注入，遵循 CC-3 決定性重播)
  void drawSampleMaterial({Random? random}) {
    if (_materialPool.isEmpty) return;
    final rng = random ?? Random();
    final item = _materialPool[rng.nextInt(_materialPool.length)];
    state = state.addMaterial(item);
  }

  /// 依指定 ID 抽取素材加入腰包
  void drawMaterialById(String id) {
    final item = _materialPool.firstWhere(
      (m) => m.id == id,
      orElse: () => throw ArgumentError('素材庫中無此 ID: $id'),
    );
    state = state.addMaterial(item);
  }

  /// 將素材放入時間線槽位 (實作引用模式，禁止同一素材跨槽位重複引用)
  void placeMaterialInSlot(int slotIndex, TravelMaterial material) {
    RangeError.checkValueInInterval(slotIndex, 0, 3, 'slotIndex');

    // 檢查該素材是否已在其他槽位中
    final currentSlots = List<TravelMaterial?>.from(state.itinerary.slots);
    final existingIndex = currentSlots.indexWhere((s) => s?.id == material.id);

    if (existingIndex != -1 && existingIndex != slotIndex) {
      // 觸發互換/移動：將原有槽位替換為目標槽位現有之素材（若有）
      final targetExistingMaterial = currentSlots[slotIndex];
      currentSlots[existingIndex] = targetExistingMaterial;
    }

    currentSlots[slotIndex] = material;
    var nextItinerary = state.itinerary;
    for (var i = 0; i < 4; i++) {
      nextItinerary = nextItinerary.setSlot(i, currentSlots[i]);
    }

    state = state.copyWith(itinerary: nextItinerary);
  }

  /// 自指定槽位卸下素材
  void removeMaterialFromSlot(int slotIndex) {
    RangeError.checkValueInInterval(slotIndex, 0, 3, 'slotIndex');
    state = state.setTimelineSlot(slotIndex, null);
  }

  /// 互換兩槽位素材 (支援空槽位移動)
  void swapSlots(int fromIndex, int toIndex) {
    RangeError.checkValueInInterval(fromIndex, 0, 3, 'fromIndex');
    RangeError.checkValueInInterval(toIndex, 0, 3, 'toIndex');
    if (fromIndex == toIndex) return;

    final slots = state.itinerary.slots;
    final fromMat = slots[fromIndex];
    final toMat = slots[toIndex];

    var nextItinerary = state.itinerary.setSlot(fromIndex, toMat);
    nextItinerary = nextItinerary.setSlot(toIndex, fromMat);

    state = state.copyWith(itinerary: nextItinerary);
  }

  /// 呈送審查 (產生確定性結算報告，推進至 clientReview)
  void submitReview(ClientType clientType) {
    if (!state.canSubmit) {
      throw StateError('4 個槽位尚未全部填滿，無法呈送審查');
    }

    final clientSpec = switch (clientType) {
      ClientType.budgetWorker => ClientSpec.budgetWorker,
      ClientType.hypeInfluencer => ClientSpec.hypeInfluencer,
    };

    final stats = state.currentStats;
    final report = ClientReviewEngine.evaluate(
      client: clientSpec,
      stats: stats,
    );

    state = state.copyWith(
      phase: CuratorRunPhase.clientReview,
      client: clientSpec,
      latestReport: report,
    );
  }

  /// 接受審查結果 (累積佣金，推進至 settled)
  void acceptReview() {
    final report = state.latestReport;
    if (report == null) {
      throw StateError('尚無結算報告可供接受');
    }
    state = state.completeReview(report);
  }

  /// 返回微調行程 (在 Near Miss / Rejected 下退回 nightEditing，保留槽位與腰包)
  void tweakItinerary() {
    state = state.tweakItinerary();
  }

  /// 重新啟動新單局 (保留裝備與累積金幣，清空槽位腰包，生成新 UUID)
  void restartRun({ClientSpec? nextClient, TravelPhilosophy? nextPhilosophy}) {
    state = CuratorRunState.initial(
      client: nextClient ?? state.client,
      philosophy: nextPhilosophy ?? state.philosophy,
      equipment: state.equipment,
    );
  }
}
