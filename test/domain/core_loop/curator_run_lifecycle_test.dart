import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';

void main() {
  group('單局生命週期與再來一局重置測試 (AC-ML-7)', () {
    test(
      'AC-ML-7.1 Restart Run 後新局 HP 依球鞋等級回滿，Budget 重置，Theme 為 50，腰包與 4 槽位清空',
      () {
        // 升級球鞋至 Lv.2 (HP=115)，腰包至 Lv.2 (容量=8)
        final equipment = EquipmentInventory.initial()
            .copyWith(coins: 5000)
            .upgrade(EquipmentType.sneakers)
            .upgrade(EquipmentType.waistBag);

        // 建立第一局狀態 (社畜，午夜哲學)
        var runState = CuratorRunState.create(
          client: ClientSpec.budgetWorker,
          philosophy: TravelPhilosophy.midnight,
          equipment: equipment,
        );

        // 模擬踩線耗損與採集
        runState = runState.copyWith(
          phase: CuratorRunPhase.fieldTrip,
          resources: runState.resources
              .consumeHp(50)
              .spendBudget(1200)
              .adjustTheme(30),
        );
        runState = runState.addMaterial(
          const TravelMaterial(
            id: 'm1',
            name: '拉麵',
            tags: ['#深夜'],
            themeValue: 10,
            hypeValue: 20,
          ),
        );
        runState = runState.setTimelineSlot(
          0,
          const TravelMaterial(
            id: 'm1',
            name: '拉麵',
            tags: ['#深夜'],
            themeValue: 10,
            hypeValue: 20,
          ),
        );

        expect(runState.resources.hp, 65); // 115 - 50 = 65
        expect(runState.resources.budget, 800); // 2000 - 1200 = 800
        expect(runState.inventory.count, 1);
        expect(runState.itinerary.slots[0], isNotNull);

        // 執行 Restart Run (開啟第二局，選網紅與慢旅行)
        final secondRun = runState.restartRun(
          nextClient: ClientSpec.hypeInfluencer,
          nextPhilosophy: TravelPhilosophy.slow,
        );

        // 驗證新局初始化符合 AC-ML-7.1
        expect(
          secondRun.runId,
          isNot(equals(runState.runId)),
        ); // UUID 重新生成 (CC-1)
        expect(secondRun.client.type, ClientType.hypeInfluencer);
        expect(secondRun.philosophy, TravelPhilosophy.slow);
        expect(secondRun.phase, CuratorRunPhase.fieldTrip);
        expect(secondRun.resources.hp, 115); // 依 Lv.2 球鞋回滿 115
        expect(secondRun.resources.maxHp, 115);
        expect(secondRun.resources.budget, 8000); // 網紅起始預算 8000
        expect(secondRun.resources.theme, 50); // Theme 回復 50
        expect(secondRun.resources.hype, 0); // Hype 回復 0
        expect(secondRun.inventory.count, 0); // 腰包清空
        expect(
          secondRun.itinerary.slots.every((s) => s == null),
          isTrue,
        ); // 4 槽位清空
        expect(secondRun.latestReport, isNull);
      },
    );

    test('AC-ML-7.2 Restart Run 後上一局所賺取的佣金累積與已升級裝備等級維持不變', () {
      final equipment = EquipmentInventory.initial().copyWith(coins: 100);

      var runState = CuratorRunState.create(
        client: ClientSpec.budgetWorker,
        philosophy: TravelPhilosophy.midnight,
        equipment: equipment,
      );

      // 結算並獲得 1500 佣金
      const mockReport = ReviewReport(
        clientType: 'budgetWorker',
        satisfaction: 95,
        outcome: ReviewOutcome.perfect,
        earnedCoins: 1520,
        feedbackQuote: '太棒了',
        subscores: {},
      );
      runState = runState.completeReview(mockReport);

      expect(runState.equipment.coins, 1620); // 100 + 1520
      expect(runState.phase, CuratorRunPhase.settled);

      // 在局外用 500 幣升級相機至 Lv.2
      final upgradedState = runState.upgradeEquipment(EquipmentType.camera);
      expect(upgradedState.equipment.camera.level, 2);
      expect(upgradedState.equipment.coins, 1120);

      // 觸發「再來一局」
      final nextRun = upgradedState.restartRun(
        nextClient: ClientSpec.budgetWorker,
        nextPhilosophy: TravelPhilosophy.gourmet,
      );

      // 驗證資產與裝備完整繼承
      expect(nextRun.equipment.coins, 1120);
      expect(nextRun.equipment.camera.level, 2);
    });
  });
}
