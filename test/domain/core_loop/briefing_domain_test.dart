import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/core_loop_exceptions.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';

void main() {
  group('Milestone M4 行前委託與哲學狀態機領域測試 (AC-M4-1, AC-M4-2.4)', () {
    test('AC-M4-1.1: createBriefing 隨機揭曉客戶且生成 3 張不重複哲學卡', () {
      final state = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial(),
        random: Random(42),
      );

      expect(state.phase, CuratorRunPhase.philosophizing);
      expect(state.philosophyChoices.length, 3);
      expect(state.philosophyChoices.toSet().length, 3);
      expect(state.selectedPhilosophy, isNull);
      expect(state.rerollsUsed, 0);
      expect(state.canDepart, isFalse);
    });

    test('AC-M4-1.2: 未選定哲學時呼叫 departToFieldTrip 拋出 PreconditionFailedException', () {
      final state = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial(),
      );
      expect(state.selectedPhilosophy, isNull);

      expect(
        () => state.departToFieldTrip(),
        throwsA(isA<PreconditionFailedException>()),
      );
    });

    test('AC-M4-1.3 & 1.4: 選定哲學後成功出發，原子鎖定 equipmentSnapshot，HP與腰包上限精確匹配', () {
      final equip = EquipmentInventory(
        coins: 100,
        sneakers: const EquipmentItem(type: EquipmentType.sneakers, level: 2), // HP 125
        camera: const EquipmentItem(type: EquipmentType.camera, level: 1),
        waistBag: const EquipmentItem(type: EquipmentType.waistBag, level: 2), // Cap 8
      );
      final state = CuratorRunState.createBriefing(
        equipment: equip,
        client: ClientSpec.budgetWorker,
      );

      final choice = state.philosophyChoices.first;
      final selectedState = state.selectPhilosophy(choice);
      expect(selectedState.selectedPhilosophy, choice);
      expect(selectedState.canDepart, isTrue);

      final departedState = selectedState.departToFieldTrip();
      expect(departedState.phase, CuratorRunPhase.fieldTrip);
      expect(departedState.philosophy, choice);
      expect(departedState.equipmentSnapshot, equip);
      expect(departedState.resources.currentHp, 125);
      expect(departedState.resources.maxHp, 125);
      expect(departedState.inventory.capacity, 8);
    });

    test('AC-M4-1.5: 靈感重擲：局外 0 幣時首次免費；有幣時扣 100 幣；幣不足拋異常', () {
      // 情況 A：局外 0 幣，首次重擲免費
      final zeroCoinState = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial(), // 0 coins
      );
      expect(zeroCoinState.nextRerollCost, 0);
      expect(zeroCoinState.canReroll, isTrue);

      final afterFreeReroll = zeroCoinState.rerollPhilosophies();
      expect(afterFreeReroll.rerollsUsed, 1);
      expect(afterFreeReroll.equipment.coins, 0);
      expect(afterFreeReroll.philosophyChoices.length, 3);
      expect(afterFreeReroll.nextRerollCost, 100);
      expect(afterFreeReroll.canReroll, isFalse);

      expect(
        () => afterFreeReroll.rerollPhilosophies(),
        throwsA(isA<InsufficientCoinsException>()),
      );

      // 情況 B：局外有 150 幣，重擲扣 100 幣
      final fundedState = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial().copyWith(coins: 150),
      );
      expect(fundedState.nextRerollCost, 100);
      expect(fundedState.canReroll, isTrue);

      final rerolledFunded = fundedState.rerollPhilosophies();
      expect(rerolledFunded.rerollsUsed, 1);
      expect(rerolledFunded.equipment.coins, 50);
      expect(rerolledFunded.nextRerollCost, 100);
      expect(rerolledFunded.canReroll, isFalse); // 50 < 100
    });

    test('AC-FIX-1.1: 靈感重擲必須清空既有哲學選擇，重擲後不得直接出發', () {
      final state = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial(),
        random: Random(7),
      );
      final chosen = state.philosophyChoices.first;
      final selected = state.selectPhilosophy(chosen);
      expect(selected.canDepart, isTrue);

      final rerolled = selected.rerollPhilosophies(random: Random(99));

      expect(
        rerolled.selectedPhilosophy,
        isNull,
        reason: '重擲換掉候選卡後，舊的選擇必須失效',
      );
      expect(rerolled.canDepart, isFalse);
    });

    test('AC-FIX-1.2: 選定的哲學不在候選卡內時不得出發', () {
      final state = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial(),
        random: Random(7),
      );
      final outsider = TravelPhilosophy.values.firstWhere(
        (p) => !state.philosophyChoices.contains(p),
      );

      expect(
        () => state.selectPhilosophy(outsider).departToFieldTrip(),
        throwsA(isA<PreconditionFailedException>()),
      );
    });

    test('AC-M4-2.4: 局內即時指標防作弊：升級裝備新數值存檔保留，但當局計算嚴格依據 equipmentSnapshot', () {
      final equip = EquipmentInventory(
        coins: 1500,
        sneakers: const EquipmentItem(type: EquipmentType.sneakers, level: 1),
        camera: const EquipmentItem(type: EquipmentType.camera, level: 1), // 1.5x
        waistBag: const EquipmentItem(type: EquipmentType.waistBag, level: 1),
      );

      final briefing = CuratorRunState.createBriefing(
        equipment: equip,
        client: ClientSpec.hypeInfluencer,
      );
      final running = briefing
          .selectPhilosophy(briefing.philosophyChoices.first)
          .departToFieldTrip();

      final runningWithSlot = running.setTimelineSlot(
        2,
        const TravelMaterial(
          id: 'm_sunset',
          name: '日落點',
          tags: ['#絕景'],
          themeValue: 10,
          hypeValue: 100,
        ),
      );

      // 局中黑市升級相機至 Lv.2 (1.8x)
      final afterUpgrade =
          runningWithSlot.upgradeEquipment(EquipmentType.camera);
      expect(afterUpgrade.equipment.camera.level, 2);
      expect(afterUpgrade.equipment.camera.cameraMultiplier, 1.8);
      // 快照必須維持 Lv.1 (1.5x)
      expect(afterUpgrade.equipmentSnapshot.camera.level, 1);
      expect(afterUpgrade.equipmentSnapshot.camera.cameraMultiplier, 1.5);
      // currentStats 讀取快照倍率: 100 * 1.5 = 150 (而非 1.8x 的 180)
      expect(afterUpgrade.currentStats.slotEffectiveHypes[2], 150);
    });
  });
}
