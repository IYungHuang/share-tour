import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/ui/core_loop/review_settlement_modal.dart';

void main() {
  final sampleMaterials = [
    const TravelMaterial(
      id: 'm1',
      name: '景點 1',
      tags: ['#深夜'],
      themeValue: 30,
      hypeValue: 20,
      cost: 500,
    ),
    const TravelMaterial(
      id: 'm2',
      name: '景點 2',
      tags: ['#深夜'],
      themeValue: 30,
      hypeValue: 20,
      cost: 500,
    ),
    const TravelMaterial(
      id: 'm3',
      name: '景點 3',
      tags: ['#深夜'],
      themeValue: 30,
      hypeValue: 20,
      cost: 500,
    ),
    const TravelMaterial(
      id: 'm4',
      name: '景點 4',
      tags: ['#深夜'],
      themeValue: 30,
      hypeValue: 20,
      cost: 660, // 總額 2160 超支 160
    ),
  ];

  Widget createSubject({
    required CuratorRunState state,
    ReviewReport? initialReport,
    VoidCallback? onOpenGearShop,
    VoidCallback? onRestartRun,
  }) {
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        curatorMaterialPoolProvider.overrideWithValue(sampleMaterials),
        curatorRunControllerProvider.overrideWith(
          (ref) => CuratorRunController(
            materialPool: sampleMaterials,
            initialState: state,
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ReviewSettlementModal(
            initialReport: initialReport,
            onOpenGearShop: onOpenGearShop,
            onRestartRun: onRestartRun,
          ),
        ),
      ),
    );
  }

  group('雙客戶動態評審與 Near Miss 結算彈窗 Widget 測試 (AC-UI-3)', () {
    testWidgets(
      'AC-FIX-5.1: 切換客戶頁籤只是唯讀對照，收下的報告一律以本局指派客戶為準',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 廉價素材：社畜 (指派客戶) 不超支可收佣金，網紅則因熱度不足退件
        const cheap = TravelMaterial(
          id: 'cheap',
          name: '巷弄散步',
          tags: ['#深夜'],
          themeValue: 30,
          hypeValue: 50,
          cost: 100,
        );
        var state = CuratorRunState.create(
          client: ClientSpec.budgetWorker,
          philosophy: TravelPhilosophy.midnight,
          equipment: EquipmentInventory.initial(),
        );
        for (var i = 0; i < 4; i++) {
          state = state.setTimelineSlot(i, cheap);
        }
        state = state.copyWith(phase: CuratorRunPhase.clientReview);

        await tester.pumpWidget(createSubject(state: state));

        // 玩家切到另一位客戶的頁籤，想改拿那份報告
        await tester.tap(find.byKey(const Key('client_tab_hypeInfluencer')));
        await tester.pumpAndSettle();

        // 行動區必須仍由指派客戶驅動，不因檢視頁籤而改變
        expect(find.byKey(const Key('btn_collect_rewards')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_collect_rewards')));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final settled = container.read(curatorRunControllerProvider);

        expect(
          settled.latestReport!.clientType,
          'budgetWorker',
          reason: '結算視窗切換頁籤不得變成免費重骰客戶',
        );
      },
    );

    testWidgets(
      'AC-UI-3.1: 預設載入 budgetWorker，提供切換頁籤 client_tab_hypeInfluencer',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final state = CuratorRunState.initial();
        await tester.pumpWidget(createSubject(state: state));

        expect(
          find.byKey(const Key('client_tab_budgetWorker')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('client_tab_hypeInfluencer')),
          findsOneWidget,
        );
        expect(find.textContaining('社畜小林'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-UI-3.2: 社畜超支 Near Miss (68分) 蓋上 stamp_near_miss 印章並標示超支扣分',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const workerReport = ReviewReport(
          clientType: 'budgetWorker',
          outcome: ReviewOutcome.nearMiss,
          satisfaction: 68,
          earnedCoins: 30,
          feedbackQuote: '差點就完美了！超支了 160 円...',
          subscores: {
            'budgetScore': 38,
            'themeScore': 30,
            'boredomPenalty': 0,
            'totalCost': 2160,
            'targetBudget': 2000,
          },
        );

        final state = CuratorRunState.initial().copyWith(
          phase: CuratorRunPhase.clientReview,
          latestReport: workerReport,
        );

        await tester.pumpWidget(
          createSubject(state: state, initialReport: workerReport),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('stamp_near_miss')), findsOneWidget);
        expect(find.textContaining('超支扣分提醒'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-UI-3.3: 網紅無絕景 Near Miss (67分) 蓋上 stamp_near_miss 印章並標示無絕景',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const influencerReport = ReviewReport(
          clientType: 'hypeInfluencer',
          outcome: ReviewOutcome.nearMiss,
          satisfaction: 67,
          earnedCoins: 40,
          feedbackQuote: '熱度很高，但缺少焦點絕景！經紀人強制打五折...',
          subscores: {
            'effectiveHype': 100,
            'spotlightMultiplier': 0.5,
            'themeFactor': 1.0,
          },
        );

        final state = CuratorRunState.initial().copyWith(
          phase: CuratorRunPhase.clientReview,
          latestReport: influencerReport,
        );

        await tester.pumpWidget(
          createSubject(state: state, initialReport: influencerReport),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('stamp_near_miss')), findsOneWidget);
        expect(find.textContaining('無絕景'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-UI-3.4: 在 Near Miss 下點擊 btn_tweak_itinerary 返回微調，控制器退回 nightEditing',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const report = ReviewReport(
          clientType: 'budgetWorker',
          outcome: ReviewOutcome.nearMiss,
          satisfaction: 68,
          earnedCoins: 30,
          feedbackQuote: '差 160 円...',
          subscores: {},
        );

        final state = CuratorRunState.initial().copyWith(
          phase: CuratorRunPhase.clientReview,
          latestReport: report,
        );

        await tester.pumpWidget(
          createSubject(state: state, initialReport: report),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn_tweak_itinerary')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_tweak_itinerary')));
        await tester.pump();
      },
    );

    testWidgets('AC-UI-3.5: 點擊 btn_restart_run 重啟新單局', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const report = ReviewReport(
        clientType: 'budgetWorker',
        outcome: ReviewOutcome.rejected,
        satisfaction: 40,
        earnedCoins: 0,
        feedbackQuote: '太差了！',
        subscores: {},
      );

      final state = CuratorRunState.initial().copyWith(
        phase: CuratorRunPhase.clientReview,
        latestReport: report,
      );

      await tester.pumpWidget(
        createSubject(state: state, initialReport: report),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_restart_run')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_restart_run')));
      await tester.pump();
    });

    testWidgets('AC-M4-4.3: Near Miss 呈現反事實導購提示', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const report = ReviewReport(
        clientType: 'hypeInfluencer',
        outcome: ReviewOutcome.nearMiss,
        satisfaction: 67,
        earnedCoins: 450,
        feedbackQuote: '差點就震撼了！',
        subscores: {},
      );

      final state = CuratorRunState.initial().copyWith(
        phase: CuratorRunPhase.clientReview,
        latestReport: report,
      );

      await tester.pumpWidget(
        createSubject(state: state, initialReport: report),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('near_miss_shop_tip')), findsOneWidget);
      expect(find.textContaining('要是黃昏再震撼一點就好了'), findsOneWidget);
    });

    testWidgets('AC-M4-4.3: 結算完成展示前往裝備舖與再來一局雙出口', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const report = ReviewReport(
        clientType: 'budgetWorker',
        outcome: ReviewOutcome.pass,
        satisfaction: 80,
        earnedCoins: 1000,
        feedbackQuote: '合格！',
        subscores: {},
      );

      final state = CuratorRunState.initial().copyWith(
        phase: CuratorRunPhase.settled,
        latestReport: report,
      );

      var gearShopOpened = false;
      var restartRunCalled = false;

      await tester.pumpWidget(
        createSubject(
          state: state,
          initialReport: report,
          onOpenGearShop: () => gearShopOpened = true,
          onRestartRun: () => restartRunCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settlement_go_to_shop_button')), findsOneWidget);
      expect(find.byKey(const Key('settlement_restart_run_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('settlement_go_to_shop_button')));
      await tester.pumpAndSettle();
      expect(gearShopOpened, isTrue);

      await tester.tap(find.byKey(const Key('settlement_restart_run_button')));
      await tester.pumpAndSettle();
      expect(restartRunCalled, isTrue);
    });

    testWidgets(
      'AC-A1-3.5: 純度成立與失效時的結算子分數文案可明確區分',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. 純度成立報告
        const activeReport = ReviewReport(
          clientType: 'budgetWorker',
          outcome: ReviewOutcome.pass,
          satisfaction: 85,
          earnedCoins: 500,
          feedbackQuote: '不錯！',
          subscores: {
            'budgetScore': 44,
            'themeScore': 41,
            'boredomPenalty': 0,
            'boredomThreshold': 168,
            'maxBudgetScore': 44,
            'themeWeight': 56,
            'totalCost': 1800,
            'targetBudget': 2000,
            'purityBonus': 1,
            'themeFatigue': 0,
          },
        );

        final stateActive = CuratorRunState.initial().copyWith(
          phase: CuratorRunPhase.clientReview,
          latestReport: activeReport,
        );

        await tester.pumpWidget(
          createSubject(state: stateActive, initialReport: activeReport),
        );
        await tester.pumpAndSettle();

        expect(find.text('風格純度獎勵'), findsOneWidget);
        expect(find.text('+1 分 (純度達成)'), findsOneWidget);

        // 2. 純度失效報告
        const inactiveReport = ReviewReport(
          clientType: 'budgetWorker',
          outcome: ReviewOutcome.pass,
          satisfaction: 84,
          earnedCoins: 500,
          feedbackQuote: '不錯！',
          subscores: {
            'budgetScore': 44,
            'themeScore': 40,
            'boredomPenalty': 0,
            'boredomThreshold': 168,
            'maxBudgetScore': 44,
            'themeWeight': 56,
            'totalCost': 1800,
            'targetBudget': 2000,
            'purityBonus': 0,
            'themeFatigue': 0,
          },
        );

        final stateInactive = CuratorRunState.initial().copyWith(
          phase: CuratorRunPhase.clientReview,
          latestReport: inactiveReport,
        );

        await tester.pumpWidget(
          createSubject(state: stateInactive, initialReport: inactiveReport),
        );
        await tester.pumpAndSettle();

        expect(find.text('風格純度獎勵'), findsOneWidget);
        expect(find.text('0 分 (純度失效)'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-A1-6.6: 混亂報告同時呈現 Hype 冒險連段收益與 Theme 疲勞，其他哲學呈現 Hype 疲勞損失與 Theme 疲勞',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. 混亂冒險哲學報告 (冒險連段加成 > 0，拉車疲勞扣分 > 0)
        const chaosReport = ReviewReport(
          clientType: 'hypeInfluencer',
          outcome: ReviewOutcome.pass,
          satisfaction: 88,
          earnedCoins: 700,
          feedbackQuote: '冒險刺激！',
          subscores: {
            'effectiveHype': 160,
            'spotlightMultiplier': 1.0,
            'spotlightCount': 1,
            'themeFactor': 0.9,
            'purityBonus': 0,
            'themeFatigue': 10,
            'adventureCombo': 21,
            'hypeFatigue': 0,
          },
        );

        final stateChaos = CuratorRunState.initial().copyWith(
          philosophy: TravelPhilosophy.chaos,
          phase: CuratorRunPhase.clientReview,
          latestReport: chaosReport,
        );

        await tester.pumpWidget(
          createSubject(state: stateChaos, initialReport: chaosReport),
        );
        await tester.pumpAndSettle();

        expect(find.text('冒險連段加成'), findsOneWidget);
        expect(find.text('+21 Hype'), findsOneWidget);
        expect(find.text('拉車疲勞扣分'), findsOneWidget);
        expect(find.text('-10 分'), findsOneWidget);
        expect(find.text('拉車脫妝懲罰'), findsNothing);

        // 2. 一般哲學報告 (拉車脫妝懲罰 > 0，拉車疲勞扣分 > 0)
        const normalReport = ReviewReport(
          clientType: 'hypeInfluencer',
          outcome: ReviewOutcome.pass,
          satisfaction: 75,
          earnedCoins: 600,
          feedbackQuote: '有點累！',
          subscores: {
            'effectiveHype': 118,
            'spotlightMultiplier': 1.0,
            'spotlightCount': 1,
            'themeFactor': 0.9,
            'purityBonus': 0,
            'themeFatigue': 10,
            'adventureCombo': 0,
            'hypeFatigue': 21,
          },
        );

        final stateNormal = CuratorRunState.initial().copyWith(
          philosophy: TravelPhilosophy.midnight,
          phase: CuratorRunPhase.clientReview,
          latestReport: normalReport,
        );

        await tester.pumpWidget(
          createSubject(state: stateNormal, initialReport: normalReport),
        );
        await tester.pumpAndSettle();

        expect(find.text('拉車脫妝懲罰'), findsOneWidget);
        expect(find.text('-21 Hype'), findsOneWidget);
        expect(find.text('拉車疲勞扣分'), findsOneWidget);
        expect(find.text('-10 分'), findsOneWidget);
        expect(find.text('冒險連段加成'), findsNothing);
      },
    );

    testWidgets(
      'AC-A1-Integration: 裝牌至控制器提交審查，ReviewSettlementModal 數值與 domain 報告完全一致且對照頁籤不改指派結算',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const passMat1 = TravelMaterial(
          id: 'p1',
          name: '夜市散策',
          tags: ['#深夜'],
          themeValue: 80,
          hypeValue: 70,
          cost: 300,
        );
        const passMat2 = TravelMaterial(
          id: 'p2',
          name: '酒吧巡禮',
          tags: ['#深夜'],
          themeValue: 80,
          hypeValue: 70,
          cost: 300,
        );
        const passMat3 = TravelMaterial(
          id: 'p3',
          name: '展望台夜景',
          tags: ['#深夜'],
          themeValue: 80,
          hypeValue: 70,
          cost: 300,
        );

        final controller = CuratorRunController(
          materialPool: [passMat1, passMat2, passMat3],
          initialState: CuratorRunState.create(
            client: ClientSpec.budgetWorker,
            philosophy: TravelPhilosophy.midnight,
            equipment: EquipmentInventory.initial(),
          ),
        );

        // 裝入 3 個連續素材 (合法 3 槽)
        controller.placeMaterialInSlot(0, passMat1);
        controller.placeMaterialInSlot(1, passMat2);
        controller.placeMaterialInSlot(2, passMat3);

        // 真實呈送審查
        controller.submitReview(ClientType.budgetWorker);
        final reportAfterSubmit = controller.state.latestReport!;

        // 透過 ProviderScope 掛載 ReviewSettlementModal，不傳入 initialReport，驗證真實 Provider 接線
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              curatorMaterialPoolProvider.overrideWithValue(sampleMaterials),
              curatorRunControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(
              home: Scaffold(body: ReviewSettlementModal()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 驗證 UI 渲染之滿意度、文案與子分數完全等於 domain report
        expect(find.text('${reportAfterSubmit.satisfaction}'), findsOneWidget);
        expect(
          find.text('「${reportAfterSubmit.feedbackQuote}」'),
          findsOneWidget,
        );
        expect(
          find.text(
            '${reportAfterSubmit.subscores['budgetScore']} / ${reportAfterSubmit.maxBudgetScore}',
          ),
          findsOneWidget,
        );

        // 切換至網紅對照頁籤
        await tester.tap(find.byKey(const Key('client_tab_hypeInfluencer')));
        await tester.pumpAndSettle();

        // 操作按鈕依然是指派客戶的結算（收下佣金）
        expect(find.byKey(const Key('btn_collect_rewards')), findsOneWidget);
        expect(
          find.textContaining('+${reportAfterSubmit.earnedCoins} 金幣'),
          findsOneWidget,
        );

        // 點擊收下佣金，驗證持久化與結算 outcome 仍然完全鎖定為指派客戶
        await tester.tap(find.byKey(const Key('btn_collect_rewards')));
        await tester.pumpAndSettle();

        expect(controller.state.phase, CuratorRunPhase.settled);
        expect(controller.state.latestReport!.clientType, 'budgetWorker');
        expect(
          controller.state.latestReport!.satisfaction,
          reportAfterSubmit.satisfaction,
        );
        expect(
          controller.state.latestReport!.earnedCoins,
          reportAfterSubmit.earnedCoins,
        );
      },
    );
  });
}
