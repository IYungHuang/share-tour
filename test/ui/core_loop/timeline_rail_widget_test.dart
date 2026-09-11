import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
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

    testWidgets('AC-UI-2.2: 相鄰兩槽位命中同標籤時，渲染連鎖光軌與 +20% Combo 文本', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Slot 0 與 Slot 1 皆有 #老街 標籤
      var state = CuratorRunState.initial();
      state = state.setTimelineSlot(0, walkMaterial);
      state = state.setTimelineSlot(1, foodMaterial);

      await tester.pumpWidget(createSubject(state));

      expect(find.byKey(const Key('combo_indicator_0_1')), findsOneWidget);
      expect(find.textContaining('+20% Combo'), findsOneWidget);
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
      state = state.copyWith(equipment: upgradedEquip);
      await tester.pumpWidget(createSubject(state));
      expect(find.textContaining('📷 1.8x'), findsOneWidget);
    });
  });
}
