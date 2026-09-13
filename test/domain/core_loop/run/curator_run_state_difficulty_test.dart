import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';

void main() {
  group('AC-M5-5.1: 出發後難度鎖定', () {
    test('selectDifficulty 後出發，難度不因出發而改變', () {
      final briefing = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial(),
      );
      final withPhilosophy = briefing.selectPhilosophy(
        briefing.philosophyChoices.first,
      );
      final withDifficulty = withPhilosophy.selectDifficulty(
        ShutterDifficulty.decisiveMoment,
      );
      final departed = withDifficulty.departToFieldTrip();
      expect(departed.shutterDifficulty, ShutterDifficulty.decisiveMoment);
    });

    test('未選擇時預設 tourist', () {
      final briefing = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial(),
      );
      final state = CuratorRunState.create(
        client: briefing.client,
        philosophy: briefing.philosophy,
        equipment: EquipmentInventory.initial(),
      );
      expect(state.shutterDifficulty, ShutterDifficulty.tourist);
    });
  });

  group('中斷計數與折扣冪次', () {
    test('recordInterruption 累加，interruptionDiscount 為 0.9 的冪次', () {
      final briefing = CuratorRunState.createBriefing(
        equipment: EquipmentInventory.initial(),
      );
      final base = CuratorRunState.create(
        client: briefing.client,
        philosophy: briefing.philosophy,
        equipment: EquipmentInventory.initial(),
      );
      expect(base.interruptionCount, 0);
      expect(base.interruptionDiscount, 1.0);

      final once = base.recordInterruption();
      expect(once.interruptionCount, 1);
      expect(once.interruptionDiscount, closeTo(0.9, 1e-9));

      final twice = once.recordInterruption();
      expect(twice.interruptionCount, 2);
      expect(twice.interruptionDiscount, closeTo(0.81, 1e-9));
    });
  });
}
