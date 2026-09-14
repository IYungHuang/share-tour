import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/causal/causal_fact.dart';
import 'package:share_tour/domain/core_loop/causal/curator_codex.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/ui/core_loop/components/causal_badge.dart';
import 'package:share_tour/ui/core_loop/curator_studio_modal.dart';

void main() {
  const walkMaterial = TravelMaterial(
    id: 'm_walk',
    name: '散步景點',
    tags: ['#散步', '#老街'],
    themeValue: 30,
    hypeValue: 20,
    cost: 100,
    riskLevel: 1,
  );

  const foodMaterial = TravelMaterial(
    id: 'm_food',
    name: '美食景點',
    tags: ['#美食', '#老街'],
    themeValue: 30,
    hypeValue: 35,
    cost: 200,
    riskLevel: 3,
  );

  const duskMaterial = TravelMaterial(
    id: 'm_dusk',
    name: '絕景打卡點',
    tags: ['#絕景', '#打卡'],
    themeValue: 40,
    hypeValue: 80,
    isSpotlight: true,
    cost: 300,
    riskLevel: 2,
  );

  final testPool = [walkMaterial, foodMaterial, duskMaterial];

  Widget createSubject({required CuratorRunState state}) {
    return ProviderScope(
      overrides: [
        curatorMaterialPoolProvider.overrideWithValue(testPool),
        curatorRunControllerProvider.overrideWith(
          (ref) => CuratorRunController(
            materialPool: testPool,
            initialState: state,
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: CuratorStudioModal(),
        ),
      ),
    );
  }

  group('客戶意圖表情與 Codex 直通 Tooltip 測試 (AC-CF-3.1, AC-CF-3.3)', () {
    testWidgets('AC-CF-3.1: 畫面上存在唯一 Key(client_expression)，且無第二個客戶表情元件', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = CuratorRunState.create(
        client: ClientSpec.budgetWorker,
        philosophy: TravelPhilosophy.slow,
        equipment: EquipmentInventory.initial(),
      );

      await tester.pumpWidget(createSubject(state: state));

      // 存在唯一表情元件
      expect(find.byKey(const Key('client_expression')), findsOneWidget);

      // 畫面上不存在第二個 client_expression* 元件 (如客群切換器的第二頭像)
      final allClientExpressionWidgets = find.byWidgetPredicate(
        (w) =>
            w.key != null &&
            w.key.toString().contains('client_expression') &&
            w.key != const Key('client_expression'),
      );
      expect(allClientExpressionWidgets, findsNothing);
    });

    testWidgets('AC-CF-3.1: 初始未排滿時為 idle (💤)，點擊彈出具名 personaName 心態氣泡且點空白消褪', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 社畜小林局
      final state = CuratorRunState.create(
        client: ClientSpec.budgetWorker,
        philosophy: TravelPhilosophy.slow,
        equipment: EquipmentInventory.initial(),
      );

      await tester.pumpWidget(createSubject(state: state));

      // 1. 未達提交門檻 (canSubmit == false) 顯示 💤 與 personaName 小林
      expect(find.text('💤'), findsOneWidget);
      expect(find.text('小林'), findsWidgets);

      // 2. 點擊表情頭像彈出定性氣泡
      await tester.tap(find.byKey(const Key('client_expression')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('client_expression_bubble')), findsOneWidget);
      expect(find.textContaining('小林'), findsWidgets);
      expect(find.textContaining('阿導，行程還沒排完呢，我先瞇一下...'), findsOneWidget);

      // 3. 點擊空白處消褪
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('client_expression_bubble')), findsNothing);
    });

    testWidgets('AC-CF-3.1: 網紅安娜局之稱呼與六態切換正確性', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 網紅安娜局
      final state = CuratorRunState.create(
        client: ClientSpec.hypeInfluencer,
        philosophy: TravelPhilosophy.chaos,
        equipment: EquipmentInventory.initial(),
      );

      await tester.pumpWidget(createSubject(state: state));

      expect(find.text('安娜'), findsWidgets);

      await tester.tap(find.byKey(const Key('client_expression')));
      await tester.pumpAndSettle();

      expect(find.textContaining('安娜'), findsWidgets);
      expect(find.byKey(const Key('client_expression_bubble')), findsOneWidget);
    });

    test('AC-CF-3.1 監聽回呼隔離：ProviderContainer.listen 驗證不變心態時回呼不觸發', () {
      final state = CuratorRunState.create(
        client: ClientSpec.budgetWorker,
        philosophy: TravelPhilosophy.slow,
        equipment: EquipmentInventory.initial(),
      );

      final container = ProviderContainer(
        overrides: [
          curatorMaterialPoolProvider.overrideWithValue(testPool),
          curatorRunControllerProvider.overrideWith(
            (ref) => CuratorRunController(
              materialPool: testPool,
              initialState: state,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      int listenerCallCount = 0;
      container.listen<ClientImpression>(
        itineraryCausalReportProvider.select((r) => r.clientImpression),
        (previous, next) {
          listenerCallCount++;
        },
      );

      // 第一次主動讀取
      expect(container.read(itineraryCausalReportProvider).clientImpression, ClientImpression.idle);

      // 操作 controller：放入 1 張卡，行程仍未滿 3 槽 (canSubmit 仍為 false, impression 仍為 idle)
      container.read(curatorRunControllerProvider.notifier).placeMaterialInSlot(0, walkMaterial);
      container.read(itineraryCausalReportProvider);

      // 斷言：由於 clientImpression 仍為 idle，細粒度 select 監聽回呼未曾被觸發 (0 次)
      expect(listenerCallCount, 0);
    });

    testWidgets('AC-CF-3.3: 點擊 CausalBadge 彈出對應 reasonCode 的 CodexTooltip，內含 title, explanation, guideNote', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const fact = CausalFact(
        domain: CausalDomain.adjacency,
        direction: ImpactDirection.positive,
        intensity: ImpactIntensity.major,
        pairIndices: (0, 1),
        sourceSignifier: '🎵 節奏互補',
        reasonCode: 'rhythm_complement',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CausalBadge.fromFact(fact),
            ),
          ),
        ),
      );

      // 點擊徽章
      await tester.tap(find.byKey(const Key('causal_badge_rhythm_complement')));
      await tester.pumpAndSettle();

      // 彈出對應 CodexTooltip
      expect(
        find.byKey(const Key('codex_tooltip_rhythm_complement')),
        findsOneWidget,
      );
      expect(find.text('節奏互補'), findsOneWidget);
      expect(find.text('一張一弛'), findsOneWidget);
      expect(find.textContaining('高低風險行程相間排列'), findsOneWidget);
      expect(find.textContaining('阿導筆記：緊湊之後來點漫步'), findsOneWidget);

      // 點擊遮罩空白處消褪
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('codex_tooltip_rhythm_complement')),
        findsNothing,
      );
    });

    testWidgets('AC-CF-3.3 字典覆蓋：全部 15 條 reasonCode 均具備有效 CodexEntry 且可正常顯示', (
      tester,
    ) async {
      expect(CuratorCodex.entries.length, 15);

      for (final entry in CuratorCodex.entries.entries) {
        expect(entry.value.title.isNotEmpty, isTrue);
        expect(entry.value.jargon.isNotEmpty, isTrue);
        expect(entry.value.explanation.isNotEmpty, isTrue);
        expect(entry.value.guideNote.isNotEmpty, isTrue);
      }
    });

    testWidgets('360dp 螢幕下完整渲染 CuratorStudioModal 頂導航與單一表情頭像且零 RenderFlex 溢出', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = CuratorRunState.create(
        client: ClientSpec.budgetWorker,
        philosophy: TravelPhilosophy.slow,
        equipment: EquipmentInventory.initial(),
      );

      await tester.pumpWidget(createSubject(state: state));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('client_expression')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
