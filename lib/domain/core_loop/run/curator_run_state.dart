import 'package:uuid/uuid.dart';

import '../models/core_loop_exceptions.dart';
import '../models/guide_resources.dart';
import '../models/material_inventory.dart';
import '../models/meta_equipment.dart';
import '../models/review_outcome.dart';
import '../models/timeline_itinerary.dart';
import '../models/travel_material.dart';
import '../models/travel_philosophy.dart';
import '../review/client_spec.dart';
import 'curator_run_phase.dart';

/// 單局旅行策展人完整狀態實體 (不可變領域狀態機)
class CuratorRunState {
  const CuratorRunState({
    required this.runId,
    required this.phase,
    required this.client,
    required this.philosophy,
    required this.resources,
    required this.inventory,
    required this.itinerary,
    required this.equipment,
    this.gatheredPoiIds = const {},
    this.latestReport,
  });

  /// 建立全新單局初始狀態 (預設 philosophizing 階段，UUID 遵循 CC-1)
  factory CuratorRunState.initial({
    CuratorRunPhase? phase,
    ClientSpec? client,
    TravelPhilosophy? philosophy,
    TravelPhilosophy? targetPhilosophy,
    EquipmentInventory? equipment,
    String? runId,
    int? initialBudget,
    int? initialHp,
  }) {
    final effectiveClient = client ?? ClientSpec.budgetWorker;
    final effectivePhilosophy =
        targetPhilosophy ?? philosophy ?? TravelPhilosophy.midnight;
    final effectiveEquipment = equipment ?? EquipmentInventory.initial();
    final effectiveId = runId ?? const Uuid().v4();
    var resources = GuideResources.initial(
      startingBudget: initialBudget ?? effectiveClient.targetBudget,
      equipment: effectiveEquipment,
    );
    if (initialHp != null && initialHp < resources.currentHp) {
      resources = resources.consumeHp(resources.currentHp - initialHp);
    }
    final inventory =
        MaterialInventory(capacity: effectiveEquipment.waistBag.capacity);
    final itinerary = TimelineItinerary.empty();

    return CuratorRunState(
      runId: effectiveId,
      phase: phase ?? CuratorRunPhase.philosophizing,
      client: effectiveClient,
      philosophy: effectivePhilosophy,
      resources: resources,
      inventory: inventory,
      itinerary: itinerary,
      equipment: effectiveEquipment,
      gatheredPoiIds: const {},
    );
  }

  /// 建立全新單局 (產生新 UUID，CC-1，進入 fieldTrip 階段)
  factory CuratorRunState.create({
    required ClientSpec client,
    required TravelPhilosophy philosophy,
    required EquipmentInventory equipment,
    String? runId,
    int? initialBudget,
    int? initialHp,
  }) {
    final effectiveId = runId ?? const Uuid().v4();
    var resources = GuideResources.initial(
      startingBudget: initialBudget ?? client.targetBudget,
      equipment: equipment,
    );
    if (initialHp != null && initialHp < resources.currentHp) {
      resources = resources.consumeHp(resources.currentHp - initialHp);
    }
    final inventory = MaterialInventory(capacity: equipment.waistBag.capacity);
    final itinerary = TimelineItinerary.empty();

    return CuratorRunState(
      runId: effectiveId,
      phase: CuratorRunPhase.fieldTrip,
      client: client,
      philosophy: philosophy,
      resources: resources,
      inventory: inventory,
      itinerary: itinerary,
      equipment: equipment,
      gatheredPoiIds: const {},
    );
  }

  /// 單局唯一識別碼 (UUID，遵循 CC-1)
  final String runId;

  /// 當前流程階段
  final CuratorRunPhase phase;

  /// 當局委託客戶
  final ClientSpec client;

  /// 當局選定之旅行哲學
  final TravelPhilosophy philosophy;

  /// 阿導 3+1 核心資源狀態機 (HP, Budget, Theme, Hype)
  final GuideResources resources;

  /// 腰包素材庫存
  final MaterialInventory inventory;

  /// 4 槽位時間線行程表
  final TimelineItinerary itinerary;

  /// 局外裝備庫存 (球鞋、相機、腰包與佣金幣)
  final EquipmentInventory equipment;

  /// 單局內已踩線採集之 POI ID 集合 (防止原地無腦洗牌)
  final Set<String> gatheredPoiIds;

  /// 最近一次客戶審查結算報告
  final ReviewReport? latestReport;

  /// 踩線取材原子轉移 (REQ-M3-03, AC-M3-3)
  CuratorRunState gatherPoiMaterial({
    required String poiId,
    required TravelMaterial material,
  }) {
    if (gatheredPoiIds.contains(poiId)) {
      throw PoiAlreadyGatheredException(poiId);
    }
    if (resources.isExhausted || resources.currentHp <= 0) {
      throw const CuratorExhaustedException();
    }
    if (inventory.isFull) {
      throw InventoryFullException(inventory.capacity);
    }

    final deltaHp = 10 + (material.riskLevel * 2);
    final nextHp = resources.currentHp - deltaHp;
    final bool isNowExhausted = nextHp <= 0;
    final consumedHp = isNowExhausted ? resources.currentHp : deltaHp;

    var nextResources = resources.consumeHp(consumedHp);
    nextResources = nextResources.spendBudget(material.cost);

    final nextInventory = inventory.add(material);
    final nextGathered = Set<String>.unmodifiable({...gatheredPoiIds, poiId});
    final nextPhase = isNowExhausted ? CuratorRunPhase.nightEditing : phase;

    return copyWith(
      resources: nextResources,
      inventory: nextInventory,
      gatheredPoiIds: nextGathered,
      phase: nextPhase,
    );
  }

  /// 腰包滿額現場換牌原子轉移 (REQ-M3-03, AC-M3-4)
  CuratorRunState replaceGatheredMaterial({
    required String poiId,
    required int dropIndex,
    required TravelMaterial newMaterial,
  }) {
    if (gatheredPoiIds.contains(poiId)) {
      throw PoiAlreadyGatheredException(poiId);
    }
    if (resources.isExhausted || resources.currentHp <= 0) {
      throw const CuratorExhaustedException();
    }

    final deltaHp = 10 + (newMaterial.riskLevel * 2);
    final nextHp = resources.currentHp - deltaHp;
    final bool isNowExhausted = nextHp <= 0;
    final consumedHp = isNowExhausted ? resources.currentHp : deltaHp;

    var nextResources = resources.consumeHp(consumedHp);
    nextResources = nextResources.spendBudget(newMaterial.cost);

    final nextInventory = inventory.replace(
      dropIndex: dropIndex,
      newItem: newMaterial,
    );
    final nextGathered = Set<String>.unmodifiable({...gatheredPoiIds, poiId});
    final nextPhase = isNowExhausted ? CuratorRunPhase.nightEditing : phase;

    return copyWith(
      resources: nextResources,
      inventory: nextInventory,
      gatheredPoiIds: nextGathered,
      phase: nextPhase,
    );
  }

  /// 踩線拾取素材 (向後相容)
  CuratorRunState addMaterial(TravelMaterial material) {
    final nextInventory = inventory.add(material);
    return copyWith(inventory: nextInventory);
  }

  /// 腰包滿額替換素材
  CuratorRunState replaceMaterial({
    required int dropIndex,
    required TravelMaterial newItem,
  }) {
    final nextInventory = inventory.replace(
      dropIndex: dropIndex,
      newItem: newItem,
    );
    return copyWith(inventory: nextInventory);
  }

  /// 設定時間線槽位
  CuratorRunState setTimelineSlot(int slotIndex, TravelMaterial? material) {
    final nextItinerary = itinerary.setSlot(slotIndex, material);
    return copyWith(itinerary: nextItinerary);
  }

  /// 完成審查並結算 (進入 settled 階段，累積佣金，遵循 CC-3 決定性重播)
  CuratorRunState completeReview(ReviewReport report) {
    final nextEquipment = equipment.addCoins(report.earnedCoins);
    return copyWith(
      phase: CuratorRunPhase.settled,
      equipment: nextEquipment,
      latestReport: report,
    );
  }

  /// 局外升級裝備
  CuratorRunState upgradeEquipment(EquipmentType type) {
    final nextEquipment = equipment.upgrade(type);
    return copyWith(equipment: nextEquipment);
  }

  /// 體力是否透支或強制進入夜晚排程 (REQ-M3-04)
  bool get isExhausted =>
      resources.isExhausted || phase == CuratorRunPhase.nightEditing;

  /// 4 槽位是否已全部填滿可呈送審查
  bool get canSubmit => itinerary.canSubmit;

  /// 當前 4 槽位時間線之即時計算指標 (包含哲學加權與相機倍率)
  ItineraryStats get currentStats => itinerary.calculateStats(
        philosophy: philosophy,
        cameraMultiplier: equipment.camera.cameraMultiplier,
      );

  /// Near Miss 或 Rejected 時返回微調行程 (退回 nightEditing 階段，保留槽位與腰包)
  CuratorRunState tweakItinerary() {
    if (phase != CuratorRunPhase.clientReview &&
        phase != CuratorRunPhase.settled) {
      return this;
    }
    return copyWith(phase: CuratorRunPhase.nightEditing);
  }

  /// 觸發「再來一局 (Restart Run)」(AC-ML-7)
  CuratorRunState restartRun({
    ClientSpec? nextClient,
    TravelPhilosophy? nextPhilosophy,
    TravelPhilosophy? targetPhilosophy,
  }) {
    // 繼承既有裝備與佣金，重新生成 UUID，重置局內所有數值與已採集 POI
    return CuratorRunState.create(
      client: nextClient ?? client,
      philosophy: nextPhilosophy ?? targetPhilosophy ?? philosophy,
      equipment: equipment,
    );
  }

  CuratorRunState copyWith({
    String? runId,
    CuratorRunPhase? phase,
    ClientSpec? client,
    TravelPhilosophy? philosophy,
    GuideResources? resources,
    MaterialInventory? inventory,
    TimelineItinerary? itinerary,
    EquipmentInventory? equipment,
    Set<String>? gatheredPoiIds,
    ReviewReport? latestReport,
  }) => CuratorRunState(
    runId: runId ?? this.runId,
    phase: phase ?? this.phase,
    client: client ?? this.client,
    philosophy: philosophy ?? this.philosophy,
    resources: resources ?? this.resources,
    inventory: inventory ?? this.inventory,
    itinerary: itinerary ?? this.itinerary,
    equipment: equipment ?? this.equipment,
    gatheredPoiIds: gatheredPoiIds ?? this.gatheredPoiIds,
    latestReport: latestReport ?? this.latestReport,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CuratorRunState &&
          runtimeType == other.runtimeType &&
          runId == other.runId &&
          phase == other.phase &&
          client == other.client &&
          philosophy == other.philosophy &&
          resources == other.resources &&
          inventory == other.inventory &&
          itinerary == other.itinerary &&
          equipment == other.equipment &&
          _setsEqual(gatheredPoiIds, other.gatheredPoiIds);

  @override
  int get hashCode => Object.hash(
    runId,
    phase,
    client,
    philosophy,
    resources,
    inventory,
    itinerary,
    equipment,
    Object.hashAll(gatheredPoiIds),
  );

  static bool _setsEqual(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
