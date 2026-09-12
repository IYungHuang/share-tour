import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/causal/causal_fact.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

void main() {
  group('CuratorRunState 焦點光暈生命週期與因果報告 (SPEC §2.4, §3.2.2)', () {
    const sampleMat1 = TravelMaterial(
      id: 'mat_1',
      name: '素材1',
      tags: ['#散步'],
      themeValue: 10,
      hypeValue: 10,
      riskLevel: 1,
    );
    const sampleMat2 = TravelMaterial(
      id: 'mat_2',
      name: '素材2',
      tags: ['#美食'],
      themeValue: 10,
      hypeValue: 10,
      riskLevel: 1,
    );

    test('tweakItinerary 帶入焦點槽位，並在 culpritSlot 為 null 時清除舊焦點', () {
      final initial = CuratorRunState.initial().copyWith(
        phase: CuratorRunPhase.clientReview,
      );
      final controller = CuratorRunController(
        materialPool: const [sampleMat1, sampleMat2],
        initialState: initial,
      );

      // 1. 帶入焦點槽位 2
      controller.tweakItinerary(culpritSlot: 2);
      expect(controller.state.phase, equals(CuratorRunPhase.nightEditing));
      expect(controller.state.focusedCulpritSlot, equals(2));

      // 再次推進至 clientReview
      controller.state = controller.state.copyWith(phase: CuratorRunPhase.clientReview);

      // 2. culpritSlot 為 null 時，應徹底清除焦點，不得因 null-coalescing 保留 2
      controller.tweakItinerary(culpritSlot: null);
      expect(controller.state.phase, equals(CuratorRunPhase.nightEditing));
      expect(controller.state.focusedCulpritSlot, isNull);
    });

    test('placeMaterialInSlot 放置卡片後清除 focusedCulpritSlot', () {
      final initial = CuratorRunState.initial().copyWith(
        phase: CuratorRunPhase.nightEditing,
        focusedCulpritSlot: 1,
      );
      final controller = CuratorRunController(
        materialPool: const [sampleMat1],
        initialState: initial,
      );

      expect(controller.state.focusedCulpritSlot, equals(1));
      controller.placeMaterialInSlot(0, sampleMat1);
      expect(controller.state.focusedCulpritSlot, isNull);
    });

    test('removeMaterialFromSlot 移除卡片後清除 focusedCulpritSlot', () {
      var initial = CuratorRunState.initial().copyWith(
        phase: CuratorRunPhase.nightEditing,
      );
      initial = initial.setTimelineSlot(0, sampleMat1).copyWith(
        focusedCulpritSlot: 0,
      );
      final controller = CuratorRunController(
        materialPool: const [sampleMat1],
        initialState: initial,
      );

      expect(controller.state.focusedCulpritSlot, equals(0));
      controller.removeMaterialFromSlot(0);
      expect(controller.state.focusedCulpritSlot, isNull);
    });

    test('swapSlots 互換槽位卡片後清除 focusedCulpritSlot', () {
      var initial = CuratorRunState.initial().copyWith(
        phase: CuratorRunPhase.nightEditing,
      );
      initial = initial.setTimelineSlot(0, sampleMat1).setTimelineSlot(1, sampleMat2).copyWith(
        focusedCulpritSlot: 1,
      );
      final controller = CuratorRunController(
        materialPool: const [sampleMat1, sampleMat2],
        initialState: initial,
      );

      expect(controller.state.focusedCulpritSlot, equals(1));
      controller.swapSlots(0, 1);
      expect(controller.state.focusedCulpritSlot, isNull);
    });

    test('itineraryCausalReportProvider 從純領域衍生報告，且不因無關資源變更重新計算', () {
      final container = ProviderContainer(
        overrides: [
          curatorMaterialPoolProvider.overrideWithValue([sampleMat1, sampleMat2]),
          curatorRunControllerProvider.overrideWith((ref) => CuratorRunController(
            materialPool: [sampleMat1, sampleMat2],
            initialState: CuratorRunState.initial(
              client: ClientSpec.budgetWorker,
              philosophy: TravelPhilosophy.chaos,
            ),
          )),
        ],
      );
      addTearDown(container.dispose);

      int reportBuildCount = 0;
      container.listen<ItineraryCausalReport>(
        itineraryCausalReportProvider,
        (previous, next) => reportBuildCount++,
        fireImmediately: true,
      );

      expect(reportBuildCount, equals(1));
      final report = container.read(itineraryCausalReportProvider);
      expect(report, isNotNull);
      expect(report.facts, isNotNull);

      // 當阿導在大地圖走動消耗 HP 或花費金幣時，不應重新計算因果報告
      final controller = container.read(curatorRunControllerProvider.notifier);
      controller.state = controller.state.copyWith(
        resources: controller.state.resources.consumeHp(10),
      );

      // 監聽器次數依然保持 1
      expect(reportBuildCount, equals(1));

      // 放入行程素材時，觸發重算
      controller.placeMaterialInSlot(0, sampleMat1);
      final newReport = container.read(itineraryCausalReportProvider);
      expect(reportBuildCount, equals(2));
      expect(newReport.primaryCulpritSlot, equals(0));
    });
  });
}
