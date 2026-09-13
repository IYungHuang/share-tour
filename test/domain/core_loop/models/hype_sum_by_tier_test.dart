import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';

TravelMaterial card({
  required String id,
  required int hypeValue,
  bool isSpotlight = false,
  ShotTier shotTier = ShotTier.normal,
  int cost = 0,
}) => TravelMaterial(
  id: id,
  name: id,
  tags: const [],
  themeValue: 10,
  hypeValue: hypeValue,
  isSpotlight: isSpotlight,
  cost: cost,
  shotTier: shotTier,
);

void main() {
  group('ItineraryStats.hypeSumByTier（六分量：3態 × 絕景/非絕景）', () {
    test('單張非絕景 perfect 卡歸入 perfectNonSpotlightHype', () {
      final it = TimelineItinerary(
        slots: [
          card(id: 'a', hypeValue: 50, shotTier: ShotTier.perfect),
          null,
          null,
          null,
        ],
      );
      final stats = it.calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.0,
      );
      expect(stats.perfectNonSpotlightHype, 50);
      expect(stats.perfectSpotlightHype, 0);
      expect(stats.normalNonSpotlightHype, 0);
      expect(stats.failedNonSpotlightHype, 0);
    });

    test('混合絕景/非絕景同態，各自獨立累加', () {
      final it = TimelineItinerary(
        slots: [
          card(id: 'a', hypeValue: 80, isSpotlight: true, shotTier: ShotTier.perfect),
          card(id: 'b', hypeValue: 55, shotTier: ShotTier.perfect),
          card(id: 'c', hypeValue: 60, isSpotlight: true, shotTier: ShotTier.failed),
          card(id: 'd', hypeValue: 40, shotTier: ShotTier.normal),
        ],
      );
      final stats = it.calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.0,
      );
      expect(stats.perfectSpotlightHype, 80);
      expect(stats.perfectNonSpotlightHype, 55);
      expect(stats.failedSpotlightHype, 60);
      expect(stats.normalNonSpotlightHype, 40);
      expect(stats.normalSpotlightHype, 0);
      expect(stats.failedNonSpotlightHype, 0);
    });

    test('用 material.hypeValue 而非 slotEffectiveHypes（排列相依量），'
        '打亂槽位順序後六分量總和不變', () {
      final a = card(id: 'a', hypeValue: 30, shotTier: ShotTier.perfect);
      final b = card(id: 'b', hypeValue: 45, shotTier: ShotTier.perfect);
      final c = card(id: 'c', hypeValue: 20, shotTier: ShotTier.normal);

      final order1 = TimelineItinerary(slots: [a, b, c, null]).calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.5, // 相機倍率只影響 slotEffectiveHypes[2]
      );
      final order2 = TimelineItinerary(slots: [c, a, null, b]).calculateStats(
        philosophy: TravelPhilosophy.midnight,
        cameraMultiplier: 1.5,
      );

      expect(order1.perfectNonSpotlightHype, order2.perfectNonSpotlightHype);
      expect(order1.normalNonSpotlightHype, order2.normalNonSpotlightHype);
    });
  });
}
