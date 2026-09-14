import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/core_loop/persistence_providers.dart';
import 'package:share_tour/ui/core_loop/briefing/curator_briefing_modal.dart';

import '../../fakes/fake_persistence_repository.dart';

void main() {
  Widget createSubject({
    CuratorRunState? initialState,
    VoidCallback? onOpenGearShop,
    Key? key,
  }) {
    return ProviderScope(
      key: key ?? UniqueKey(),
      overrides: [
        persistenceRepositoryProvider
            .overrideWithValue(FakePersistenceRepository()),
        if (initialState != null)
          curatorRunControllerProvider.overrideWith(
            (ref) => CuratorRunController(
              materialPool: const [],
              initialState: initialState,
            ),
          ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CuratorBriefingModal(
            onOpenGearShop: onOpenGearShop,
          ),
        ),
      ),
    );
  }

  group('CuratorBriefingModal UI 測試 (Task M5, AC-M4-4.1, AC-M4-1.2)', () {
    testWidgets('360dp 螢幕下完整渲染且零 RenderFlex overflowed', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.textContaining('阿導行前委託'), findsOneWidget);
      expect(find.byKey(const Key('briefing_depart_button')), findsOneWidget);
      expect(find.byKey(const Key('briefing_reroll_button')), findsOneWidget);
      expect(find.byKey(const Key('briefing_gear_shop_button')), findsOneWidget);

      // 驗證無 RenderFlex 溢出異常
      expect(tester.takeException(), isNull);
    });

    testWidgets('未選哲學時出發按鈕為 Disabled，點擊哲學卡後出發按鈕解鎖', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial(),
        client: ClientSpec.budgetWorker,
      );

      await tester.pumpWidget(createSubject(initialState: state));
      await tester.pumpAndSettle();

      final departButtonFinder = find.byKey(const Key('briefing_depart_button'));
      final buttonBefore = tester.widget<ElevatedButton>(departButtonFinder);
      expect(buttonBefore.onPressed, isNull); // 禁用

      // 點擊第一張哲學卡
      final firstChoice = state.philosophyChoices.first;
      final firstCardFinder = find.byKey(Key('philosophy_card_${firstChoice.name}'));
      expect(firstCardFinder, findsOneWidget);
      await tester.tap(firstCardFinder);
      await tester.pumpAndSettle();

      final buttonAfter = tester.widget<ElevatedButton>(departButtonFinder);
      expect(buttonAfter.onPressed, isNotNull); // 已解鎖
    });

    testWidgets('在底抽屜中點擊出發按鈕調用 departToFieldTrip 並關閉彈窗', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial(),
        client: ClientSpec.budgetWorker,
      );

      final choice = state.philosophyChoices.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            persistenceRepositoryProvider
                .overrideWithValue(FakePersistenceRepository()),
            curatorRunControllerProvider.overrideWith(
              (ref) => CuratorRunController(
                materialPool: const [],
                initialState: state.selectPhilosophy(choice),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => const CuratorBriefingModal(),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 打開底抽屜
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(CuratorBriefingModal), findsOneWidget);

      final departButtonFinder = find.byKey(const Key('briefing_depart_button'));
      await tester.tap(departButtonFinder);
      await tester.pumpAndSettle();

      // 驗證彈窗已關閉
      expect(find.byType(CuratorBriefingModal), findsNothing);
    });

    testWidgets('點擊裝備舖按鈕觸發 onOpenGearShop 回調', (tester) async {
      var gearShopOpened = false;
      await tester.pumpWidget(
        createSubject(
          onOpenGearShop: () => gearShopOpened = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('briefing_gear_shop_button')));
      await tester.pumpAndSettle();

      expect(gearShopOpened, isTrue);
    });

    testWidgets('委託客戶標題顯示客戶 personaName 與 displayName 具名格式', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final stateWorker = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial(),
        client: ClientSpec.budgetWorker,
      );

      await tester.pumpWidget(createSubject(initialState: stateWorker));
      await tester.pumpAndSettle();

      expect(find.text('委託客戶：小林（極限窮遊社畜）'), findsOneWidget);

      final stateInfluencer = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial(),
        client: ClientSpec.hypeInfluencer,
      );

      await tester.pumpWidget(createSubject(initialState: stateInfluencer));
      await tester.pumpAndSettle();

      expect(find.text('委託客戶：安娜（IG 網紅）'), findsOneWidget);
    });

    testWidgets('難度選擇：預設觀光客，點擊攝影師寫入 selectDifficulty（REQ-M5-05.2）', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final key = UniqueKey();
      await tester.pumpWidget(createSubject(key: key));
      await tester.pumpAndSettle();

      for (final difficulty in ShutterDifficulty.values) {
        expect(find.byKey(Key('difficulty_pill_${difficulty.name}')), findsOneWidget);
      }

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('briefing_depart_button'))),
      );
      expect(
        container.read(curatorRunControllerProvider).shutterDifficulty,
        ShutterDifficulty.tourist,
        reason: '未選擇時預設觀光客',
      );

      await tester.ensureVisible(find.byKey(const Key('difficulty_pill_photographer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('difficulty_pill_photographer')));
      await tester.pumpAndSettle();

      expect(
        container.read(curatorRunControllerProvider).shutterDifficulty,
        ShutterDifficulty.photographer,
      );
    });
  });
}
