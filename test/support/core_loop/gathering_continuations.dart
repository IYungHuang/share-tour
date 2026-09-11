import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';

/// 採集分支評估結果 (AC-A1-6.2)
class GatheringBranchEvaluation {
  const GatheringBranchEvaluation({
    required this.maxSatisfaction,
    required this.bestItineraries,
    required this.totalHandsEvaluated,
    required this.totalItinerariesEvaluated,
  });

  final int maxSatisfaction;
  final List<TimelineItinerary> bestItineraries;
  final int totalHandsEvaluated;
  final int totalItinerariesEvaluated;
}

/// 窮舉給定分支下的所有採集續局，並在 HP 與腰包容量限制下評估合法行程的最佳滿意度
GatheringBranchEvaluation evaluateGatheringContinuations({
  required List<TravelMaterial> startHand,
  required int startHp,
  required List<TravelMaterial> remainingPool,
  required TravelPhilosophy philosophy,
  required ClientSpec client,
  required double cameraMultiplier,
  int waistBagCapacity = 6,
  bool ignoreHpLimit = false,
}) {
  var maxSat = -1;
  final bestItineraries = <TimelineItinerary>[];
  var totalHands = 0;
  var totalItineraries = 0;

  void evaluateHand(List<TravelMaterial> hand) {
    if (hand.length < 3) return;
    totalHands++;

    // 3-slot: [hand[i], hand[j], hand[k], null] 與 [null, hand[i], hand[j], hand[k]]
    for (var i = 0; i < hand.length; i++) {
      for (var j = 0; j < hand.length; j++) {
        if (j == i) continue;
        for (var k = 0; k < hand.length; k++) {
          if (k == i || k == j) continue;

          for (final slots in [
            [hand[i], hand[j], hand[k], null],
            [null, hand[i], hand[j], hand[k]],
          ]) {
            totalItineraries++;
            final it = TimelineItinerary(slots: slots);
            final sat = ClientReviewEngine.evaluate(
              client: client,
              stats: it.calculateStats(
                philosophy: philosophy,
                cameraMultiplier: cameraMultiplier,
              ),
              philosophy: philosophy,
            ).satisfaction;

            if (sat > maxSat) {
              maxSat = sat;
              bestItineraries.clear();
              bestItineraries.add(it);
            } else if (sat == maxSat) {
              bestItineraries.add(it);
            }
          }
        }
      }
    }

    // 4-slot: [hand[i], hand[j], hand[k], hand[l]]
    if (hand.length >= 4) {
      for (var i = 0; i < hand.length; i++) {
        for (var j = 0; j < hand.length; j++) {
          if (j == i) continue;
          for (var k = 0; k < hand.length; k++) {
            if (k == i || k == j) continue;
            for (var l = 0; l < hand.length; l++) {
              if (l == i || l == j || l == k) continue;

              totalItineraries++;
              final it = TimelineItinerary(
                slots: [hand[i], hand[j], hand[k], hand[l]],
              );
              final sat = ClientReviewEngine.evaluate(
                client: client,
                stats: it.calculateStats(
                  philosophy: philosophy,
                  cameraMultiplier: cameraMultiplier,
                ),
                philosophy: philosophy,
              ).satisfaction;

              if (sat > maxSat) {
                maxSat = sat;
                bestItineraries.clear();
                bestItineraries.add(it);
              } else if (sat == maxSat) {
                bestItineraries.add(it);
              }
            }
          }
        }
      }
    }
  }

  void dfs(List<TravelMaterial> currentHand, int remainingHp, int poolIdx) {
    evaluateHand(currentHand);
    if (currentHand.length >= waistBagCapacity) return;

    for (var i = poolIdx; i < remainingPool.length; i++) {
      final nextCard = remainingPool[i];
      final cost = gatheringHpCost(nextCard);
      if (ignoreHpLimit || remainingHp >= cost) {
        dfs(
          [...currentHand, nextCard],
          remainingHp - cost,
          i + 1,
        );
      }
    }
  }

  dfs(startHand, startHp, 0);

  return GatheringBranchEvaluation(
    maxSatisfaction: maxSat,
    bestItineraries: bestItineraries,
    totalHandsEvaluated: totalHands,
    totalItinerariesEvaluated: totalItineraries,
  );
}
