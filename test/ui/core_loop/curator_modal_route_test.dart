import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/ui/core_loop/curator_modal_route.dart';

void main() {
  group('單局狀態轉移的彈窗路由 (AC-M4-4.4)', () {
    CuratorRunState fieldTrip() => CuratorRunState.create(
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      equipment: EquipmentInventory.initial(),
    );

    CuratorRunState briefing() => CuratorRunState.createBriefing(
      equipment: EquipmentInventory.initial(),
    );

    test('首次進入行前準備開啟委託彈窗', () {
      expect(
        resolveCuratorModalRoute(fieldTrip(), briefing()),
        CuratorModalRoute.briefing,
      );
    });

    test('開場無前一狀態時，行前準備仍要開啟委託彈窗', () {
      expect(
        resolveCuratorModalRoute(null, briefing()),
        CuratorModalRoute.briefing,
      );
    });

    test('持續停留在行前準備不重複開啟', () {
      expect(
        resolveCuratorModalRoute(briefing(), briefing()),
        CuratorModalRoute.none,
      );
    });

    test('體力透支時開啟夜間工作室', () {
      final healthy = fieldTrip();
      final exhausted = healthy.copyWith(
        resources: healthy.resources.consumeHp(healthy.resources.maxHp),
      );

      expect(healthy.isExhausted, isFalse);
      expect(exhausted.isExhausted, isTrue);
      expect(
        resolveCuratorModalRoute(healthy, exhausted),
        CuratorModalRoute.studio,
      );
    });

    test('已處於透支狀態不重複開啟工作室', () {
      final healthy = fieldTrip();
      final exhausted = healthy.copyWith(
        resources: healthy.resources.consumeHp(healthy.resources.maxHp),
      );

      expect(
        resolveCuratorModalRoute(exhausted, exhausted),
        CuratorModalRoute.none,
      );
    });

    test('探索途中不開啟任何彈窗', () {
      expect(
        resolveCuratorModalRoute(fieldTrip(), fieldTrip()),
        CuratorModalRoute.none,
      );
    });

    test('同一幀同時進入行前準備與透支時，以行前準備優先', () {
      // 兩個條件同時成立時只能開一個，否則兩個彈窗會互相疊在對方上面。
      final exhaustedBriefing = briefing().copyWith(
        phase: CuratorRunPhase.philosophizing,
        resources: briefing().resources.consumeHp(
          briefing().resources.maxHp,
        ),
      );

      expect(
        resolveCuratorModalRoute(fieldTrip(), exhaustedBriefing),
        CuratorModalRoute.briefing,
      );
    });
  });
}
