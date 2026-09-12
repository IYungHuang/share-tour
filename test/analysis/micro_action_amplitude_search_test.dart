// 一次性分析腳本（非驗收測試）：為 SPEC_MVP_MICRO_ACTION v3 求三態幅度。
//
// 母體沿用 AC-A1-5.1 的 16-POI 子集（`reachablePool.take(16)`），每手 6 張，
// 5 哲學 × 2 客戶。排列以 `normal` 態的最佳解決定（排列選擇與幅度無關），
// 再在同一排列上評估三態 × 三組候選幅度。
//
// 輸出：三態兩兩相異比例、完全同分比例、極差分佈。
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';

/// 候選幅度：(一般卡增減量, 絕景增減量)
const candidates = <String, (int, int)>{
  '±2/±3': (2, 3),
  '±3/±5': (3, 5),
  '±4/±7': (4, 7),
  '±6/±10': (6, 10),
  '±8/±13': (8, 13),
};

TravelMaterial shift(TravelMaterial m, int delta) {
  final next = m.hypeValue + delta;
  return m.copyWith(hypeValue: next < 0 ? 0 : next);
}

class Acc {
  int total = 0;
  int distinct3 = 0;
  int allSame = 0;
  int perfectEqNormal = 0;
  int failedEqNormal = 0;
  int maxSpread = 0;
  int sumSpread = 0;
  final List<int> spreads = [];

  void add(int p, int n, int f) {
    total++;
    final set = {p, n, f};
    if (set.length == 3) distinct3++;
    if (set.length == 1) allSame++;
    if (p == n) perfectEqNormal++;
    if (f == n) failedEqNormal++;
    final spread = [p, n, f].reduce((a, b) => a > b ? a : b) -
        [p, n, f].reduce((a, b) => a < b ? a : b);
    if (spread > maxSpread) maxSpread = spread;
    sumSpread += spread;
    spreads.add(spread);
  }

  String report(String label) {
    spreads.sort();
    final p95 = spreads[(spreads.length * 0.95).floor()];
    final median = spreads[spreads.length ~/ 2];
    return '$label  n=$total  '
        '三態相異 ${(distinct3 / total * 100).toStringAsFixed(1)}%  '
        '完全同分 ${(allSame / total * 100).toStringAsFixed(1)}%  '
        'P=N ${(perfectEqNormal / total * 100).toStringAsFixed(1)}%  '
        'F=N ${(failedEqNormal / total * 100).toStringAsFixed(1)}%  '
        '極差 mean ${(sumSpread / total).toStringAsFixed(1)} / med $median / p95 $p95 / max $maxSpread';
  }
}

void main() {
  test('micro-action amplitude search', () {
    const manifest = KyotoNightMapManifest();
    const resolver = KyotoPoiMaterialResolver();
    final reachable = manifest.districtAttractions
        .map((a) => resolver.resolveMaterialFor(a.id)!)
        .toList();
    final pool = reachable.take(16).toList();
    final n = pool.length;

    final clients = {
      '社畜': ClientSpec.budgetWorker,
      '網紅': ClientSpec.hypeInfluencer,
    };
    // key: '客戶|幅度'
    final acc = <String, Acc>{};
    for (final c in clients.keys) {
      for (final a in candidates.keys) {
        acc['$c|$a'] = Acc();
      }
    }

    int evaluate(List<TravelMaterial?> slots, ClientSpec client,
        TravelPhilosophy phil, double cam) {
      final it = TimelineItinerary(slots: slots);
      return ClientReviewEngine.evaluate(
        client: client,
        stats: it.calculateStats(philosophy: phil, cameraMultiplier: cam),
        philosophy: phil,
      ).satisfaction;
    }

    const cam = 1.5; // 相機 Lv.1，與 AC-A1-5.1 同基準
    var hands = 0;

    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        for (var k = j + 1; k < n; k++) {
          for (var l = k + 1; l < n; l++) {
            for (var m = l + 1; m < n; m++) {
              for (var q = m + 1; q < n; q++) {
                hands++;
                final hand = [pool[i], pool[j], pool[k], pool[l], pool[m], pool[q]];

                for (final phil in TravelPhilosophy.values) {
                  for (final ce in clients.entries) {
                    // 1) 以 normal 態找最佳排列
                    List<TravelMaterial?>? best;
                    var bestSat = -1;
                    for (var a = 0; a < 6; a++) {
                      for (var b = 0; b < 6; b++) {
                        if (b == a) continue;
                        for (var c = 0; c < 6; c++) {
                          if (c == a || c == b) continue;
                          for (final layout in [
                            [hand[a], hand[b], hand[c], null],
                            [null, hand[a], hand[b], hand[c]],
                          ]) {
                            final s = evaluate(layout, ce.value, phil, cam);
                            if (s > bestSat) {
                              bestSat = s;
                              best = layout;
                            }
                          }
                        }
                      }
                    }
                    final arrangement = best!;

                    // 2) 同一排列上評估三態 × 三組幅度
                    for (final cand in candidates.entries) {
                      final delta = cand.value;
                      List<TravelMaterial?> tier(int sign) => [
                            for (final s in arrangement)
                              s == null
                                  ? null
                                  : shift(s,
                                      sign * (s.isSpotlight ? delta.$2 : delta.$1))
                          ];
                      final p = evaluate(tier(1), ce.value, phil, cam);
                      final f = evaluate(tier(-1), ce.value, phil, cam);
                      acc['${ce.key}|${cand.key}']!.add(p, bestSat, f);
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // ignore: avoid_print
    print('\n=== 母體：$hands 手 × 5 哲學 × 2 客戶，相機 Lv.1，16-POI 池 ===');
    for (final c in clients.keys) {
      // ignore: avoid_print
      print('');
      for (final a in candidates.keys) {
        // ignore: avoid_print
        print(acc['$c|$a']!.report('[$c] $a'));
      }
    }
    expect(hands, 8008);
  }, timeout: const Timeout(Duration(minutes: 30)));
}
