import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/ui/core_loop/field/curator_field_hud.dart';

void main() {
  group('CuratorFieldHud Widget 測試 (G3, AC-M3-1.1)', () {
    Widget buildTestWidget({required CuratorRunState state}) {
      return ProviderScope(
        overrides: [
          curatorRunControllerProvider.overrideWith((ref) {
            return CuratorRunController(
              materialPool: const [],
              initialState: state,
            );
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: CuratorFieldHud(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('AC-M3-1.1 初始渲染：顯示滿血 100/100、預算 ¥2,000、腰包 0/6', (tester) async {
      final state = CuratorRunState.initial(
        client: ClientSpec.budgetWorker,
        initialBudget: 2000,
        initialHp: 100,
      );

      await tester.pumpWidget(buildTestWidget(state: state));

      expect(find.textContaining('100/100'), findsOneWidget);
      expect(find.textContaining('2000'), findsOneWidget);
      expect(find.textContaining('0/6'), findsOneWidget);
    });

    testWidgets('HP 扣減即時反應與赤字預算呈現紅色警告', (tester) async {
      final state = CuratorRunState.initial(
        client: ClientSpec.budgetWorker,
        initialBudget: 2000,
        initialHp: 100,
      );
      // 人為扣除 HP 至 15 (紅色警戒)，預算扣至 -500 (赤字)
      final damagedState = state.copyWith(
        resources: state.resources.consumeHp(85).spendBudget(2500),
        inventory: state.inventory.add(
          const TravelMaterial(
            id: 'mat_1',
            name: '測試卡',
            tags: ['#美食'],
            themeValue: 10,
            hypeValue: 10,
          ),
        ),
      );

      await tester.pumpWidget(buildTestWidget(state: damagedState));

      expect(find.textContaining('15/100'), findsOneWidget);
      expect(find.textContaining('-500'), findsOneWidget);
      expect(find.textContaining('1/6'), findsOneWidget);
    });

    testWidgets('在 360dp 寬度手機螢幕下自適應，零 RenderFlex Overflow', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final state = CuratorRunState.initial(
        client: ClientSpec.budgetWorker,
        initialBudget: 99999,
        initialHp: 100,
      );

      await tester.pumpWidget(buildTestWidget(state: state));
      expect(tester.takeException(), isNull);
    });
  });
}
