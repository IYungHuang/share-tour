import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';

import 'itinerary_enumeration.dart';

void main() {
  group('itinerary_enumeration 窮舉行程輔助工具自證測試', () {
    TravelMaterial makeCard(String id, {int hype = 10, int cost = 100}) {
      return TravelMaterial(
        id: id,
        name: id,
        tags: const ['#散步'],
        themeValue: 10,
        hypeValue: hype,
        cost: cost,
        riskLevel: 1,
      );
    }

    test('4 張不同合成卡產生 2P(4,3) + P(4,4) = 72 個合法行程', () {
      final pool = [
        makeCard('c1'),
        makeCard('c2'),
        makeCard('c3'),
        makeCard('c4'),
      ];

      final results = enumerateLegalItineraries(pool);
      expect(results.length, equals(72));

      for (final it in results) {
        final nonNulls = it.slots.whereType<TravelMaterial>().toList();
        expect(nonNulls.length, anyOf(3, 4));

        final ids = nonNulls.map((m) => m.id).toSet();
        expect(ids.length, equals(nonNulls.length), reason: '素材 ID 必須唯一');

        if (nonNulls.length == 3) {
          final isLeft = it.slots[0] != null &&
              it.slots[1] != null &&
              it.slots[2] != null &&
              it.slots[3] == null;
          final isRight = it.slots[0] == null &&
              it.slots[1] != null &&
              it.slots[2] != null &&
              it.slots[3] != null;
          expect(isLeft || isRight, isTrue, reason: '3 槽只可能 [0,1,2] 或 [1,2,3]');
        }
      }
    });

    test('6 張不同合成卡產生 2P(6,3) + P(6,4) = 600 個合法行程', () {
      final pool = List.generate(6, (i) => makeCard('c$i'));
      final results = enumerateLegalItineraries(pool);
      expect(results.length, equals(600));

      final threeSlotCount = results.where((it) => it.slots.whereType<TravelMaterial>().length == 3).length;
      final fourSlotCount = results.where((it) => it.slots.whereType<TravelMaterial>().length == 4).length;

      expect(threeSlotCount, equals(240)); // 2 * P(6, 3) = 240
      expect(fourSlotCount, equals(360)); // P(6, 4) = 360
    });

    test('bestBySatisfaction 與 maxByTotalHype 為不同聚合，且保留全部平手', () {
      final c1 = makeCard('c1', hype: 50, cost: 500);
      final c2 = makeCard('c2', hype: 50, cost: 500);
      final c3 = makeCard('c3', hype: 50, cost: 500);
      final c4 = makeCard('c4', hype: 50, cost: 500);
      final pool = [c1, c2, c3, c4];

      final itineraries = enumerateLegalItineraries(pool);

      final maxHypeList = maxByTotalHype(
        itineraries,
        philosophy: TravelPhilosophy.slow,
        cameraMultiplier: 1.5,
      );
      expect(maxHypeList.length, greaterThan(1), reason: '全平手時應保留全部解');

      final bestSatList = bestBySatisfaction(
        itineraries,
        client: ClientSpec.budgetWorker,
        philosophy: TravelPhilosophy.slow,
        cameraMultiplier: 1.5,
      );
      expect(bestSatList.length, greaterThan(1), reason: '全平手時應保留全部解');
    });
  });
}
