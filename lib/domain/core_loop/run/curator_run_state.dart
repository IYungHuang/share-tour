import 'dart:math';

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

/// 景點踩線與換牌之名目體力代價共用函式 (D8 規則: 0 + riskLevel * 6)
int gatheringHpCost(TravelMaterial material) {
  return material.riskLevel * 6;
}

/// 單局旅行策展人完整狀態實體 (不可變領域狀態機)
class CuratorRunState {
  CuratorRunState({
    required this.runId,
    required this.phase,
    required this.client,
    required this.philosophy,
    required this.resources,
    required this.inventory,
    required this.itinerary,
    required this.equipment,
    EquipmentInventory? equipmentSnapshot,
    this.philosophyChoices = const [],
    this.selectedPhilosophy,
    this.rerollsUsed = 0,
    this.gatheredPoiIds = const {},
    this.latestReport,
  }) : equipmentSnapshot = equipmentSnapshot ?? equipment;

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
      equipmentSnapshot: effectiveEquipment,
      gatheredPoiIds: const {},
    );
  }

  /// 建立行前準備階段新局 (隨機客戶、三選一哲學候選卡、CC-1)
  factory CuratorRunState.createBriefing({
    required EquipmentInventory equipment,
    ClientSpec? client,
    String? runId,
    Random? random,
  }) {
    final rng = random ?? Random();
    final effectiveClient = client ??
        (rng.nextBool() ? ClientSpec.budgetWorker : ClientSpec.hypeInfluencer);
    final effectiveId = runId ?? const Uuid().v4();
    final choices = _pickDistinctPhilosophies(rng, 3);
    final resources = GuideResources.initial(
      startingBudget: effectiveClient.targetBudget,
      equipment: equipment,
    );
    final inventory = MaterialInventory(capacity: equipment.waistBag.capacity);
    final itinerary = TimelineItinerary.empty();

    return CuratorRunState(
      runId: effectiveId,
      phase: CuratorRunPhase.philosophizing,
      client: effectiveClient,
      philosophy: choices.first,
      resources: resources,
      inventory: inventory,
      itinerary: itinerary,
      equipment: equipment,
      equipmentSnapshot: equipment,
      philosophyChoices: choices,
      selectedPhilosophy: null,
      rerollsUsed: 0,
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
      equipmentSnapshot: equipment,
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

  /// 行前準備之 3 張不重複候選哲學卡
  final List<TravelPhilosophy> philosophyChoices;

  /// 行前選定之哲學卡 (出發前為 null，出發時鎖定為 philosophy)
  final TravelPhilosophy? selectedPhilosophy;

  /// 當局行前已重擲次數
  final int rerollsUsed;

  /// 阿導 3+1 核心資源狀態機 (HP, Budget, Theme, Hype)
  final GuideResources resources;

  /// 腰包素材庫存
  final MaterialInventory inventory;

  /// 4 槽位時間線行程表
  final TimelineItinerary itinerary;

  /// 局外裝備庫存 (球鞋、相機、腰包與佣金幣)
  final EquipmentInventory equipment;

  /// 當局出發時鎖定之裝備快照 (防作弊：當局踩線與計算一律使用快照)
  final EquipmentInventory equipmentSnapshot;

  /// 單局內已踩線採集之 POI ID 集合 (防止原地無腦洗牌)
  final Set<String> gatheredPoiIds;

  /// 最近一次客戶審查結算報告
  final ReviewReport? latestReport;

  /// 是否具備出發踩線資格 (已選定哲學)
  bool get canDepart => selectedPhilosophy != null;

  /// 下一次靈感重擲費用 (首局且局外零幣時免費 0 幣，其餘皆扣 100 幣)
  int get nextRerollCost =>
      (rerollsUsed == 0 && equipment.coins == 0) ? 0 : 100;

  /// 是否有足夠金幣重擲哲學
  bool get canReroll =>
      nextRerollCost == 0 || equipment.coins >= nextRerollCost;

  /// 行前單選旅行哲學
  CuratorRunState selectPhilosophy(TravelPhilosophy choice) {
    return copyWith(selectedPhilosophy: choice);
  }

  /// 靈感重擲刷新候選卡 (首局零幣免費，其餘扣 100 幣，不足拋出異常)
  CuratorRunState rerollPhilosophies({Random? random}) {
    final cost = nextRerollCost;
    if (!canReroll) {
      throw InsufficientCoinsException(cost, equipment.coins);
    }
    final rng = random ?? Random();
    final newChoices = _pickDistinctPhilosophies(rng, 3);
    final nextEquipment = cost > 0
        ? equipment.copyWith(coins: equipment.coins - cost)
        : equipment;

    return copyWith(
      equipment: nextEquipment,
      philosophyChoices: newChoices,
      clearSelectedPhilosophy: true,
      rerollsUsed: rerollsUsed + 1,
    );
  }

  /// 確認出發踩線 (狀態轉至 fieldTrip，原子鎖定 equipmentSnapshot，HP與腰包上限依快照初始化)
  CuratorRunState departToFieldTrip() {
    if (selectedPhilosophy == null) {
      throw const PreconditionFailedException('必須先選定一項旅行哲學方可出發踩線');
    }
    final chosenPhilosophy = selectedPhilosophy!;
    // 候選卡非空時 (行前準備階段)，選擇必須仍在當前候選卡內；
    // 否則重擲後殘留的舊選擇會讓玩家帶著一張沒被發到的哲學出發。
    if (philosophyChoices.isNotEmpty &&
        !philosophyChoices.contains(chosenPhilosophy)) {
      throw const PreconditionFailedException('選定的旅行哲學不在當前候選卡內');
    }
    final snapshot = equipment;
    final nextResources = GuideResources.initial(
      startingBudget: client.targetBudget,
      equipment: snapshot,
    );
    final nextInventory =
        MaterialInventory(capacity: snapshot.waistBag.capacity);

    return copyWith(
      phase: CuratorRunPhase.fieldTrip,
      philosophy: chosenPhilosophy,
      equipmentSnapshot: snapshot,
      resources: nextResources,
      inventory: nextInventory,
      gatheredPoiIds: const {},
    );
  }

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

    final deltaHp = gatheringHpCost(material);
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

    final deltaHp = gatheringHpCost(newMaterial);
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
    // 收下的報告必須出自本局指派的客戶。這條規則原本只擋在結算彈窗裡，
    // 換一個呼叫端就能再破一次；反作弊規則屬於狀態機，留在 domain。
    if (report.clientType != client.type.name) {
      throw PreconditionFailedException(
        '報告來自 ${report.clientType}，與本局指派客戶 ${client.type.name} 不符',
      );
    }
    final nextEquipment = equipment.addCoins(report.earnedCoins);
    return copyWith(
      phase: CuratorRunPhase.settled,
      equipment: nextEquipment,
      latestReport: report,
    );
  }

  /// 局外升級裝備 (升級 equipment，但 equipmentSnapshot 維持不變)
  CuratorRunState upgradeEquipment(EquipmentType type) {
    final nextEquipment = equipment.upgrade(type);
    return copyWith(equipment: nextEquipment);
  }

  /// 體力是否透支或強制進入夜晚排程 (REQ-M3-04)
  bool get isExhausted =>
      resources.isExhausted || phase == CuratorRunPhase.nightEditing;

  /// 是否已達可呈送審查標準 (連續 3 槽或填滿 4 槽)
  bool get canSubmit => itinerary.canSubmit;

  /// 行程表提交問題 (轉交 domain 行程表判定)
  ItinerarySubmissionIssue? get submissionIssue => itinerary.submissionIssue;

  /// 當前 4 槽位時間線之即時計算指標 (包含哲學加權與相機倍率，嚴格依據快照)
  ItineraryStats get currentStats => itinerary.calculateStats(
        philosophy: philosophy,
        cameraMultiplier: equipmentSnapshot.camera.cameraMultiplier,
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
    Random? random,
  }) {
    if (nextPhilosophy != null || targetPhilosophy != null) {
      return CuratorRunState.create(
        client: nextClient ?? client,
        philosophy: nextPhilosophy ?? targetPhilosophy ?? philosophy,
        equipment: equipment,
      );
    }
    return CuratorRunState.createBriefing(
      client: nextClient,
      equipment: equipment,
      random: random,
    );
  }

  CuratorRunState copyWith({
    String? runId,
    CuratorRunPhase? phase,
    ClientSpec? client,
    TravelPhilosophy? philosophy,
    List<TravelPhilosophy>? philosophyChoices,
    TravelPhilosophy? selectedPhilosophy,
    bool clearSelectedPhilosophy = false,
    int? rerollsUsed,
    GuideResources? resources,
    MaterialInventory? inventory,
    TimelineItinerary? itinerary,
    EquipmentInventory? equipment,
    EquipmentInventory? equipmentSnapshot,
    Set<String>? gatheredPoiIds,
    ReviewReport? latestReport,
  }) => CuratorRunState(
    runId: runId ?? this.runId,
    phase: phase ?? this.phase,
    client: client ?? this.client,
    philosophy: philosophy ?? this.philosophy,
    philosophyChoices: philosophyChoices ?? this.philosophyChoices,
    selectedPhilosophy: clearSelectedPhilosophy
        ? null
        : (selectedPhilosophy ?? this.selectedPhilosophy),
    rerollsUsed: rerollsUsed ?? this.rerollsUsed,
    resources: resources ?? this.resources,
    inventory: inventory ?? this.inventory,
    itinerary: itinerary ?? this.itinerary,
    equipment: equipment ?? this.equipment,
    equipmentSnapshot: equipmentSnapshot ?? this.equipmentSnapshot,
    gatheredPoiIds: gatheredPoiIds ?? this.gatheredPoiIds,
    latestReport: latestReport ?? this.latestReport,
  );

  static List<TravelPhilosophy> _pickDistinctPhilosophies(
    Random rng,
    int count,
  ) {
    final all = List<TravelPhilosophy>.from(TravelPhilosophy.values);
    all.shuffle(rng);
    return List<TravelPhilosophy>.unmodifiable(all.take(count));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CuratorRunState &&
          runtimeType == other.runtimeType &&
          runId == other.runId &&
          phase == other.phase &&
          client == other.client &&
          philosophy == other.philosophy &&
          selectedPhilosophy == other.selectedPhilosophy &&
          rerollsUsed == other.rerollsUsed &&
          resources == other.resources &&
          inventory == other.inventory &&
          itinerary == other.itinerary &&
          equipment == other.equipment &&
          equipmentSnapshot == other.equipmentSnapshot &&
          _setsEqual(gatheredPoiIds, other.gatheredPoiIds);

  @override
  int get hashCode => Object.hash(
    runId,
    phase,
    client,
    philosophy,
    selectedPhilosophy,
    rerollsUsed,
    resources,
    inventory,
    itinerary,
    equipment,
    equipmentSnapshot,
    Object.hashAll(gatheredPoiIds),
  );

  static bool _setsEqual(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
