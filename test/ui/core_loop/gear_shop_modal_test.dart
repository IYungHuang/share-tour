import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/events/curator_event.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/core_loop/persistence_providers.dart';
import 'package:share_tour/ui/core_loop/gear_shop/gear_shop_modal.dart';

import '../../fakes/fake_persistence_repository.dart';

void main() {
  Widget createSubject({
    CuratorRunState? initialState,
    FakePersistenceRepository? fakeRepo,
  }) {
    final repo = fakeRepo ?? FakePersistenceRepository();
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        persistenceRepositoryProvider.overrideWithValue(repo),
        if (initialState != null)
          curatorRunControllerProvider.overrideWith(
            (ref) => CuratorRunController(
              materialPool: const [],
              initialState: initialState,
              persistenceRepository: repo,
            ),
          ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: GearShopModal(),
        ),
      ),
    );
  }

  group('GearShopModal UI 測試 (Task M6, AC-M4-4.2)', () {
    testWidgets('360dp 螢幕下完整渲染 3 張裝備卡與金幣看板且零 RenderFlex 溢出', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.textContaining('黑市裝備舖'), findsOneWidget);
      expect(find.byKey(const Key('gear_shop_coins_indicator')), findsOneWidget);
      expect(find.byKey(const Key('gear_card_sneakers')), findsOneWidget);
      expect(find.byKey(const Key('gear_card_camera')), findsOneWidget);
      expect(find.byKey(const Key('gear_card_waistBag')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('金幣不足時升級按鈕為 Disabled，金幣充足時點擊升級成功扣款並升級', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakePersistenceRepository();
      // 只有 200 幣 (不足 300 幣升級)
      final poorState = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial().copyWith(coins: 200),
      );

      await tester.pumpWidget(createSubject(initialState: poorState, fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(const Key('upgrade_button_sneakers'));
      final buttonWidget = tester.widget<ElevatedButton>(buttonFinder);
      expect(buttonWidget.onPressed, isNull); // 灰階禁用

      // 提供 500 幣 (足夠 300 幣升級)
      final richState = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial().copyWith(coins: 500),
      );

      await tester.pumpWidget(createSubject(initialState: richState, fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      final richButton = tester.widget<ElevatedButton>(buttonFinder);
      expect(richButton.onPressed, isNotNull); // 可點擊

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // 驗證金幣扣減為 200，球鞋升至 Lv.2
      expect(find.textContaining('200'), findsWidgets);
      expect(find.textContaining('Lv. 2'), findsWidgets);
      expect(fakeRepo.appendCount, 1);
      expect(fakeRepo.events.last.type, CuratorEventType.equipmentUpgraded);
      expect(fakeRepo.events.last.payload['equipment'], 'sneakers');
    });

    testWidgets('滿級 Lv.3 裝備顯示 MAX 標籤且按鈕禁用', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final maxEquip = EquipmentInventory(
        coins: 10000,
        sneakers: const EquipmentItem(type: EquipmentType.sneakers, level: 3),
        camera: const EquipmentItem(type: EquipmentType.camera, level: 3),
        waistBag: const EquipmentItem(type: EquipmentType.waistBag, level: 3),
      );

      final state = CuratorRunState.createBriefing(equipment: maxEquip);
      await tester.pumpWidget(createSubject(initialState: state));
      await tester.pumpAndSettle();

      expect(find.text('MAX'), findsNWidgets(3));
      final maxBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('upgrade_button_sneakers')),
      );
      expect(maxBtn.onPressed, isNull);
    });
  });
}
