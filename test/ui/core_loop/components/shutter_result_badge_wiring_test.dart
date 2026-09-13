// 煙霧測試等級（`CLAUDE.md` §2：`ui/` 不追求覆蓋率）。
//
// AC-M5-11.3：三態徽章在腰包抽屜、4 槽位卡面、結算歸因三處皆存在且符號一致
// ——三處共用同一個 `ShutterResultBadge` 元件，符號一致由元件本身保證，
// 這裡只驗證三處都確實引用了它（用同一個 Key 命名慣例找）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/material_inventory.dart';
import 'package:share_tour/domain/core_loop/models/review_outcome.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/ui/core_loop/components/compact_slot_card.dart';
import 'package:share_tour/ui/core_loop/components/waist_bag_drawer.dart';
import 'package:share_tour/ui/core_loop/review_settlement_modal.dart';

const _perfectMaterial = TravelMaterial(
  id: 'perfect_card',
  name: '完美一擊',
  tags: ['#深夜'],
  themeValue: 30,
  hypeValue: 50,
  cost: 300,
  shotTier: ShotTier.perfect,
);

void main() {
  Widget wrap(CuratorRunState state, Widget child) {
    return ProviderScope(
      overrides: [
        curatorMaterialPoolProvider.overrideWithValue(const [_perfectMaterial]),
        curatorRunControllerProvider.overrideWith(
          (ref) => CuratorRunController(
            materialPool: const [_perfectMaterial],
            initialState: state,
          ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('腰包抽屜顯示 perfect 徽章', (tester) async {
    var state = CuratorRunState.create(
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      equipment: EquipmentInventory.initial(),
    );
    state = state.copyWith(
      inventory: MaterialInventory(capacity: 6, materials: const [_perfectMaterial]),
    );

    await tester.pumpWidget(wrap(state, const WaistBagDrawer()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shutterResultBadge.perfect')), findsOneWidget);
  });

  testWidgets('4 槽位卡面顯示 perfect 徽章', (tester) async {
    var state = CuratorRunState.create(
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      equipment: EquipmentInventory.initial(),
    );
    state = state.setTimelineSlot(0, _perfectMaterial);

    await tester.pumpWidget(wrap(state, const Row(children: [CompactSlotCard(slotIndex: 0)])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shutterResultBadge.perfect')), findsOneWidget);
  });

  testWidgets('結算歸因區顯示 perfect 徽章', (tester) async {
    var state = CuratorRunState.create(
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      equipment: EquipmentInventory.initial(),
    );
    for (var i = 0; i < 4; i++) {
      state = state.setTimelineSlot(i, i == 0 ? _perfectMaterial : _perfectMaterial.copyWith(id: 'm$i', shotTier: ShotTier.normal));
    }
    state = state.copyWith(phase: CuratorRunPhase.clientReview);

    final report = ReviewReport(
      clientType: 'budgetWorker',
      outcome: ReviewOutcome.pass,
      satisfaction: 80,
      earnedCoins: 100,
      feedbackQuote: '不錯',
      subscores: const {},
    );

    await tester.pumpWidget(
      wrap(
        state,
        ReviewSettlementModal(initialReport: report),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shutterResultBadge.perfect')), findsOneWidget);
  });
}
