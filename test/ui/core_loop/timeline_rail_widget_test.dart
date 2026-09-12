import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/ui/core_loop/components/timeline_rail.dart';

void main() {
  const walkMaterial = TravelMaterial(
    id: 'm_walk',
    name: '哲學之道晨曦漫遊',
    tags: ['#散步', '#老街'],
    themeValue: 25,
    hypeValue: 20,
    riskLevel: 1,
  );

  const foodMaterial = TravelMaterial(
    id: 'm_food',
    name: '錦市場午後排隊生魚片',
    tags: ['#美食', '#老街'],
    themeValue: 30,
    hypeValue: 35,
    riskLevel: 3,
  );

  const duskMaterial = TravelMaterial(
    id: 'm_dusk',
    name: '伏見稻荷千本鳥居黑夜陰影',
    tags: ['#怪談', '#高風險', '#絕景'],
    themeValue: 40,
    hypeValue: 70,
    isSpotlight: true,
    riskLevel: 4,
  );

  Widget createSubject(CuratorRunState state, {Key? key}) {
    return ProviderScope(
      key: key ?? UniqueKey(),
      overrides: [
        curatorMaterialPoolProvider.overrideWithValue([
          walkMaterial,
          foodMaterial,
          duskMaterial,
        ]),
        curatorRunControllerProvider.overrideWith(
          (ref) => CuratorRunController(
            materialPool: [walkMaterial, foodMaterial, duskMaterial],
            initialState: state,
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: TimelineRail())),
      ),
    );
  }

  group('4 槽位時間線軌道與連動光軌 Widget 測試 (AC-UI-2)', () {
    testWidgets(
      'AC-UI-2.1: 編輯器依序呈現 Slot 0(清晨)、Slot 1(午後)、Slot 2(黃昏)、Slot 3(深夜) 四個槽位',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final state = CuratorRunState.initial();
        await tester.pumpWidget(createSubject(state));

        expect(find.byKey(const Key('slot_card_0')), findsOneWidget);
        expect(find.byKey(const Key('slot_card_1')), findsOneWidget);
        expect(find.byKey(const Key('slot_card_2')), findsOneWidget);
        expect(find.byKey(const Key('slot_card_3')), findsOneWidget);

        expect(find.textContaining('06:00'), findsOneWidget);
        expect(find.textContaining('11:00'), findsOneWidget);
        expect(find.textContaining('16:00'), findsOneWidget);
        expect(find.textContaining('19:00'), findsOneWidget);
      },
    );

    testWidgets('AC-UI-2.2: 相鄰兩槽位命中同標籤時，渲染連鎖光軌與 [共鳴] 符號', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Slot 0 與 Slot 1 皆有 #老街 標籤
      var state = CuratorRunState.initial();
      state = state.setTimelineSlot(0, walkMaterial);
      state = state.setTimelineSlot(1, foodMaterial);

      await tester.pumpWidget(createSubject(state));

      expect(find.byKey(const Key('combo_indicator_0_1')), findsOneWidget);
      expect(find.text('0-1 [共鳴]'), findsOneWidget);
      expect(find.textContaining('+20% Combo'), findsNothing);
    });

    testWidgets('AC-UI-2.3: 相鄰兩槽位皆為高風險(riskLevel >= 3)時，渲染拉車疲勞警示', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Slot 1 (risk 3) 與 Slot 2 (risk 4)
      var state = CuratorRunState.initial();
      state = state.setTimelineSlot(1, foodMaterial);
      state = state.setTimelineSlot(2, duskMaterial);

      await tester.pumpWidget(createSubject(state));

      expect(find.byKey(const Key('fatigue_warning_1_2')), findsOneWidget);
      expect(find.textContaining('💀 拉車疲勞'), findsOneWidget);
    });

    testWidgets('AC-CF-3.4: 相鄰槽位一高一低風險時，光軌渲染 🎵 節奏互補 (同軌同階)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Slot 0 (risk 1) 與 Slot 1 (risk 3)
      var state = CuratorRunState.initial();
      state = state.setTimelineSlot(0, walkMaterial);
      state = state.setTimelineSlot(1, foodMaterial);

      await tester.pumpWidget(createSubject(state));

      expect(
        find.byKey(const Key('rail_indicator_rhythm_complement_0_1')),
        findsOneWidget,
      );
      expect(find.textContaining('🎵 節奏互補'), findsOneWidget);
    });

    testWidgets('AC-CF-4.2: focusedCulpritSlot 在對應槽位渲染 highlight_culprit_slot 光暈', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var state = CuratorRunState.initial();
      state = state.setTimelineSlot(1, foodMaterial);
      state = state.copyWith(focusedCulpritSlot: 1);

      await tester.pumpWidget(createSubject(state));

      expect(find.byKey(const Key('highlight_culprit_slot')), findsOneWidget);
    });

    testWidgets('AC-UI-2.4: Slot 2 黃昏槽位動態顯示當前相機等級之熱度倍率 (預設 Lv.1 為 1.5x)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 預設 Lv.1 相機
      var state = CuratorRunState.initial();
      await tester.pumpWidget(createSubject(state));
      expect(find.textContaining('📷 1.5x'), findsOneWidget);

      // 升級至 Lv.2 相機 (先充值 1000 金幣)
      final upgradedEquip = state.equipment
          .addCoins(1000)
          .upgrade(EquipmentType.camera);
      state = state.copyWith(
        equipment: upgradedEquip,
        equipmentSnapshot: upgradedEquip,
      );
      await tester.pumpWidget(createSubject(state));
      expect(find.textContaining('📷 1.8x'), findsOneWidget);
    });

    testWidgets('AC-A1-3.8: 四個槽位容器常駐，合法 3 槽端點顯示「刻意留白」，未達 3 槽顯示預設提示', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var state = CuratorRunState.initial();

      // 1. 全空時：4 個槽位卡片皆存在，無「刻意留白」
      await tester.pumpWidget(createSubject(state));
      expect(find.byKey(const Key('slot_card_0')), findsOneWidget);
      expect(find.byKey(const Key('slot_card_1')), findsOneWidget);
      expect(find.byKey(const Key('slot_card_2')), findsOneWidget);
      expect(find.byKey(const Key('slot_card_3')), findsOneWidget);
      expect(find.text('刻意留白'), findsNothing);

      // 2. 僅放 2 槽 ([0, 1])：仍無「刻意留白」
      state = state
          .setTimelineSlot(0, walkMaterial)
          .setTimelineSlot(1, foodMaterial);
      await tester.pumpWidget(createSubject(state));
      expect(find.text('刻意留白'), findsNothing);

      // 3. 3 槽連續 [0, 1, 2]：Slot 3 端點顯示「刻意留白」
      state = state.setTimelineSlot(2, duskMaterial);
      await tester.pumpWidget(createSubject(state));
      expect(find.text('刻意留白'), findsOneWidget);

      // 4. 3 槽連續 [1, 2, 3]：Slot 0 端點顯示「刻意留白」
      state = state
          .setTimelineSlot(0, null)
          .setTimelineSlot(3, walkMaterial);
      await tester.pumpWidget(createSubject(state));
      expect(find.text('刻意留白'), findsOneWidget);

      // 5. 3 槽中間留空 [0, 1, 3]：不可提交，無「刻意留白」
      state = state
          .setTimelineSlot(0, walkMaterial)
          .setTimelineSlot(2, null);
      await tester.pumpWidget(createSubject(state));
      expect(find.text('刻意留白'), findsNothing);
    });

    testWidgets(
      'RED camera snapshot: 出發後局外裝備改變不影響本局黃昏顯示／評分；下一局才使用新倍率',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. 本局初始為 Lv.1 相機出發
        var state = CuratorRunState.create(
          client: ClientSpec.budgetWorker,
          philosophy: TravelPhilosophy.slow,
          equipment: EquipmentInventory.initial(),
        );
        expect(state.equipmentSnapshot.camera.cameraMultiplier, 1.5);

        // 2. 模擬局外裝備升級為 Lv.2 相機 (例如在商店升級)
        final upgradedEquip = state.equipment
            .addCoins(1000)
            .upgrade(EquipmentType.camera);
        state = state.copyWith(equipment: upgradedEquip);

        // 裝備已升至 Lv.2，但快照仍為 Lv.1
        expect(state.equipment.camera.level, 2);
        expect(state.equipmentSnapshot.camera.level, 1);

        // 3. 黃昏槽位卡片顯示必須嚴格依據快照 (仍顯示 1.5x，不得顯示 1.8x)
        await tester.pumpWidget(createSubject(state));
        expect(find.textContaining('📷 1.5x'), findsOneWidget);
        expect(find.textContaining('📷 1.8x'), findsNothing);

        // 4. 重啟新單局 (restartRun) 後，下一局才鎖定新倍率 1.8x
        final nextRunState = state.restartRun(targetPhilosophy: TravelPhilosophy.slow);
        expect(nextRunState.equipmentSnapshot.camera.level, 2);
        expect(nextRunState.equipmentSnapshot.camera.cameraMultiplier, 1.8);

        await tester.pumpWidget(createSubject(nextRunState));
        expect(find.textContaining('📷 1.8x'), findsOneWidget);
      },
    );
  });
}
