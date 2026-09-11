import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

void main() {
  late ProviderContainer container;

  // 測試專用決定性素材池
  final testMaterials = [
    const TravelMaterial(
      id: 'mat_walk_1',
      name: '清晨哲學之道散步',
      tags: ['#散步', '#老街'],
      themeValue: 30,
      hypeValue: 20,
      riskLevel: 1,
    ),
    const TravelMaterial(
      id: 'mat_food_1',
      name: '錦市場午後玉子燒',
      tags: ['#美食', '#老街'],
      themeValue: 25,
      hypeValue: 25,
      cost: 500,
      riskLevel: 1,
    ),
    const TravelMaterial(
      id: 'mat_spot_1',
      name: '清水寺黃昏夕照舞台',
      tags: ['#老街', '#絕景'],
      themeValue: 40,
      hypeValue: 70,
      isSpotlight: true,
      cost: 400,
      riskLevel: 2,
    ),
    const TravelMaterial(
      id: 'mat_night_1',
      name: '先斗町深夜幽靈居酒屋',
      tags: ['#深夜', '#老街', '#美食'],
      themeValue: 35,
      hypeValue: 35,
      cost: 1200,
      riskLevel: 2,
    ),
  ];

  setUp(() {
    container = ProviderContainer(
      overrides: [curatorMaterialPoolProvider.overrideWithValue(testMaterials)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CuratorRunController 狀態機測試 (AC-UI-1)', () {
    test(
      'AC-UI-1.1: 初始階段為 philosophizing，4 槽位皆為 null，腰包為空，canSubmit 為 false',
      () {
        final state = container.read(curatorRunControllerProvider);

        expect(state.phase, equals(CuratorRunPhase.philosophizing));
        expect(state.itinerary.slots, equals([null, null, null, null]));
        expect(state.inventory.materials, isEmpty);
        expect(state.canSubmit, isFalse);
      },
    );

    test('AC-UI-1.2: 注入固定 Random 種子呼叫 drawSampleMaterial，成功將決定性素材加入腰包', () {
      final controller = container.read(curatorRunControllerProvider.notifier);

      controller.drawSampleMaterial(random: Random(42));

      final state = container.read(curatorRunControllerProvider);
      expect(state.inventory.count, equals(1));
      expect(
        state.inventory.materials.first.id,
        equals(testMaterials[Random(42).nextInt(4)].id),
      );
    });

    test(
      'AC-UI-1.3: placeMaterialInSlot 填充槽位並更新 currentStats；嘗試在另一槽位放入同素材時觸發移動/互換，禁止重複引用',
      () {
        final controller = container.read(
          curatorRunControllerProvider.notifier,
        );
        final mat1 = testMaterials[0];
        final mat2 = testMaterials[1];

        // 放入 Slot 0
        controller.placeMaterialInSlot(0, mat1);
        var state = container.read(curatorRunControllerProvider);
        expect(state.itinerary.slots[0]?.id, equals(mat1.id));
        expect(state.canSubmit, isFalse);
        expect(state.currentStats.totalHype, greaterThan(0));

        // 放入 Slot 1
        controller.placeMaterialInSlot(1, mat2);
        state = container.read(curatorRunControllerProvider);
        expect(state.itinerary.slots[0]?.id, equals(mat1.id));
        expect(state.itinerary.slots[1]?.id, equals(mat2.id));

        // 嘗試將 mat1 再次放入 Slot 1 -> 應該觸發移動/交換，Slot 0 變 mat2 或 mat1 移至 Slot 1
        controller.placeMaterialInSlot(1, mat1);
        state = container.read(curatorRunControllerProvider);

        // 槽位中絕無重複 mat1
        final mat1Count = state.itinerary.slots
            .where((s) => s?.id == mat1.id)
            .length;
        expect(mat1Count, equals(1));
      },
    );

    test('AC-UI-1.4: 填滿 4 槽位後 canSubmit 為 true；移除任一槽位後回退為 false', () {
      final controller = container.read(curatorRunControllerProvider.notifier);

      for (var i = 0; i < 4; i++) {
        controller.placeMaterialInSlot(i, testMaterials[i]);
      }

      var state = container.read(curatorRunControllerProvider);
      expect(state.canSubmit, isTrue);

      controller.removeMaterialFromSlot(2);
      state = container.read(curatorRunControllerProvider);
      expect(state.itinerary.slots[2], isNull);
      expect(state.canSubmit, isFalse);
    });

    test('AC-UI-1.5: swapSlots 支援任意兩槽位互換（含空槽），重新計算相鄰連鎖與疲勞', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      controller.placeMaterialInSlot(0, testMaterials[0]);
      controller.placeMaterialInSlot(1, testMaterials[1]);

      controller.swapSlots(0, 1);
      var state = container.read(curatorRunControllerProvider);
      expect(state.itinerary.slots[0]?.id, equals(testMaterials[1].id));
      expect(state.itinerary.slots[1]?.id, equals(testMaterials[0].id));

      // 互換有素材與空槽 (Slot 0 與 Slot 3)
      controller.swapSlots(0, 3);
      state = container.read(curatorRunControllerProvider);
      expect(state.itinerary.slots[0], isNull);
      expect(state.itinerary.slots[3]?.id, equals(testMaterials[1].id));
    });

    test(
      'AC-UI-1.6: submitReview 推進至 clientReview，acceptReview 累積佣金至 equipment.coins 並推進至 settled',
      () {
        final controller = container.read(
          curatorRunControllerProvider.notifier,
        );

        for (var i = 0; i < 4; i++) {
          controller.placeMaterialInSlot(i, testMaterials[i]);
        }

        controller.submitReview(ClientType.budgetWorker);
        var state = container.read(curatorRunControllerProvider);
        expect(state.phase, equals(CuratorRunPhase.clientReview));
        expect(state.latestReport, isNotNull);

        final initialCoins = state.equipment.coins;
        final earnedCoins = state.latestReport!.earnedCoins;

        controller.acceptReview();
        state = container.read(curatorRunControllerProvider);
        expect(state.phase, equals(CuratorRunPhase.settled));
        expect(state.equipment.coins, equals(initialCoins + earnedCoins));
      },
    );

    test(
      'AC-UI-1.7: 在審查結果為 Near Miss 時呼叫 tweakItinerary，階段安全回退至 nightEditing，槽位與腰包保留',
      () {
        final controller = container.read(
          curatorRunControllerProvider.notifier,
        );

        for (var i = 0; i < 4; i++) {
          controller.placeMaterialInSlot(i, testMaterials[i]);
        }

        controller.submitReview(ClientType.budgetWorker);
        var state = container.read(curatorRunControllerProvider);
        expect(state.phase, equals(CuratorRunPhase.clientReview));

        controller.tweakItinerary();
        state = container.read(curatorRunControllerProvider);
        expect(state.phase, equals(CuratorRunPhase.nightEditing));
        expect(state.itinerary.slots.every((s) => s != null), isTrue);
      },
    );

    test(
      'AC-FIX-2.1: restartRun 未指定客戶時必須重新隨機揭曉今日客戶，不得沿用上一局',
      () {
        final controller = container.read(
          curatorRunControllerProvider.notifier,
        );

        final seen = <ClientSpec>{};
        for (var seed = 0; seed < 20; seed++) {
          controller.restartRun(random: Random(seed));
          seen.add(container.read(curatorRunControllerProvider).client);
        }

        expect(
          seen.length,
          2,
          reason: '20 次重開局應同時出現兩種客戶，否則客戶已被鎖死為第一局那位',
        );
      },
    );

    test(
      'AC-UI-1.8: restartRun 清空 4 槽位與腰包，HP 恢復滿值，佣金裝備不變，runId 變更為全新 UUID (CC-1)',
      () {
        final controller = container.read(
          curatorRunControllerProvider.notifier,
        );
        final oldRunId = container.read(curatorRunControllerProvider).runId;

        for (var i = 0; i < 4; i++) {
          controller.placeMaterialInSlot(i, testMaterials[i]);
        }

        controller.restartRun(nextPhilosophy: TravelPhilosophy.antiTourism);
        final state = container.read(curatorRunControllerProvider);

        expect(state.runId, isNot(equals(oldRunId)));
        expect(state.phase, equals(CuratorRunPhase.philosophizing));
        expect(state.philosophy, equals(TravelPhilosophy.antiTourism));
        expect(state.itinerary.slots, equals([null, null, null, null]));
        expect(state.inventory.materials, isEmpty);
        expect(state.resources.hp, equals(state.equipment.sneakers.maxHp));
      },
    );
  });
}
