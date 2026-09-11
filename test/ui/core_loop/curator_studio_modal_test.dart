import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/ui/core_loop/curator_studio_modal.dart';
import 'package:share_tour/ui/core_loop/review_settlement_modal.dart';

void main() {
  final sampleMaterials = List.generate(
    4,
    (i) => TravelMaterial(
      id: 'm_$i',
      name: '素材 $i',
      tags: ['#深夜'],
      themeValue: 30,
      hypeValue: 20,
      cost: 400,
    ),
  );

  Widget createSubject({CuratorRunState? initialState}) {
    return ProviderScope(
      key: UniqueKey(),
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
      child: const MaterialApp(home: Scaffold(body: CuratorStudioModal())),
    );
  }

  group('CuratorStudioModal 整合測試 (U5)', () {
    testWidgets('工作台渲染完整組件：導航列、時間線軌道、數值看板、腰包抽屜', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject());

      expect(find.textContaining('策展工作台'), findsOneWidget);
      expect(find.byKey(const Key('studio_close_button')), findsOneWidget);
      expect(find.byKey(const Key('slot_card_0')), findsOneWidget);
      expect(find.byKey(const Key('submit_itinerary_button')), findsOneWidget);
      expect(
        find.byKey(const Key('draw_sample_material_button')),
        findsOneWidget,
      );
    });

    testWidgets('當 4 槽位填滿時點擊呈送按鈕，彈出 ReviewSettlementModal', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var state = CuratorRunState.initial();
      for (var i = 0; i < 4; i++) {
        state = state.setTimelineSlot(i, sampleMaterials[i]);
      }

      await tester.pumpWidget(createSubject(initialState: state));
      expect(find.byKey(const Key('submit_itinerary_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('submit_itinerary_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewSettlementModal), findsOneWidget);
    });
  });
}
