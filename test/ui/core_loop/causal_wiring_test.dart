import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/meta_equipment.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/ui/core_loop/curator_studio_modal.dart';

/// 14 項端到端因果接線驗證情境規格
class WiringScenario {
  final String reasonCode;
  final String signifier;
  final ClientSpec client;
  final TravelPhilosophy philosophy;
  final List<TravelMaterial?> slots;

  const WiringScenario({
    required this.reasonCode,
    required this.signifier,
    required this.client,
    required this.philosophy,
    required this.slots,
  });
}

void main() {
  // 素材定義庫
  const highRiskA = TravelMaterial(
    id: 'hr_a',
    name: '高危山道 A',
    tags: ['#高風險'],
    themeValue: 30,
    hypeValue: 20,
    cost: 400,
    riskLevel: 3,
  );

  const highRiskB = TravelMaterial(
    id: 'hr_b',
    name: '高危山道 B',
    tags: ['#高風險'],
    themeValue: 30,
    hypeValue: 20,
    cost: 400,
    riskLevel: 3,
  );

  const lowRiskA = TravelMaterial(
    id: 'lr_a',
    name: '平緩散步',
    tags: ['#放鬆'],
    themeValue: 20,
    hypeValue: 15,
    cost: 300,
    riskLevel: 1,
  );

  const doubleResonance = TravelMaterial(
    id: 'double_res',
    name: '深夜酒吧街',
    tags: ['#深夜', '#小酌'],
    themeValue: 35,
    hypeValue: 30,
    cost: 500,
    riskLevel: 1,
  );

  const singleResonance = TravelMaterial(
    id: 'single_res',
    name: '居酒屋',
    tags: ['#深夜'],
    themeValue: 25,
    hypeValue: 20,
    cost: 400,
    riskLevel: 1,
  );

  const repelledCard = TravelMaterial(
    id: 'repelled_mat',
    name: '長途客運站',
    tags: ['#拉車'],
    themeValue: 20,
    hypeValue: 15,
    cost: 300,
    riskLevel: 1,
  );

  const card550 = TravelMaterial(
    id: 'cost_550',
    name: '精緻咖啡廳',
    tags: ['#散步'],
    themeValue: 25,
    hypeValue: 20,
    cost: 550,
    riskLevel: 1,
  );

  const card700 = TravelMaterial(
    id: 'cost_700',
    name: '奢華料亭',
    tags: ['#美食'],
    themeValue: 35,
    hypeValue: 30,
    cost: 700,
    riskLevel: 1,
  );

  const spotlightA = TravelMaterial(
    id: 'spot_a',
    name: '清水寺絕景',
    tags: ['#絕景', '#古蹟'],
    themeValue: 35,
    hypeValue: 40,
    cost: 500,
    riskLevel: 1,
    isSpotlight: true,
  );

  const spotlightB = TravelMaterial(
    id: 'spot_b',
    name: '金閣寺絕景',
    tags: ['#絕景', '#拍照'],
    themeValue: 35,
    hypeValue: 40,
    cost: 500,
    riskLevel: 1,
    isSpotlight: true,
  );

  const spotlightC = TravelMaterial(
    id: 'spot_c',
    name: '伏見稻荷絕景',
    tags: ['#絕景', '#鳥居'],
    themeValue: 35,
    hypeValue: 40,
    cost: 500,
    riskLevel: 1,
    isSpotlight: true,
  );

  const spotlightD = TravelMaterial(
    id: 'spot_d',
    name: '嵐山竹林絕景',
    tags: ['#絕景', '#竹林'],
    themeValue: 35,
    hypeValue: 40,
    cost: 500,
    riskLevel: 1,
    isSpotlight: true,
  );

  const lowHypeCard = TravelMaterial(
    id: 'low_hype',
    name: '無聊自習室',
    tags: ['#安靜'],
    themeValue: 20,
    hypeValue: 5,
    cost: 200,
    riskLevel: 1,
  );

  const synergyTagA = TravelMaterial(
    id: 'syn_a',
    name: '古蹟寺院 A',
    tags: ['#古蹟'],
    themeValue: 25,
    hypeValue: 20,
    cost: 300,
    riskLevel: 1,
  );

  const synergyTagB = TravelMaterial(
    id: 'syn_b',
    name: '古蹟寺院 B',
    tags: ['#古蹟'],
    themeValue: 25,
    hypeValue: 20,
    cost: 300,
    riskLevel: 1,
  );

  const morningWalk = TravelMaterial(
    id: 'm_walk',
    name: '晨間漫步',
    tags: ['#散步'],
    themeValue: 20,
    hypeValue: 15,
    cost: 200,
    riskLevel: 1,
  );

  const noonFood = TravelMaterial(
    id: 'n_food',
    name: '午後拉麵',
    tags: ['#美食'],
    themeValue: 25,
    hypeValue: 25,
    cost: 350,
    riskLevel: 1,
  );

  const midnightDrink = TravelMaterial(
    id: 'm_drink',
    name: '午夜特調',
    tags: ['#小酌'],
    themeValue: 30,
    hypeValue: 25,
    cost: 400,
    riskLevel: 1,
  );

  const neutralCard = TravelMaterial(
    id: 'neutral',
    name: '普通小憩',
    tags: ['#休息'],
    themeValue: 20,
    hypeValue: 20,
    cost: 200,
    riskLevel: 1,
  );

  final samplePool = [
    highRiskA,
    highRiskB,
    lowRiskA,
    doubleResonance,
    singleResonance,
    repelledCard,
    card550,
    card700,
    spotlightA,
    spotlightB,
    spotlightC,
    spotlightD,
    lowHypeCard,
    synergyTagA,
    synergyTagB,
    morningWalk,
    noonFood,
    midnightDrink,
    neutralCard,
  ];

  CuratorRunState stateOf(WiringScenario scenario) {
    var state = CuratorRunState.create(
      client: scenario.client,
      philosophy: scenario.philosophy,
      equipment: EquipmentInventory.initial(),
    );
    for (var i = 0; i < 4; i++) {
      final m = scenario.slots[i];
      if (m != null) {
        state = state.setTimelineSlot(i, m);
      }
    }
    return state.copyWith(phase: CuratorRunPhase.nightEditing);
  }

  Widget studioWith(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: CuratorStudioModal(),
        ),
      ),
    );
  }

  final wiringScenarios = <WiringScenario>[
    // 1. fatigue_spike
    const WiringScenario(
      reasonCode: 'fatigue_spike',
      signifier: '💀 拉車疲勞',
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      slots: [highRiskA, highRiskB, neutralCard, neutralCard],
    ),
    // 2. fatigue_hype_penalty
    const WiringScenario(
      reasonCode: 'fatigue_hype_penalty',
      signifier: '💀 脫妝暴跌',
      client: ClientSpec.hypeInfluencer,
      philosophy: TravelPhilosophy.midnight,
      slots: [highRiskA, highRiskB, neutralCard, neutralCard],
    ),
    // 3. chaotic_combo
    const WiringScenario(
      reasonCode: 'chaotic_combo',
      signifier: '⚡ 驚險連段',
      client: ClientSpec.hypeInfluencer,
      philosophy: TravelPhilosophy.chaos,
      slots: [highRiskA, highRiskB, neutralCard, neutralCard],
    ),
    // 4. rhythm_complement
    const WiringScenario(
      reasonCode: 'rhythm_complement',
      signifier: '🎵 節奏互補',
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      slots: [lowRiskA, highRiskA, neutralCard, neutralCard],
    ),
    // 5. philosophy_matched_major
    const WiringScenario(
      reasonCode: 'philosophy_matched_major',
      signifier: '★★ 強烈共鳴',
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      slots: [doubleResonance, neutralCard, neutralCard, neutralCard],
    ),
    // 6. philosophy_matched_minor
    const WiringScenario(
      reasonCode: 'philosophy_matched_minor',
      signifier: '★ 契合',
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      slots: [singleResonance, neutralCard, neutralCard, neutralCard],
    ),
    // 7. philosophy_repelled
    const WiringScenario(
      reasonCode: 'philosophy_repelled',
      signifier: '💢 排斥',
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      slots: [repelledCard, neutralCard, neutralCard, neutralCard],
    ),
    // 8. budget_overrun_minor (2200 / 2000 = 10% <= 15%)
    const WiringScenario(
      reasonCode: 'budget_overrun_minor',
      signifier: '⚠️ 超支·輕度',
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      slots: [card550, card550, card550, card550],
    ),
    // 9. budget_overrun_major (2800 / 2000 = 40% > 15%)
    const WiringScenario(
      reasonCode: 'budget_overrun_major',
      signifier: '🚨 超支·爆表',
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      slots: [card700, card700, card700, card700],
    ),
    // 10. spotlight_full
    const WiringScenario(
      reasonCode: 'spotlight_full',
      signifier: '🌟 絕景大滿貫',
      client: ClientSpec.hypeInfluencer,
      philosophy: TravelPhilosophy.chaos,
      slots: [spotlightA, spotlightB, spotlightC, spotlightD],
    ),
    // 11. spotlight_shortfall
    const WiringScenario(
      reasonCode: 'spotlight_shortfall',
      signifier: '📉 絕景缺口',
      client: ClientSpec.hypeInfluencer,
      philosophy: TravelPhilosophy.chaos,
      slots: [spotlightA, neutralCard, neutralCard, neutralCard],
    ),
    // 12. boredom_risk
    const WiringScenario(
      reasonCode: 'boredom_risk',
      signifier: '🚨 極度乏味',
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      slots: [lowHypeCard, lowHypeCard, lowHypeCard, lowHypeCard],
    ),
    // 13. tag_synergy
    const WiringScenario(
      reasonCode: 'tag_synergy',
      signifier: '[共鳴]',
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      slots: [synergyTagA, synergyTagB, neutralCard, neutralCard],
    ),
    // 14. ambient_slot_affinity
    const WiringScenario(
      reasonCode: 'ambient_slot_affinity',
      signifier: '[時段契合]',
      client: ClientSpec.budgetWorker,
      philosophy: TravelPhilosophy.midnight,
      slots: [morningWalk, neutralCard, neutralCard, neutralCard],
    ),
  ];

  group('端到端接線守門與全系統驗收 (AC-CF-2)', () {
    testWidgets(
      'AC-CF-2.1: 14 項因果代碼全部從真實行程經 calculateStats 與 builder 抵達畫面',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        for (final scenario in wiringScenarios) {
          final state = stateOf(scenario);
          final container = ProviderContainer(
            overrides: [
              curatorRunControllerProvider.overrideWith(
                (ref) => CuratorRunController(
                  materialPool: samplePool,
                  initialState: state,
                ),
              ),
            ],
          );
          addTearDown(container.dispose);

          // 鏈條中段：證明 builder 確實自真實行程產出該 reasonCode
          final report = container.read(itineraryCausalReportProvider);
          expect(
            report.facts.map((f) => f.reasonCode),
            contains(scenario.reasonCode),
            reason: '${scenario.reasonCode}：builder 沒從真實行程產出這條事實',
          );

          // 鏈條末段：證明符號真實抵達畫面（不為零可見死碼）
          await tester.pumpWidget(studioWith(container));
          await tester.pumpAndSettle();

          expect(
            find.textContaining(scenario.signifier),
            findsWidgets,
            reason: '${scenario.reasonCode} 在工作台畫面未尋得符號「${scenario.signifier}」',
          );
        }
      },
    );

    testWidgets(
      'AC-CF-2.3: 五個擊穿欄位各有真實情境端到端證明 (fatiguePairs, rhythmActivePairs, comboActiveSlots, slotThemeBonuses, spotlightCount)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. fatiguePairs -> fatigue_spike
        final fatigueScenario = wiringScenarios.firstWhere((s) => s.reasonCode == 'fatigue_spike');
        final fatigueContainer = ProviderContainer(
          overrides: [
            curatorRunControllerProvider.overrideWith(
              (ref) => CuratorRunController(
                materialPool: samplePool,
                initialState: stateOf(fatigueScenario),
              ),
            ),
          ],
        );
        addTearDown(fatigueContainer.dispose);
        final fatigueStats = fatigueContainer.read(itineraryStatsProvider);
        expect(fatigueStats.fatiguePairs, contains(0));
        await tester.pumpWidget(studioWith(fatigueContainer));
        await tester.pumpAndSettle();
        expect(find.textContaining('0-1 💀 拉車疲勞'), findsOneWidget);

        // 2. rhythmActivePairs -> rhythm_complement
        final rhythmScenario = wiringScenarios.firstWhere((s) => s.reasonCode == 'rhythm_complement');
        final rhythmContainer = ProviderContainer(
          overrides: [
            curatorRunControllerProvider.overrideWith(
              (ref) => CuratorRunController(
                materialPool: samplePool,
                initialState: stateOf(rhythmScenario),
              ),
            ),
          ],
        );
        addTearDown(rhythmContainer.dispose);
        final rhythmStats = rhythmContainer.read(itineraryStatsProvider);
        expect(rhythmStats.rhythmActivePairs, contains(0));
        await tester.pumpWidget(studioWith(rhythmContainer));
        await tester.pumpAndSettle();
        expect(find.textContaining('0-1 🎵 節奏互補'), findsOneWidget);

        // 3. comboActiveSlots -> tag_synergy
        final comboScenario = wiringScenarios.firstWhere((s) => s.reasonCode == 'tag_synergy');
        final comboContainer = ProviderContainer(
          overrides: [
            curatorRunControllerProvider.overrideWith(
              (ref) => CuratorRunController(
                materialPool: samplePool,
                initialState: stateOf(comboScenario),
              ),
            ),
          ],
        );
        addTearDown(comboContainer.dispose);
        final comboStats = comboContainer.read(itineraryStatsProvider);
        expect(comboStats.comboActiveSlots, contains(1));
        await tester.pumpWidget(studioWith(comboContainer));
        await tester.pumpAndSettle();
        expect(find.textContaining('0-1 [共鳴]'), findsOneWidget);

        // 4. slotThemeBonuses (覆蓋 Slot 0, 1, 3 各一)
        var allSlotsState = CuratorRunState.create(
          client: ClientSpec.budgetWorker,
          philosophy: TravelPhilosophy.midnight,
          equipment: EquipmentInventory.initial(),
        );
        allSlotsState = allSlotsState.setTimelineSlot(0, morningWalk); // Slot 0 affinity (+5)
        allSlotsState = allSlotsState.setTimelineSlot(1, noonFood); // Slot 1 affinity (+5)
        allSlotsState = allSlotsState.setTimelineSlot(2, neutralCard);
        allSlotsState = allSlotsState.setTimelineSlot(3, midnightDrink); // Slot 3 affinity (+5)
        allSlotsState = allSlotsState.copyWith(phase: CuratorRunPhase.nightEditing);

        final slotContainer = ProviderContainer(
          overrides: [
            curatorRunControllerProvider.overrideWith(
              (ref) => CuratorRunController(
                materialPool: samplePool,
                initialState: allSlotsState,
              ),
            ),
          ],
        );
        addTearDown(slotContainer.dispose);
        final slotStats = slotContainer.read(itineraryStatsProvider);
        expect(slotStats.slotThemeBonuses.keys, containsAll([0, 1, 3]));
        await tester.pumpWidget(studioWith(slotContainer));
        await tester.pumpAndSettle();
        // 畫面上 Slot 0, 1, 3 各呈現 [時段契合] 徽章，共 3 個
        expect(find.textContaining('[時段契合]'), findsNWidgets(3));

        // 5. spotlightCount -> spotlight_full & spotlight_shortfall
        final spotFullScenario = wiringScenarios.firstWhere((s) => s.reasonCode == 'spotlight_full');
        final spotFullContainer = ProviderContainer(
          overrides: [
            curatorRunControllerProvider.overrideWith(
              (ref) => CuratorRunController(
                materialPool: samplePool,
                initialState: stateOf(spotFullScenario),
              ),
            ),
          ],
        );
        addTearDown(spotFullContainer.dispose);
        final spotFullStats = spotFullContainer.read(itineraryStatsProvider);
        expect(spotFullStats.spotlightCount, equals(4));
        await tester.pumpWidget(studioWith(spotFullContainer));
        await tester.pumpAndSettle();
        expect(find.textContaining('🌟 絕景大滿貫'), findsOneWidget);

        final spotShortScenario = wiringScenarios.firstWhere((s) => s.reasonCode == 'spotlight_shortfall');
        final spotShortContainer = ProviderContainer(
          overrides: [
            curatorRunControllerProvider.overrideWith(
              (ref) => CuratorRunController(
                materialPool: samplePool,
                initialState: stateOf(spotShortScenario),
              ),
            ),
          ],
        );
        addTearDown(spotShortContainer.dispose);
        final spotShortStats = spotShortContainer.read(itineraryStatsProvider);
        expect(spotShortStats.spotlightCount, equals(1));
        await tester.pumpWidget(studioWith(spotShortContainer));
        await tester.pumpAndSettle();
        expect(find.textContaining('📉 絕景缺口'), findsOneWidget);
      },
    );
  });
}
