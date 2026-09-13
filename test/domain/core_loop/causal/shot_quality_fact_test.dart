import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/causal/causal_fact.dart';
import 'package:share_tour/domain/core_loop/causal/causal_report_builder.dart';
import 'package:share_tour/domain/core_loop/causal/curator_codex.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';

TravelMaterial card({
  required String id,
  required int hypeValue,
  ShotTier shotTier = ShotTier.normal,
  int cost = 0,
}) => TravelMaterial(
  id: id,
  name: id,
  tags: const [],
  themeValue: 30,
  hypeValue: hypeValue,
  cost: cost,
  shotTier: shotTier,
);

void main() {
  group('AC-M5-8.1: shotQuality 單一詞條', () {
    test('CuratorCodex 有 15 個詞條，含 shot_quality', () {
      expect(CuratorCodex.entries.length, 15);
      expect(CuratorCodex.lookup('shot_quality'), isNotNull);
    });
  });

  group('AC-M5-8.2: 全程 failed 的行程存在指向快門的 CausalFact', () {
    test('全 failed 態產生 negative 方向的 shotQuality 事實', () {
      final it = TimelineItinerary(
        slots: [
          card(id: 'a', hypeValue: 40, shotTier: ShotTier.failed),
          card(id: 'b', hypeValue: 50, shotTier: ShotTier.failed),
          card(id: 'c', hypeValue: 30, shotTier: ShotTier.failed),
          null,
        ],
      );
      final stats = it.calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.0,
      );
      final report = CausalReportBuilder.build(
        itinerary: it,
        stats: stats,
        philosophy: TravelPhilosophy.midnight,
        client: ClientSpec.budgetWorker,
      );
      final shotFacts =
          report.facts.where((f) => f.domain == CausalDomain.shotQuality);
      expect(shotFacts, isNotEmpty);
      expect(shotFacts.every((f) => f.direction == ImpactDirection.negative), isTrue);
      expect(shotFacts.every((f) => f.reasonCode == 'shot_quality'), isTrue);
    });

    test('全 perfect 態產生 positive 方向的 shotQuality 事實', () {
      final it = TimelineItinerary(
        slots: [
          card(id: 'a', hypeValue: 40, shotTier: ShotTier.perfect),
          card(id: 'b', hypeValue: 50, shotTier: ShotTier.perfect),
          null,
          null,
        ],
      );
      final stats = it.calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.0,
      );
      final report = CausalReportBuilder.build(
        itinerary: it,
        stats: stats,
        philosophy: TravelPhilosophy.midnight,
        client: ClientSpec.hypeInfluencer,
      );
      final shotFacts =
          report.facts.where((f) => f.domain == CausalDomain.shotQuality);
      expect(shotFacts, isNotEmpty);
      expect(shotFacts.every((f) => f.direction == ImpactDirection.positive), isTrue);
    });

    test('全 normal 態不產生 shotQuality 事實', () {
      final it = TimelineItinerary(
        slots: [
          card(id: 'a', hypeValue: 40),
          card(id: 'b', hypeValue: 50),
          null,
          null,
        ],
      );
      final stats = it.calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.0,
      );
      final report = CausalReportBuilder.build(
        itinerary: it,
        stats: stats,
        philosophy: TravelPhilosophy.midnight,
        client: ClientSpec.budgetWorker,
      );
      expect(
        report.facts.where((f) => f.domain == CausalDomain.shotQuality),
        isEmpty,
      );
    });
  });
}
