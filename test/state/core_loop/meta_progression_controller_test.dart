import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/events/curator_event.dart';
import 'package:share_tour/domain/core_loop/events/curator_event_replay.dart';
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

    test('AC-CC-3.15: 事件日誌重播回來的狀態必須等於控制器當下狀態', () async {
      final initialSave = CuratorSaveData(
        profileId: 'round-trip',
        coins: 2000,
        sneakersLevel: 1,
        cameraLevel: 1,
        waistBagLevel: 1,
        completedRuns: 0,
        lastMonotonicSeq: 1,
        updatedAtUtc: DateTime.utc(2026, 9, 11),
      );
      final customContainer = ProviderContainer(
        overrides: [
          persistenceRepositoryProvider.overrideWithValue(fakeRepo),
          initialSaveDataProvider.overrideWithValue(initialSave),
        ],
      );
      addTearDown(customContainer.dispose);

      // 讓日誌自己建立身分事件 (seq 1)，之後的操作接著編號
      await fakeRepo.loadSave();

      final controller = customContainer.read(
        curatorRunControllerProvider.notifier,
      );

      controller.rerollPhilosophies();
      controller.upgradeEquipment(EquipmentType.sneakers);
      controller.upgradeEquipment(EquipmentType.camera);
      await controller.pendingPersist;

      final replayed = replayCuratorEvents(fakeRepo.events);
      final live = customContainer.read(curatorRunControllerProvider).equipment;

      // 寫出去的東西重播回來，必須還是同一個局外狀態
      expect(replayed.coins, live.coins - initialSave.coins);
      expect(replayed.sneakersLevel, live.sneakers.level);
      expect(replayed.cameraLevel, live.camera.level);
      expect(
        fakeRepo.events.map((e) => e.seq).toList(),
        [1, 2, 3, 4],
        reason: 'genesis 佔 1，之後的操作接著嚴格遞增，不得撞號',
      );
    });

    test('AC-FIX-3.1: 存檔寫入失敗時必須被捕捉並可觀測，不得靜默丟失', () async {
      fakeRepo.simulateWriteFailure = true;
      final controller = container.read(curatorRunControllerProvider.notifier);

      controller.rerollPhilosophies();
      await controller.pendingPersist;

      expect(
        controller.lastPersistError,
        isNotNull,
        reason: '寫入失敗必須被記錄，否則玩家的金幣與等級會靜默消失',
      );
    });

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
      await controller.pendingPersist;
      expect(fakeRepo.appendCount, 1);
      expect(fakeRepo.events.last.type, CuratorEventType.philosophyRerolled);
      expect(fakeRepo.events.last.payload['cost'], 100);
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
      await controller.pendingPersist;
      expect(fakeRepo.appendCount, 1);
      expect(fakeRepo.events.last.type, CuratorEventType.equipmentUpgraded);
      expect(fakeRepo.events.last.payload['equipment'], 'sneakers');
      expect(fakeRepo.events.last.payload['cost'], 300);
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
      await controller.pendingPersist;
      expect(fakeRepo.appendCount, 1);
      expect(fakeRepo.events.last.type, CuratorEventType.runSettled);
      expect(fakeRepo.events.last.payload['earnedCoins'], report.earnedCoins);
    });
  });
}
