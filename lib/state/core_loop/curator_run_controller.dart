import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:share_tour/domain/core_loop/events/curator_event.dart';
import 'package:share_tour/domain/core_loop/models/core_loop_exceptions.dart';
import 'package:share_tour/domain/core_loop/models/curator_save_data.dart';
import 'package:share_tour/domain/core_loop/models/gathering_eligibility.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/persistence_repository.dart';
import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/domain/core_loop/time/diurnal_resonance_rule.dart';
import 'package:share_tour/domain/core_loop/time/tour_period.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:vector_math/vector_math.dart';

/// 策展單局控制器 (Riverpod StateNotifier，管理單局完整狀態機與存檔持久化)
class CuratorRunController extends StateNotifier<CuratorRunState> {
  CuratorRunController({
    required List<TravelMaterial> materialPool,
    PoiMaterialResolver? resolver,
    CuratorRunState? initialState,
    PersistenceRepository? persistenceRepository,
    CuratorSaveData? initialSaveData,
    DateTime Function()? nowUtc,
    Uuid? uuid,
  }) : _materialPool = materialPool,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _uuid = uuid ?? const Uuid(),
       _resolver = resolver,
       _persistenceRepository = persistenceRepository,
       super(
         initialState ??
             (initialSaveData != null
                 ? CuratorRunState.createBriefing(
                     equipment: initialSaveData.toEquipmentInventory(),
                   )
                 : CuratorRunState.createBriefing(
                     equipment: EquipmentInventory.initial(),
                   )),
       );

  final List<TravelMaterial> _materialPool;
  PoiMaterialResolver? _resolver;
  final PersistenceRepository? _persistenceRepository;
  final DateTime Function() _nowUtc;
  final Uuid _uuid;

  /// 設定景點素材解析器
  void setResolver(PoiMaterialResolver resolver) {
    _resolver = resolver;
  }

  /// 踩線取材發動 (REQ-M3-03, AC-M3-3, AC-A1-4.3, AC-A1-5.5)
  ///
  /// 若提供 manifest 與 playerPixel，會重新計算當下最近且可取材之 POI；
  /// 若無提供（既有測試相容路徑），則直接以 poiId 進行解析與取材。
  ///
  /// [expectedPoiId] 為 REQ-M5-07.1 的鎖定防護：QTE 開始時鎖定目標，判定
  /// 完成後（1.2~2.0 秒後）若最近可取材的 POI 已與鎖定時不符，拋出
  /// [PoiTargetChangedException] 取消本次取材，不做任何狀態變更。未提供
  /// 時（既有呼叫端）完全不受影響——這是既有缺陷的獨立修復，不隨 [shotTier]
  /// 一起生效。
  ///
  /// [shotTier] 為快門 QTE 的判定結果（REQ-M5-01.1），預設 `normal`。
  ({DistrictAttraction attraction, TravelMaterial material, int hpSpent})
  gatherPoi(
    String poiId, {
    OverworldMapManifest? manifest,
    Vector2? playerPixel,
    TourPeriod? period,
    String? expectedPoiId,
    ShotTier shotTier = ShotTier.normal,
  }) {
    final resolver = _resolver;
    if (resolver == null) {
      throw StateError('PoiMaterialResolver 尚未注入');
    }

    DistrictAttraction? targetAttraction;
    TravelMaterial? targetMaterial;
    final resolvesLiveTarget =
        manifest != null &&
        playerPixel != null &&
        manifest.districtAttractions.isNotEmpty;

    if (resolvesLiveTarget) {
      final nearest = nearestGatherablePoi(
        attractions: manifest.districtAttractions,
        run: state,
        playerPixel: playerPixel,
        manifest: manifest,
        resolver: resolver,
      );
      if (nearest != null) {
        targetAttraction = nearest.attraction;
        targetMaterial = nearest.material;
      }
    }

    if (targetAttraction == null || targetMaterial == null) {
      if (resolvesLiveTarget && expectedPoiId != null) {
        throw PoiTargetChangedException(expectedPoiId, poiId);
      }
      if (expectedPoiId != null && poiId != expectedPoiId) {
        throw PoiTargetChangedException(expectedPoiId, poiId);
      }
      targetMaterial = resolver.resolveMaterialFor(poiId);
      if (targetMaterial == null) {
        throw PoiUnavailableException(poiId);
      }
      targetAttraction =
          manifest?.districtAttractions
              .where((a) => a.id == poiId)
              .firstOrNull ??
          DistrictAttraction(
            id: poiId,
            title: targetMaterial.name,
            districtCode: '',
            districtName: '',
            geo: const GeoPoint(0, 0),
            pixel: Vector2.zero(),
            rating: 5.0,
            reviewCount: 0,
            category: AttractionCategory.sightseeing,
          );
    }

    if (expectedPoiId != null && targetAttraction.id != expectedPoiId) {
      throw PoiTargetChangedException(expectedPoiId, targetAttraction.id);
    }

    if (shotTier != ShotTier.normal) {
      targetMaterial = targetMaterial.copyWith(shotTier: shotTier);
    }

    final overrideHpCost = period != null
        ? DiurnalResonanceRule.calculateActualCost(
            baseHpCost: gatheringHpCost(targetMaterial),
            currentPeriod: period,
            material: targetMaterial,
          )
        : null;

    final hpBefore = state.resources.currentHp;
    state = state.gatherPoiMaterial(
      poiId: targetAttraction.id,
      material: targetMaterial,
      overrideHpCost: overrideHpCost,
    );
    final hpAfter = state.resources.currentHp;
    return (
      attraction: targetAttraction,
      material: targetMaterial,
      hpSpent: hpBefore - hpAfter,
    );
  }

  /// 腰包滿額現場換牌發動 (REQ-M3-03, AC-M3-4, AC-A1-4.3, AC-A1-5.5)
  ///
  /// 接受 expectedPoiId 防止底抽屜等待期間候選改變。
  /// 命令重新求最近點，若 expectedPoiId 失配或無最近點，保持零副作用並回傳 null。
  ///
  /// [shotTier] 同 [gatherPoi]：換牌路徑先過抽屜、通過後才進 QTE
  /// （REQ-M5-07.2），預設 `normal`。
  ({DistrictAttraction attraction, TravelMaterial material, int hpSpent})?
  replaceGatheredPoi({
    required String poiId,
    required int dropIndex,
    OverworldMapManifest? manifest,
    Vector2? playerPixel,
    String? expectedPoiId,
    TourPeriod? period,
    ShotTier shotTier = ShotTier.normal,
  }) {
    final resolver = _resolver;
    if (resolver == null) {
      throw StateError('PoiMaterialResolver 尚未注入');
    }

    DistrictAttraction? targetAttraction;
    TravelMaterial? targetMaterial;

    if (manifest != null &&
        playerPixel != null &&
        manifest.districtAttractions.isNotEmpty) {
      final nearest = nearestGatherablePoi(
        attractions: manifest.districtAttractions,
        run: state,
        playerPixel: playerPixel,
        manifest: manifest,
        resolver: resolver,
      );
      if (nearest == null) {
        return null;
      }
      if (expectedPoiId != null && nearest.attraction.id != expectedPoiId) {
        return null;
      }
      targetAttraction = nearest.attraction;
      targetMaterial = nearest.material;
    } else {
      if (expectedPoiId != null && poiId != expectedPoiId) {
        return null;
      }
      targetMaterial = resolver.resolveMaterialFor(poiId);
      if (targetMaterial == null) {
        throw PoiUnavailableException(poiId);
      }
      targetAttraction =
          manifest?.districtAttractions
              .where((a) => a.id == poiId)
              .firstOrNull ??
          DistrictAttraction(
            id: poiId,
            title: targetMaterial.name,
            districtCode: '',
            districtName: '',
            geo: const GeoPoint(0, 0),
            pixel: Vector2.zero(),
            rating: 5.0,
            reviewCount: 0,
            category: AttractionCategory.sightseeing,
          );
    }

    if (shotTier != ShotTier.normal) {
      targetMaterial = targetMaterial.copyWith(shotTier: shotTier);
    }

    final overrideHpCost = period != null
        ? DiurnalResonanceRule.calculateActualCost(
            baseHpCost: gatheringHpCost(targetMaterial),
            currentPeriod: period,
            material: targetMaterial,
          )
        : null;

    final hpBefore = state.resources.currentHp;
    state = state.replaceGatheredMaterial(
      poiId: targetAttraction.id,
      dropIndex: dropIndex,
      newMaterial: targetMaterial,
      overrideHpCost: overrideHpCost,
    );
    final hpAfter = state.resources.currentHp;
    return (
      attraction: targetAttraction,
      material: targetMaterial,
      hpSpent: hpBefore - hpAfter,
    );
  }

  /// 行前選定旅行哲學
  void selectPhilosophy(TravelPhilosophy philosophy) {
    state = state.selectPhilosophy(philosophy);
  }

  /// 行前選定快門難度（REQ-M5-05.2，與旅行哲學同一畫面）。
  void selectDifficulty(ShutterDifficulty difficulty) {
    state = state.selectDifficulty(difficulty);
    _append(CuratorEventType.difficultySelected, {
      'difficulty': difficulty.name,
    });
  }

  /// 記錄一次快門中斷（REQ-M5-04.2）。
  void recordShutterInterruption() {
    state = state.recordInterruption();
  }

  /// 行前靈感重擲刷新候選卡 (首局零幣免費，其餘扣除 100 幣並寫入存檔)
  void rerollPhilosophies({Random? random}) {
    final cost = state.nextRerollCost;
    state = state.rerollPhilosophies(random: random);
    _append(CuratorEventType.philosophyRerolled, {'cost': cost});
  }

  /// 確認出發踩線 (狀態轉至 fieldTrip，原子鎖定裝備快照)
  void departToFieldTrip() {
    state = state.departToFieldTrip();
  }

  /// 黑市升級局外裝備 (即時扣幣並寫入存檔)
  void upgradeEquipment(EquipmentType type) {
    final cost = state.equipment.itemOf(type).nextUpgradeCost;
    state = state.upgradeEquipment(type);
    _append(CuratorEventType.equipmentUpgraded, {
      'equipment': type.name,
      'cost': cost ?? 0,
    });
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

    state = state.copyWith(
      itinerary: nextItinerary,
      clearFocusedCulpritSlot: state.focusedCulpritSlot != null,
    );
  }

  /// 自指定槽位卸下素材
  void removeMaterialFromSlot(int slotIndex) {
    RangeError.checkValueInInterval(slotIndex, 0, 3, 'slotIndex');
    final nextState = state.setTimelineSlot(slotIndex, null);
    state = state.focusedCulpritSlot != null
        ? nextState.copyWith(clearFocusedCulpritSlot: true)
        : nextState;
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

    state = state.copyWith(
      itinerary: nextItinerary,
      clearFocusedCulpritSlot: state.focusedCulpritSlot != null,
    );
  }

  /// 呈送審查 (產生確定性結算報告，推進至 clientReview)
  void submitReview(ClientType clientType) {
    if (!state.canSubmit) {
      final issue = state.submissionIssue;
      final message = switch (issue) {
        ItinerarySubmissionIssue.nonContiguous => '素材需連續排列，無法呈送審查',
        _ => '至少安排 3 個時段，無法呈送審查',
      };
      throw StateError(message);
    }

    final clientSpec = switch (clientType) {
      ClientType.budgetWorker => ClientSpec.budgetWorker,
      ClientType.hypeInfluencer => ClientSpec.hypeInfluencer,
    };

    final stats = state.currentStats;
    final report = ClientReviewEngine.evaluate(
      client: clientSpec,
      stats: stats,
      philosophy: state.philosophy,
      difficulty: state.shutterDifficulty,
      interruptionDiscount: state.interruptionDiscount,
    );

    state = state.copyWith(
      phase: CuratorRunPhase.clientReview,
      client: clientSpec,
      latestReport: report,
    );
  }

  /// 接受審查結果 (累積佣金，推進至 settled，自動持久化)
  void acceptReview({ReviewReport? acceptedReport}) {
    final report = acceptedReport ?? state.latestReport;
    if (report == null) {
      throw StateError('尚無結算報告可供接受');
    }
    state = state.completeReview(report);
    _append(CuratorEventType.runSettled, {
      'earnedCoins': report.earnedCoins,
      'clientType': report.clientType,
      'satisfaction': report.satisfaction,
    });
  }

  /// 返回微調行程 (在 Near Miss / Rejected 下退回 nightEditing，保留槽位與腰包)
  void tweakItinerary({int? culpritSlot}) {
    state = state.tweakItinerary().copyWith(
      focusedCulpritSlot: culpritSlot,
      clearFocusedCulpritSlot: culpritSlot == null,
    );
  }

  /// 重新啟動新單局 (進入行前準備 philosophizing 階段，保留裝備與金幣)
  void restartRun({
    ClientSpec? nextClient,
    TravelPhilosophy? nextPhilosophy,
    Random? random,
  }) {
    // nextClient 為 null 時交由 createBriefing 重新抽籤；沿用 state.client
    // 會讓整個遊戲生涯的客戶鎖死在第一局抽到的那位。
    final briefing = CuratorRunState.createBriefing(
      equipment: state.equipment,
      client: nextClient,
      random: random,
    );
    state = nextPhilosophy != null
        ? briefing.copyWith(philosophy: nextPhilosophy)
        : briefing;
  }

  /// 最近一次存檔寫入失敗的原因 (null 表示未曾失敗)。
  /// 寫入是背景進行的，失敗必須留下痕跡，否則玩家的進度會靜默消失。
  Object? get lastPersistError => _lastPersistError;
  Object? _lastPersistError;

  /// 累計寫入失敗次數。一旦大於 0，玩家的局外進度就已經與日誌脫節。
  int get persistFailureCount => _persistFailureCount;
  int _persistFailureCount = 0;

  /// 背景事件寫入的完成 Future (供測試等待；無待處理寫入時立即完成)
  Future<void> get pendingPersist => _pendingPersist ?? Future<void>.value();
  Future<void>? _pendingPersist;

  /// 追加一筆局外進度事件 (CC-3 append-only)。
  /// 最終狀態由重播得出，此處不覆寫任何既有資料。
  void _append(CuratorEventType type, Map<String, Object?> payload) {
    // 只產生草稿：seq 由日誌指派，控制器無從猜測也無從撞號。
    final event = CuratorEventDraft(
      eventId: _uuid.v4(),
      type: type,
      occurredAtUtc: _nowUtc(),
      payload: payload,
    );
    // 串在前一筆之後：覆寫會讓 pendingPersist 只等到最後一筆，
    // 也會讓先前失敗的那筆無人觀察。
    _pendingPersist = pendingPersist.then((_) => _writeEvent(event));
  }

  Future<void> _writeEvent(CuratorEventDraft event) async {
    final repo = _persistenceRepository;
    if (repo == null) return;
    try {
      await repo.appendEvents([event]);
    } catch (e) {
      // 只累積、不清除：一筆成功不代表先前丟失的進度回來了。
      _lastPersistError = e;
      _persistFailureCount++;
    }
  }
}
