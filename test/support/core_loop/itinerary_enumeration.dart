import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';

/// 窮舉排列生成輔助函式
Iterable<List<T>> permutations<T>(List<T> items, int k) sync* {
  if (k < 0 || k > items.length) return;
  if (k == 0) {
    yield const [];
    return;
  }

  Iterable<List<T>> permute(List<T> current, Set<int> usedIndices) sync* {
    if (current.length == k) {
      yield List<T>.unmodifiable(current);
      return;
    }
    for (var i = 0; i < items.length; i++) {
      if (usedIndices.contains(i)) continue;
      current.add(items[i]);
      usedIndices.add(i);
      yield* permute(current, usedIndices);
      usedIndices.remove(i);
      current.removeLast();
    }
  }

  yield* permute([], <int>{});
}

/// 從給定素材清單生成所有合法 3 槽與 4 槽時間線行程
///
/// 4 張相異卡產生 2*P(4,3) + P(4,4) = 48 + 24 = 72 個行程。
/// 6 張相異卡產生 2*P(6,3) + P(6,4) = 240 + 360 = 600 個行程。
/// 3 槽行程必為 [0,1,2] 或 [1,2,3]。
List<TimelineItinerary> enumerateLegalItineraries(List<TravelMaterial> materials) {
  final itineraries = <TimelineItinerary>[];

  // 1. 合法 3 槽：P(n, 3) 個 3 卡組合，分別放 [0,1,2] 與 [1,2,3]
  for (final p in permutations(materials, 3)) {
    // [0,1,2] - 槽位 3 為空
    itineraries.add(
      TimelineItinerary(slots: [p[0], p[1], p[2], null]),
    );
    // [1,2,3] - 槽位 0 為空
    itineraries.add(
      TimelineItinerary(slots: [null, p[0], p[1], p[2]]),
    );
  }

  // 2. 合法 4 槽：P(n, 4) 個 4 卡組合，填滿 [0,1,2,3]
  for (final p in permutations(materials, 4)) {
    itineraries.add(
      TimelineItinerary(slots: [p[0], p[1], p[2], p[3]]),
    );
  }

  return itineraries;
}

/// 依總熱度篩選出所有最高 Hype 行程（保留全部平手）
List<TimelineItinerary> maxByTotalHype(
  Iterable<TimelineItinerary> itineraries, {
  required TravelPhilosophy philosophy,
  required double cameraMultiplier,
  int baseTheme = 50,
}) {
  var maxHype = -1;
  final best = <TimelineItinerary>[];

  for (final it in itineraries) {
    final stats = it.calculateStats(
      philosophy: philosophy,
      cameraMultiplier: cameraMultiplier,
      baseTheme: baseTheme,
    );
    if (stats.totalHype > maxHype) {
      maxHype = stats.totalHype;
      best.clear();
      best.add(it);
    } else if (stats.totalHype == maxHype) {
      best.add(it);
    }
  }

  return best;
}

/// 依客戶審查滿意度篩選出所有最佳行程（保留全部平手）
List<TimelineItinerary> bestBySatisfaction(
  Iterable<TimelineItinerary> itineraries, {
  required ClientSpec client,
  required TravelPhilosophy philosophy,
  required double cameraMultiplier,
  int baseTheme = 50,
}) {
  var maxSatisfaction = -1;
  final best = <TimelineItinerary>[];

  for (final it in itineraries) {
    final stats = it.calculateStats(
      philosophy: philosophy,
      cameraMultiplier: cameraMultiplier,
      baseTheme: baseTheme,
    );
    final report = ClientReviewEngine.evaluate(
      client: client,
      stats: stats,
    );
    if (report.satisfaction > maxSatisfaction) {
      maxSatisfaction = report.satisfaction;
      best.clear();
      best.add(it);
    } else if (report.satisfaction == maxSatisfaction) {
      best.add(it);
    }
  }

  return best;
}
