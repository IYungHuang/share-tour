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
  });
}
