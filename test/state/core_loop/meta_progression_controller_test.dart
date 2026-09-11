import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/curator_save_data.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/core_loop/persistence_providers.dart';

import '../../fakes/fake_persistence_repository.dart';

void main() {
  group('Milestone M4 狀態層持久化與行前控制測試 (AC-M4-1 ~ AC-M4-3)', () {
    late FakePersistenceRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakePersistenceRepository();
      container = ProviderContainer(
        overrides: [
          persistenceRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('AC-M4-1: canExploreProvider 在行前準備 (philosophizing) 必須為 false，出發後為 true', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      final initialState = container.read(curatorRunControllerProvider);

      expect(initialState.phase, CuratorRunPhase.philosophizing);
      // 關鍵邊界防護：行前階段禁止大世界移動探索
      expect(container.read(canExploreProvider), isFalse);

      final choice = initialState.philosophyChoices.first;
      controller.selectPhilosophy(choice);
      expect(container.read(canExploreProvider), isFalse);

      controller.departToFieldTrip();
      final departedState = container.read(curatorRunControllerProvider);
      expect(departedState.phase, CuratorRunPhase.fieldTrip);
      // 出發踩線後允許探索
      expect(container.read(canExploreProvider), isTrue);
    });

    test('AC-M4-1.5: 透過 Controller 靈感重擲，扣除金幣並自動寫入存檔', () async {
      // 初始注入 300 幣存檔
      final initialSave = CuratorSaveData(
        profileId: 'player-1',
        coins: 300,
        sneakersLevel: 1,
        cameraLevel: 1,
        waistBagLevel: 1,
        completedRuns: 1,
        updatedAtUtc: DateTime.now().toUtc(),
      );
      final customContainer = ProviderContainer(
        overrides: [
          persistenceRepositoryProvider.overrideWithValue(fakeRepo),
          initialSaveDataProvider.overrideWithValue(initialSave),
        ],
      );
      addTearDown(customContainer.dispose);

      final controller =
          customContainer.read(curatorRunControllerProvider.notifier);
      final stateBefore = customContainer.read(curatorRunControllerProvider);
      expect(stateBefore.equipment.coins, 300);

      controller.rerollPhilosophies();

      final stateAfter = customContainer.read(curatorRunControllerProvider);
      expect(stateAfter.equipment.coins, 200); // 300 - 100 = 200
      expect(fakeRepo.saveCount, 1);
      expect(fakeRepo.savedHistory.last.coins, 200);
    });

    test('AC-M4-2.1 & 3.1: 透過 Controller 升級裝備，即時扣幣、升級並寫入存檔', () async {
      final initialSave = CuratorSaveData(
        profileId: 'player-upgrade-test',
        coins: 500,
        sneakersLevel: 1,
        cameraLevel: 1,
        waistBagLevel: 1,
        completedRuns: 0,
        updatedAtUtc: DateTime.now().toUtc(),
      );
      final customContainer = ProviderContainer(
        overrides: [
          persistenceRepositoryProvider.overrideWithValue(fakeRepo),
          initialSaveDataProvider.overrideWithValue(initialSave),
        ],
      );
      addTearDown(customContainer.dispose);

      final controller =
          customContainer.read(curatorRunControllerProvider.notifier);
      expect(
        customContainer.read(curatorRunControllerProvider).equipment.sneakers.level,
        1,
      );

      controller.upgradeEquipment(EquipmentType.sneakers);

      final stateAfter = customContainer.read(curatorRunControllerProvider);
      expect(stateAfter.equipment.sneakers.level, 2);
      expect(stateAfter.equipment.coins, 200); // 500 - 300 = 200
      expect(fakeRepo.saveCount, 1);
      expect(fakeRepo.savedHistory.last.sneakersLevel, 2);
      expect(fakeRepo.savedHistory.last.coins, 200);
    });

    test('AC-M4-3.1: 審查結算後 acceptReview() 自動累加佣金至局外資產並持久化儲存', () async {
      final controller = container.read(curatorRunControllerProvider.notifier);

      // 呈送 4 槽位
      for (var i = 0; i < 4; i++) {
        controller.placeMaterialInSlot(
          i,
          TravelMaterial(
            id: 'mat_$i',
            name: '素材 $i',
            tags: const ['#散步'],
            themeValue: 15,
            hypeValue: 20,
            cost: 100,
          ),
        );
      }

      controller.submitReview(ClientType.budgetWorker);
      expect(
        container.read(curatorRunControllerProvider).phase,
        CuratorRunPhase.clientReview,
      );

      final report = container.read(curatorRunControllerProvider).latestReport!;
      expect(report.earnedCoins, greaterThan(0));

      controller.acceptReview();

      final settledState = container.read(curatorRunControllerProvider);
      expect(settledState.phase, CuratorRunPhase.settled);
      expect(settledState.equipment.coins, report.earnedCoins);
      expect(fakeRepo.saveCount, 1);
      expect(fakeRepo.savedHistory.last.coins, report.earnedCoins);
      expect(fakeRepo.savedHistory.last.completedRuns, 1);
    });
  });
}
