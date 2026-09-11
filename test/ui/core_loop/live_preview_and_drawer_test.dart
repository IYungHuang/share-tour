import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/ui/core_loop/components/live_preview_hud.dart';
import 'package:share_tour/ui/core_loop/components/waist_bag_drawer.dart';

void main() {
  final sampleMaterials = List.generate(
    4,
    (i) => TravelMaterial(
      id: 'mat_$i',
      name: '特色景點 $i',
      tags: ['#景點'],
      themeValue: 20 + i * 5,
      hypeValue: 20 + i * 10,
      cost: 300 * i,
      riskLevel: 1,
    ),
  );

  Widget createSubject({CuratorRunState? initialState, Key? key}) {
    return ProviderScope(
      key: key ?? UniqueKey(),
      overrides: [
        curatorMaterialPoolProvider.overrideWithValue(sampleMaterials),
        if (initialState != null)
          curatorRunControllerProvider.overrideWith(
            (ref) => CuratorRunController(
              materialPool: sampleMaterials,
              initialState: initialState,
            ),
          ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LivePreviewHUD(),
              Expanded(child: WaistBagDrawer()),
            ],
          ),
        ),
      ),
    );
  }

  group('即時數值看板與腰包抽屜 Widget 測試 (AC-UI-2.5 & U3)', () {
    testWidgets('AC-UI-2.5: 4 槽位未填滿時 submit 按鈕禁用；填滿時轉為啟用', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var state = CuratorRunState.initial();
      await tester.pumpWidget(createSubject(initialState: state));

      // 未填滿時禁用
      final disabledBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('submit_itinerary_button')),
      );
      expect(disabledBtn.onPressed, isNull);
      expect(find.textContaining('請填滿 4 個時段'), findsOneWidget);

      // 填滿 4 槽位
      for (var i = 0; i < 4; i++) {
        state = state.setTimelineSlot(i, sampleMaterials[i]);
      }
      await tester.pumpWidget(createSubject(initialState: state));

      final enabledBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('submit_itinerary_button')),
      );
      expect(enabledBtn.onPressed, isNotNull);
      expect(find.textContaining('呈送客戶審查'), findsOneWidget);
    });

    testWidgets('WaistBagDrawer: 顯示腰包卡片，已排入槽位之卡片顯示「已排入 Slot X」遮罩', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var state = CuratorRunState.initial();
      // 加入兩張素材至腰包
      state = state
          .addMaterial(sampleMaterials[0])
          .addMaterial(sampleMaterials[1]);
      // 將第一張排入 Slot 0
      state = state.setTimelineSlot(0, sampleMaterials[0]);

      await tester.pumpWidget(createSubject(initialState: state));

      expect(
        find.byKey(Key('bag_card_${sampleMaterials[0].id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('bag_card_${sampleMaterials[1].id}')),
        findsOneWidget,
      );

      // sampleMaterials[0] 顯示已排入 Slot 0
      expect(
        find.byKey(Key('in_use_overlay_${sampleMaterials[0].id}')),
        findsOneWidget,
      );
      expect(find.textContaining('已排入 Slot 0'), findsOneWidget);

      // sampleMaterials[1] 未排入
      expect(
        find.byKey(Key('in_use_overlay_${sampleMaterials[1].id}')),
        findsNothing,
      );
    });

    testWidgets('WaistBagDrawer: 點擊 [測試] 🎲 採集素材 按鈕，腰包新增卡片', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject());

      expect(
        find.byKey(const Key('draw_sample_material_button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('draw_sample_material_button')));
      await tester.pump();

      // 腰包中出現至少一張卡片
      expect(
        find
                .byKey(Key('bag_card_${sampleMaterials[0].id}'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(Key('bag_card_${sampleMaterials[1].id}'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(Key('bag_card_${sampleMaterials[2].id}'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(Key('bag_card_${sampleMaterials[3].id}'))
                .evaluate()
                .isNotEmpty,
        isTrue,
      );
    });
  });
}
