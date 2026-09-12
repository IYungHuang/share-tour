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
    testWidgets('AC-A1-3.8: submit 按鈕依槽數與連續性動態控制啟用狀態，並以可區分文案顯示禁用原因', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var state = CuratorRunState.initial();

      // 1. 空狀態 (< 3 槽): 禁用，顯示「至少安排 3 個時段」
      await tester.pumpWidget(createSubject(initialState: state));
      var submitBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('submit_itinerary_button')),
      );
      expect(submitBtn.onPressed, isNull);
      expect(find.textContaining('至少安排 3 個時段'), findsOneWidget);

      // 2. 放入 2 槽 ([0, 1]): 仍 < 3 槽，禁用，顯示「至少安排 3 個時段」
      state = state
          .setTimelineSlot(0, sampleMaterials[0])
          .setTimelineSlot(1, sampleMaterials[1]);
      await tester.pumpWidget(createSubject(initialState: state));
      submitBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('submit_itinerary_button')),
      );
      expect(submitBtn.onPressed, isNull);
      expect(find.textContaining('至少安排 3 個時段'), findsOneWidget);

      // 3. 3 槽中間缺口 ([0, 1, 3]): 禁用，顯示「素材需連續排列」
      state = state.setTimelineSlot(3, sampleMaterials[3]);
      await tester.pumpWidget(createSubject(initialState: state));
      submitBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('submit_itinerary_button')),
      );
      expect(submitBtn.onPressed, isNull);
      expect(find.textContaining('素材需連續排列'), findsOneWidget);

      // 4. 3 槽連續 ([0, 1, 2]): 啟用，顯示「呈送客戶審查」
      state = state
          .setTimelineSlot(3, null)
          .setTimelineSlot(2, sampleMaterials[2]);
      await tester.pumpWidget(createSubject(initialState: state));
      submitBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('submit_itinerary_button')),
      );
      expect(submitBtn.onPressed, isNotNull);
      expect(find.textContaining('呈送客戶審查'), findsOneWidget);

      // 5. 3 槽連續 ([1, 2, 3]): 啟用，顯示「呈送客戶審查」
      state = state
          .setTimelineSlot(0, null)
          .setTimelineSlot(3, sampleMaterials[3]);
      await tester.pumpWidget(createSubject(initialState: state));
      submitBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('submit_itinerary_button')),
      );
      expect(submitBtn.onPressed, isNotNull);
      expect(find.textContaining('呈送客戶審查'), findsOneWidget);

      // 6. 填滿 4 槽: 啟用，顯示「呈送客戶審查」
      state = state.setTimelineSlot(0, sampleMaterials[0]);
      await tester.pumpWidget(createSubject(initialState: state));
      submitBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('submit_itinerary_button')),
      );
      expect(submitBtn.onPressed, isNotNull);
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

    testWidgets('AC-CF-3.2: 數值看板與腰包清退計分文字、絕景 4-pip 與反無聊階梯張力警示', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. 建立具有不同 Hype 與 Spotlight 的測試素材
      const lowHypeMat = TravelMaterial(
        id: 'low_hype',
        name: '平淡景點',
        tags: ['#日常'],
        themeValue: 30,
        hypeValue: 20,
        cost: 100,
        riskLevel: 1,
      );
      const midHypeMat = TravelMaterial(
        id: 'mid_hype',
        name: '稍有特色景點',
        tags: ['#探索'],
        themeValue: 30,
        hypeValue: 60,
        cost: 100,
        riskLevel: 1,
      );
      const spotlightMat = TravelMaterial(
        id: 'spotlight_mat',
        name: '絕景打卡地',
        tags: ['#打卡', '#絕景'],
        themeValue: 30,
        hypeValue: 80,
        isSpotlight: true,
        cost: 200,
        riskLevel: 2,
      );

      final materials = [lowHypeMat, midHypeMat, spotlightMat];

      // 測試 A: 社畜初始狀態（總 Hype = 0 < 120），驗證：
      // - 不含 finalTheme / totalHype 數字
      // - 槽位與腰包不含 🎯 數字
      // - 絕景顯示 4 格 pip (0 spotlight: ○ ○ ○ ☆) 與 📉 絕景缺口，無乘數數字
      // - 社畜反無聊顯示 🚨 極度乏味
      var state = CuratorRunState.create(
        client: ClientSpec.budgetWorker,
        philosophy: TravelPhilosophy.slow,
        equipment: EquipmentInventory.initial(),
      ).addMaterial(lowHypeMat).addMaterial(spotlightMat);

      Widget createCustomSubject(CuratorRunState runState) {
        return ProviderScope(
          key: UniqueKey(),
          overrides: [
            curatorMaterialPoolProvider.overrideWithValue(materials),
            curatorRunControllerProvider.overrideWith(
              (ref) => CuratorRunController(
                materialPool: materials,
                initialState: runState,
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

      await tester.pumpWidget(createCustomSubject(state));

      // 斷言計分數字不存在
      expect(find.textContaining('🎯'), findsNothing);
      expect(find.textContaining('有效爆點'), findsNothing);
      expect(find.textContaining('主題適配'), findsNothing);
      expect(find.textContaining('+20% Combo'), findsNothing);

      // 斷言乘數不存在
      expect(find.textContaining('x0.'), findsNothing);
      expect(find.textContaining('x1.'), findsNothing);

      // 斷言客戶稱呼
      expect(find.textContaining('小林（極限窮遊社畜）'), findsOneWidget);

      // 斷言 0 絕景 pip 與 🚨 極度乏味
      expect(find.text('📉 絕景缺口'), findsOneWidget);
      expect(find.text('🚨 極度乏味'), findsOneWidget);

      // 測試 B: 總 Hype 提升至 120 <= Hype < 168 (例如排入 low + low + mid = 20 + 20 + 90 = 130)
      state = state
          .setTimelineSlot(0, lowHypeMat)
          .setTimelineSlot(1, lowHypeMat)
          .setTimelineSlot(2, midHypeMat);
      await tester.pumpWidget(createCustomSubject(state));

      expect(find.text('⚠️ 稍嫌平淡'), findsOneWidget);
      expect(find.text('🚨 極度乏味'), findsNothing);

      // 測試 C: 總 Hype 提升至 >= 168 (排入 low + mid + spotlight = 20 + 60 + 80 = 160，再加一個 = 220)
      state = state.setTimelineSlot(3, midHypeMat);
      await tester.pumpWidget(createCustomSubject(state));

      // totalHype >= 168 時警示即時消褪
      expect(find.text('⚠️ 稍嫌平淡'), findsNothing);
      expect(find.text('🚨 極度乏味'), findsNothing);

      // 測試 D: 4 格全滿絕景大滿貫 (4 個 spotlight)
      state = state
          .setTimelineSlot(0, spotlightMat)
          .setTimelineSlot(1, spotlightMat)
          .setTimelineSlot(2, spotlightMat)
          .setTimelineSlot(3, spotlightMat);
      await tester.pumpWidget(createCustomSubject(state));

      expect(find.text('🌟 絕景大滿貫'), findsOneWidget);
      expect(find.text('📉 絕景缺口'), findsNothing);
    });
  });
}

