import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/core_loop_exceptions.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('Milestone M3 領域層踩線取材與原子轉移測試 (AC-M3-3, AC-M3-4, AC-M3-5)', () {
    const testMaterialLowRisk = TravelMaterial(
      id: 'mat_1',
      name: '文青咖啡館',
      tags: ['#美食', '#慢旅行'],
      themeValue: 15,
      hypeValue: 20,
      storyValue: 2,
      cost: 500,
      riskLevel: 2, // deltaHp = 10 + 2*2 = 14
    );

    const testMaterialHighRisk = TravelMaterial(
      id: 'mat_2',
      name: '午夜怪談廢墟',
      tags: ['#深夜', '#怪談'],
      themeValue: 25,
      hypeValue: 60,
      isSpotlight: true,
      storyValue: 4,
      cost: 1500,
      riskLevel: 4, // deltaHp = 10 + 4*2 = 18
    );

    late CuratorRunState initialState;

    setUp(() {
      initialState = CuratorRunState.initial(
        runId: 'run-test-001',
        targetPhilosophy: TravelPhilosophy.midnight,
        initialBudget: 2000,
        initialHp: 100,
      ).copyWith(phase: CuratorRunPhase.fieldTrip);
    });

    test('AC-M3-3.1 正常取材：扣除正確 HP (14 點)，預算扣除 500，素材入腰包，寫入 gatheredPoiIds', () {
      final nextState = initialState.gatherPoiMaterial(
        poiId: 'poi_taipei_cafe',
        material: testMaterialLowRisk,
      );

      expect(nextState.resources.currentHp, 86); // 100 - 14
      expect(nextState.resources.isExhausted, isFalse);
      expect(nextState.resources.currentBudget, 1500); // 2000 - 500
      expect(nextState.inventory.count, 1);
      expect(nextState.inventory.items.first.id, 'mat_1');
      expect(nextState.gatheredPoiIds.contains('poi_taipei_cafe'), isTrue);
      expect(nextState.phase, CuratorRunPhase.fieldTrip);
    });

    test('AC-M3-3.2 預算赤字：花費超過當前預算時允許進入赤字（負數）', () {
      final state1 = initialState.gatherPoiMaterial(
        poiId: 'poi_spot_1',
        material: testMaterialHighRisk, // cost: 1500 -> budget 500
      );
      expect(state1.resources.currentBudget, 500);

      final state2 = state1.gatherPoiMaterial(
        poiId: 'poi_spot_2',
        material: testMaterialHighRisk, // cost: 1500 -> budget -1000
      );
      expect(state2.resources.currentBudget, -1000);
      expect(state2.resources.isDeficit, isTrue);
    });

    test('AC-M3-3.3 最後一搏 (Last Stand)：HP 剩餘 5 點，面對消耗 14 點取材，HP 截斷為 0，isExhausted=true，phase=nightEditing', () {
      // 人為構造 HP = 5
      final lowHpState = initialState.copyWith(
        resources: initialState.resources.consumeHp(95),
      );
      expect(lowHpState.resources.currentHp, 5);
      expect(lowHpState.resources.isExhausted, isFalse);

      final exhaustedState = lowHpState.gatherPoiMaterial(
        poiId: 'poi_last_stand',
        material: testMaterialLowRisk, // deltaHp = 14 > 5
      );

      expect(exhaustedState.resources.currentHp, 0);
      expect(exhaustedState.resources.isExhausted, isTrue);
      expect(exhaustedState.phase, CuratorRunPhase.nightEditing);
      expect(exhaustedState.inventory.count, 1);
      expect(exhaustedState.gatheredPoiIds.contains('poi_last_stand'), isTrue);
    });

    test('AC-M3-4.1 & 4.2 腰包滿額時呼叫 gatherPoiMaterial 拋出 InventoryFullException 且零副作用', () {
      var state = initialState;
      // 填滿 6 格腰包
      for (int i = 0; i < 6; i++) {
        state = state.copyWith(
          inventory: state.inventory.add(
            testMaterialLowRisk.copyWith(id: 'mat_fill_$i'),
          ),
        );
      }
      expect(state.inventory.isFull, isTrue);

      expect(
        () => state.gatherPoiMaterial(
          poiId: 'poi_overflow',
          material: testMaterialLowRisk,
        ),
        throwsA(isA<InventoryFullException>()),
      );

      // 驗證狀態未受污染
      expect(state.resources.currentHp, 100);
      expect(state.gatheredPoiIds.contains('poi_overflow'), isFalse);
    });

    test('AC-M3-4.3 腰包滿額時呼叫 replaceGatheredMaterial 成功替換指定卡片，HP/預算正常扣除', () {
      var state = initialState;
      for (int i = 0; i < 6; i++) {
        state = state.copyWith(
          inventory: state.inventory.add(
            testMaterialLowRisk.copyWith(id: 'mat_fill_$i', name: '舊卡 $i'),
          ),
        );
      }

      // 替換 index 2 的素材
      final nextState = state.replaceGatheredMaterial(
        poiId: 'poi_replace_spot',
        dropIndex: 2,
        newMaterial: testMaterialHighRisk,
      );

      expect(nextState.inventory.count, 6);
      expect(nextState.inventory.items[2].id, 'mat_2');
      expect(nextState.inventory.items[2].name, '午夜怪談廢墟');
      expect(nextState.gatheredPoiIds.contains('poi_replace_spot'), isTrue);
      expect(nextState.resources.currentHp, 82); // 100 - 18
      expect(nextState.resources.currentBudget, 500); // 2000 - 1500
    });

    test('AC-M3-5.1 & 5.2 單局防刷：同一 POI 重複取材拋出 PoiAlreadyGatheredException，零副作用', () {
      final state1 = initialState.gatherPoiMaterial(
        poiId: 'poi_unique_01',
        material: testMaterialLowRisk,
      );

      expect(
        () => state1.gatherPoiMaterial(
          poiId: 'poi_unique_01',
          material: testMaterialLowRisk,
        ),
        throwsA(isA<PoiAlreadyGatheredException>()),
      );

      expect(state1.resources.currentHp, 86);
      expect(state1.inventory.count, 1);
    });

    test('AC-M3-5.3 重置新局 (restartRun)：gatheredPoiIds 完整清空，可重新踩線', () {
      final state1 = initialState.gatherPoiMaterial(
        poiId: 'poi_unique_01',
        material: testMaterialLowRisk,
      );
      expect(state1.gatheredPoiIds.length, 1);

      final resetState = state1.restartRun(targetPhilosophy: TravelPhilosophy.slow);
      expect(resetState.gatheredPoiIds, isEmpty);
      expect(resetState.inventory.count, 0);
      expect(resetState.resources.currentHp, 100);
      expect(resetState.phase, CuratorRunPhase.fieldTrip);
    });

    test('透支狀態下嘗試取材拋出 CuratorExhaustedException', () {
      final exhaustedState = initialState.copyWith(
        resources: initialState.resources.consumeHp(100),
      );
      expect(exhaustedState.resources.isExhausted, isTrue);

      expect(
        () => exhaustedState.gatherPoiMaterial(
          poiId: 'poi_try_when_exhausted',
          material: testMaterialLowRisk,
        ),
        throwsA(isA<CuratorExhaustedException>()),
      );
    });

    test('DistrictAttraction 基於 id 的等值性 (operator == & hashCode)', () {
      final attr1 = DistrictAttraction(
        id: 'tp_101',
        title: '台北101',
        districtCode: 'taipei',
        districtName: '台北市',
        geo: const GeoPoint(25.0339, 121.5645),
        pixel: Vector2(100, 100),
        rating: 4.8,
        reviewCount: 90000,
        category: AttractionCategory.landmark,
      );

      final attr2 = DistrictAttraction(
        id: 'tp_101',
        title: '台北101 (不同實體)',
        districtCode: 'taipei',
        districtName: '台北市',
        geo: const GeoPoint(25.0339, 121.5645),
        pixel: Vector2(100, 100),
        rating: 4.8,
        reviewCount: 90000,
        category: AttractionCategory.landmark,
      );

      final attr3 = DistrictAttraction(
        id: 'tp_palace',
        title: '故宮',
        districtCode: 'taipei',
        districtName: '台北市',
        geo: const GeoPoint(25.1024, 121.5485),
        pixel: Vector2(200, 200),
        rating: 4.7,
        reviewCount: 50000,
        category: AttractionCategory.culture,
      );

      expect(attr1, equals(attr2));
      expect(attr1.hashCode, equals(attr2.hashCode));
      expect(attr1, isNot(equals(attr3)));
    });
  });
}
