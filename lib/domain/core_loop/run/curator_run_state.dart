import 'package:uuid/uuid.dart';

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
    this.latestReport,
  });

  /// 建立全新單局初始狀態 (預設 philosophizing 階段，UUID 遵循 CC-1)
  factory CuratorRunState.initial({
    ClientSpec? client,
    TravelPhilosophy? philosophy,
    EquipmentInventory? equipment,
    String? runId,
  }) {
    final effectiveClient = client ?? ClientSpec.budgetWorker;
    final effectivePhilosophy = philosophy ?? TravelPhilosophy.midnight;
    final effectiveEquipment = equipment ?? EquipmentInventory.initial();
    final effectiveId = runId ?? const Uuid().v4();
    final resources = GuideResources.initial(
      startingBudget: effectiveClient.targetBudget,
      equipment: effectiveEquipment,
    );
    final inventory = MaterialInventory(capacity: effectiveEquipment.waistBag.capacity);
    final itinerary = TimelineItinerary.empty();

    return CuratorRunState(
      runId: effectiveId,
      phase: CuratorRunPhase.philosophizing,
      client: effectiveClient,
      philosophy: effectivePhilosophy,
      resources: resources,
      inventory: inventory,
      itinerary: itinerary,
      equipment: effectiveEquipment,
    );
  }

  /// 建立全新單局 (產生新 UUID，CC-1，進入 fieldTrip 階段)
  factory CuratorRunState.create({
    required ClientSpec client,
    required TravelPhilosophy philosophy,
    required EquipmentInventory equipment,
    String? runId,
  }) {
    final effectiveId = runId ?? const Uuid().v4();
    final resources = GuideResources.initial(
      startingBudget: client.targetBudget,
      equipment: equipment,
    );
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

  /// 最近一次客戶審查結算報告
  final ReviewReport? latestReport;

  /// 踩線拾取素材
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
    required ClientSpec nextClient,
    required TravelPhilosophy nextPhilosophy,
  }) {
    // 繼承既有裝備與佣金，重新生成 UUID，重置局內所有數值
    return CuratorRunState.create(
      client: nextClient,
      philosophy: nextPhilosophy,
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
          equipment == other.equipment;

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
  );
}
