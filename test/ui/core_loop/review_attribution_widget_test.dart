import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/ui/core_loop/curator_studio_modal.dart';
import 'package:share_tour/ui/core_loop/review_settlement_modal.dart';

void main() {
  const highRisk1 = TravelMaterial(
    id: 'hr1',
    name: '高危景點 1',
    tags: ['#深夜'],
    themeValue: 30,
    hypeValue: 20,
    cost: 500,
    riskLevel: 3,
  );

  const highRisk2 = TravelMaterial(
    id: 'hr2',
    name: '高危景點 2',
    tags: ['#深夜'],
    themeValue: 30,
    hypeValue: 20,
    cost: 500,
    riskLevel: 3,
  );

  const normalCard = TravelMaterial(
    id: 'norm',
    name: '一般景點',
    tags: ['#深夜'],
    themeValue: 25,
    hypeValue: 20,
    cost: 400,
    riskLevel: 1,
  );

  const expensiveCard = TravelMaterial(
    id: 'exp',
    name: '昂貴景點',
    tags: ['#深夜'],
    themeValue: 30,
    hypeValue: 20,
    cost: 1200,
    riskLevel: 1,
  );

  const spotlightCard = TravelMaterial(
    id: 'spot',
    name: '絕景打卡',
    tags: ['#絕景', '#拍照'],
    themeValue: 30,
    hypeValue: 40,
    cost: 500,
    isSpotlight: true,
  );

  const repelledCard = TravelMaterial(
    id: 'repel',
    name: '排斥景點',
    tags: ['#拉車'], // midnight philosophy repels #拉車
    themeValue: 20,
    hypeValue: 20,
    cost: 400,
  );

  Widget createSubject({
    required CuratorRunState state,
    ReviewReport? initialReport,
    VoidCallback? onClose,
  }) {
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        curatorRunControllerProvider.overrideWith(
          (ref) => CuratorRunController(
            materialPool: [
              highRisk1,
              highRisk2,
              normalCard,
              expensiveCard,
              spotlightCard,
              repelledCard,
            ],
            initialState: state,
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ReviewSettlementModal(
            initialReport: initialReport,
            onClose: onClose,
          ),
        ),
      ),
    );
  }

  group('結算面板局域歸因與分母同步測試 (AC-CF-4)', () {
    testWidgets(
      'AC-CF-4.1: 發生疲勞、超支、絕景不足與哲學排斥時，歸因區塊標明具體時段對、元兇槽位與缺口張數',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. 社畜超支與疲勞
        var state = CuratorRunState.create(
          client: ClientSpec.budgetWorker, // 預算 2000
          philosophy: TravelPhilosophy.midnight,
          equipment: EquipmentInventory.initial(),
        );
        // Slot 0, 1 連續高危 (疲勞對 0-1)
        state = state.setTimelineSlot(0, highRisk1);
        state = state.setTimelineSlot(1, highRisk2);
        // Slot 2 哲學排斥 (midnight 排斥 #晨間)
        state = state.setTimelineSlot(2, repelledCard);
        // Slot 3 超貴卡 (500 + 500 + 400 + 1200 = 2600 > 2000，超支 600，元兇為 Slot 3)
        state = state.setTimelineSlot(3, expensiveCard);
        state = state.copyWith(phase: CuratorRunPhase.clientReview);

        await tester.pumpWidget(createSubject(state: state));
        await tester.pumpAndSettle();

        // 斷言歸因區塊呈現
        final attributionFinder = find.byKey(const Key('settlement_attribution_section'));
        expect(attributionFinder, findsOneWidget);
        expect(find.descendant(of: attributionFinder, matching: find.text('超支元兇')), findsOneWidget);
        expect(find.descendant(of: attributionFinder, matching: find.text('Slot 3 (¥1200)')), findsOneWidget);
        expect(find.descendant(of: attributionFinder, matching: find.text('拉車疲勞')), findsOneWidget);
        expect(find.descendant(of: attributionFinder, matching: find.text('時段 0-1 疲勞')), findsOneWidget);
        expect(find.descendant(of: attributionFinder, matching: find.text('哲學排斥')), findsOneWidget);
        expect(find.descendant(of: attributionFinder, matching: find.text('Slot 2')), findsOneWidget);
      },
    );

    testWidgets(
      'AC-CF-4.1 (網紅絕景): 網紅局絕景不足時，歸因區塊標明缺口張數',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        var state = CuratorRunState.create(
          client: ClientSpec.hypeInfluencer,
          philosophy: TravelPhilosophy.chaos,
          equipment: EquipmentInventory.initial(),
        );
        // 1 張絕景，3 張非絕景 -> 缺口 3 張
        state = state.setTimelineSlot(0, spotlightCard);
        state = state.setTimelineSlot(1, normalCard);
        state = state.setTimelineSlot(2, normalCard);
        state = state.setTimelineSlot(3, normalCard);
        state = state.copyWith(phase: CuratorRunPhase.clientReview);

        await tester.pumpWidget(createSubject(state: state));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('settlement_attribution_section')), findsOneWidget);
        expect(find.textContaining('絕景缺口'), findsOneWidget);
        expect(find.textContaining('還差 3 張焦點絕景'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-CF-4.2: 點擊「返回微調」後，工作台對應槽位呈現 Key(highlight_culprit_slot) 光暈；操作後光暈消失',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        var state = CuratorRunState.create(
          client: ClientSpec.budgetWorker,
          philosophy: TravelPhilosophy.midnight,
          equipment: EquipmentInventory.initial(),
        );
        state = state.setTimelineSlot(0, normalCard);
        state = state.setTimelineSlot(1, normalCard);
        state = state.setTimelineSlot(2, normalCard);
        state = state.setTimelineSlot(3, expensiveCard); // 總價 2400 > 2000，元兇 Slot 3
        state = state.copyWith(phase: CuratorRunPhase.clientReview);

        final controller = CuratorRunController(
          materialPool: [normalCard, expensiveCard],
          initialState: state,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              curatorRunControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: ReviewSettlementModal(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 點擊返回微調
        expect(find.byKey(const Key('btn_tweak_itinerary')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_tweak_itinerary')));
        await tester.pumpAndSettle();

        // 驗證 controller 的 state 已成功記錄 focusedCulpritSlot == 3
        expect(controller.state.focusedCulpritSlot, equals(3));
        expect(controller.state.phase, equals(CuratorRunPhase.nightEditing));

        // 將此 state pump 至工作台 (CuratorStudioModal)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              curatorRunControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CuratorStudioModal(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 斷言 Slot 3 呈現高亮光暈
        expect(find.byKey(const Key('highlight_culprit_slot')), findsOneWidget);

        // 玩家對 Slot 3 執行替換/清除操作
        controller.removeMaterialFromSlot(3);
        await tester.pumpAndSettle();

        // 斷言光暈消失
        expect(find.byKey(const Key('highlight_culprit_slot')), findsNothing);
      },
    );

    testWidgets(
      'AC-CF-4.3: 結算面板的分母與係數全部取自資料，且文字規格吻合',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. 社畜局：分母呈現 / 44 與 / 56，反無聊含 168
        const workerReport = ReviewReport(
          clientType: 'budgetWorker',
          outcome: ReviewOutcome.nearMiss,
          satisfaction: 60,
          earnedCoins: 20,
          feedbackQuote: '再加油！',
          subscores: {
            'budgetScore': 30,
            'themeScore': 20,
            'boredomPenalty': 25,
            'maxBudgetScore': 44,
            'themeWeight': 56,
            'boredomThreshold': 168,
          },
        );

        final stateWorker = CuratorRunState.initial().copyWith(
          client: ClientSpec.budgetWorker,
          phase: CuratorRunPhase.clientReview,
          latestReport: workerReport,
        );

        await tester.pumpWidget(
          createSubject(state: stateWorker, initialReport: workerReport),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('/ 44'), findsOneWidget);
        expect(find.textContaining('/ 56'), findsOneWidget);
        expect(find.textContaining('Hype<168'), findsOneWidget);

        // 2. 網紅局：持有 2 張絕景時，不得出現「無絕景」，不得出現「五折」
        const influencerReport2 = ReviewReport(
          clientType: 'hypeInfluencer',
          outcome: ReviewOutcome.nearMiss,
          satisfaction: 70,
          earnedCoins: 30,
          feedbackQuote: '缺絕景！',
          subscores: {
            'effectiveHype': 120,
            'spotlightMultiplier': 0.80,
            'spotlightCount': 2,
            'themeFactor': 1.0,
          },
        );

        final stateInfluencer = CuratorRunState.initial().copyWith(
          client: ClientSpec.hypeInfluencer,
          phase: CuratorRunPhase.clientReview,
          latestReport: influencerReport2,
        );

        await tester.pumpWidget(
          createSubject(state: stateInfluencer, initialReport: influencerReport2),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('無絕景'), findsNothing);
        expect(find.textContaining('五折'), findsNothing);
        expect(find.textContaining('絕景 2/4 張 (缺口 2 張，階梯 80%)'), findsOneWidget);

        // 3. 網紅局：0 張絕景時，呈現「無絕景 (缺口 4 張，階梯 70%)」，不得出現「五折」
        const influencerReport0 = ReviewReport(
          clientType: 'hypeInfluencer',
          outcome: ReviewOutcome.nearMiss,
          satisfaction: 50,
          earnedCoins: 10,
          feedbackQuote: '完全沒有絕景！',
          subscores: {
            'effectiveHype': 80,
            'spotlightMultiplier': 0.70,
            'spotlightCount': 0,
            'themeFactor': 1.0,
          },
        );

        await tester.pumpWidget(
          createSubject(state: stateInfluencer, initialReport: influencerReport0),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('無絕景 (缺口 4 張，階梯 70%)'), findsOneWidget);
        expect(find.textContaining('五折'), findsNothing);
      },
    );

    testWidgets(
      'AC-CF-4.4: 切換至非指派客戶頁籤時，歸因區塊標示為試算；primaryCulpritSlot 恆依指派客戶計算',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 社畜指派客戶：預算 2000，填入 2400 (Slot 3 超支 1200)
        var state = CuratorRunState.create(
          client: ClientSpec.budgetWorker,
          philosophy: TravelPhilosophy.midnight,
          equipment: EquipmentInventory.initial(),
        );
        state = state.setTimelineSlot(0, normalCard);
        state = state.setTimelineSlot(1, normalCard);
        state = state.setTimelineSlot(2, normalCard);
        state = state.setTimelineSlot(3, expensiveCard);
        state = state.copyWith(phase: CuratorRunPhase.clientReview);

        final controller = CuratorRunController(
          materialPool: [normalCard, expensiveCard],
          initialState: state,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              curatorRunControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: ReviewSettlementModal(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 指派客戶頁籤：顯示歸因區塊
        expect(find.byKey(const Key('settlement_attribution_section')), findsOneWidget);
        expect(
          find.byKey(const Key('settlement_attribution_simulation_notice')),
          findsNothing,
        );

        // 切換至網紅頁籤 (非指派)
        await tester.tap(find.byKey(const Key('client_tab_hypeInfluencer')));
        await tester.pumpAndSettle();

        // 歸因區塊隱藏，呈現試算提示
        expect(find.byKey(const Key('settlement_attribution_section')), findsNothing);
        expect(
          find.byKey(const Key('settlement_attribution_simulation_notice')),
          findsOneWidget,
        );
        expect(find.textContaining('此為另一位客戶的試算，不含歸因'), findsOneWidget);

        // 在非指派頁籤下點擊「返回微調」
        expect(find.byKey(const Key('btn_tweak_itinerary')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_tweak_itinerary')));
        await tester.pumpAndSettle();

        // primaryCulpritSlot 仍恆為社畜指派客戶的 Slot 3
        expect(controller.state.focusedCulpritSlot, equals(3));
      },
    );
  });
}
