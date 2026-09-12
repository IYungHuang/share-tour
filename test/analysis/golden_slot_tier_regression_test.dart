// 一次性分析腳本（非驗收測試）：量測三態是否會撐破 AC-A1-5.1 的黃金槽門檻。
//
// AC-A1-5.1：網紅、相機 Lv.1，「該手牌的所有最佳解都把最高熱度卡放黃昏槽」
// 的手牌比例須 <= 30%（現行以 16-POI 40,040 手牌窮舉，實測通過）。
//
// 疑慮：`perfect` 嚴格優於其他版本，且黃昏槽有 1.5x 倍率 —— 混入三態會加大
// 手牌內的熱度離散度，平手變少、固定最佳解變多，可能直接撐破 30%。
//
// 兩種情境：
//   A. 全域齊一態（AC-M5-9.2 的母體定義）—— 全部卡同時 perfect / normal / failed
//   B. 每張卡獨立取態（玩家實際經歷的牌組）—— 以固定種子抽樣
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';

/// v3 REQ-M5-02.5 的幅度表：難度 -> (一般卡, 絕景)
const amplitudes = <String, (int, int)>{
  'tourist ±2/±3': (2, 3),
  'photographer ±3/±5': (3, 5),
  'decisiveMoment ±4/±7': (4, 7),
};

TravelMaterial shifted(TravelMaterial m, int tier, (int, int) amp) {
  if (tier == 0) return m;
  final delta = (m.isSpotlight ? amp.$2 : amp.$1) * tier;
  final next = m.hypeValue + delta;
  return m.copyWith(hypeValue: next < 0 ? 0 : next);
}

/// 該手牌的所有最佳解是否都把最高熱度卡放在黃昏槽。
bool duskIsFixed(List<TravelMaterial> hand, TravelPhilosophy phil) {
  var maxHype = hand[0].hypeValue;
  for (final c in hand) {
    if (c.hypeValue > maxHype) maxHype = c.hypeValue;
  }

  var maxSat = -1;
  var allBestHaveMaxHypeInDusk = true;

  void consider(List<TravelMaterial?> slots, TravelMaterial dusk) {
    final sat = ClientReviewEngine.evaluate(
      client: ClientSpec.hypeInfluencer,
      stats: TimelineItinerary(
        slots: slots,
      ).calculateStats(philosophy: phil, cameraMultiplier: 1.5),
      philosophy: phil,
    ).satisfaction;
    final isDuskMaxHype = dusk.hypeValue == maxHype;
    if (sat > maxSat) {
      maxSat = sat;
      allBestHaveMaxHypeInDusk = isDuskMaxHype;
    } else if (sat == maxSat && !isDuskMaxHype) {
      allBestHaveMaxHypeInDusk = false;
    }
  }

  for (var a = 0; a < 6; a++) {
    for (var b = 0; b < 6; b++) {
      if (b == a) continue;
      for (var c = 0; c < 6; c++) {
        if (c == a || c == b) continue;
        consider([hand[a], hand[b], hand[c], null], hand[b]);
        consider([null, hand[a], hand[b], hand[c]], hand[b]);
        for (var d = 0; d < 6; d++) {
          if (d == a || d == b || d == c) continue;
          consider([hand[a], hand[b], hand[c], hand[d]], hand[c]);
        }
      }
    }
  }
  return allBestHaveMaxHypeInDusk;
}

void main() {
  test('golden slot ratio under three-tier pools', () {
    const manifest = KyotoNightMapManifest();
    const resolver = KyotoPoiMaterialResolver();
    final pool = manifest.districtAttractions
        .map((a) => resolver.resolveMaterialFor(a.id)!)
        .take(16)
        .toList();

    List<List<int>> handIndices() {
      final out = <List<int>>[];
      for (var i = 0; i < 16; i++) {
        for (var j = i + 1; j < 16; j++) {
          for (var k = j + 1; k < 16; k++) {
            for (var l = k + 1; l < 16; l++) {
              for (var m = l + 1; m < 16; m++) {
                for (var q = m + 1; q < 16; q++) {
                  out.add([i, j, k, l, m, q]);
                }
              }
            }
          }
        }
      }
      return out;
    }

    final hands = handIndices();
    // ignore: avoid_print
    print('\n=== 黃金槽固定最佳解比例（AC-A1-5.1 門檻 <= 30%）===');
    // ignore: avoid_print
    print('母體：${hands.length} 手 × 5 哲學，網紅，相機 Lv.1\n');

    // --- 情境 A：全域齊一態 ---
    for (final amp in amplitudes.entries) {
      for (final tier in [1, 0, -1]) {
        var fixed = 0;
        var total = 0;
        for (final idx in hands) {
          final hand = [
            for (final i in idx) shifted(pool[i], tier, amp.value),
          ];
          for (final phil in TravelPhilosophy.values) {
            total++;
            if (duskIsFixed(hand, phil)) fixed++;
          }
        }
        final label = tier == 1
            ? 'perfect'
            : tier == 0
            ? 'normal '
            : 'failed ';
        final pct = fixed / total * 100;
        // ignore: avoid_print
        print(
          '[齊一] ${amp.key.padRight(22)} $label  '
          '${pct.toStringAsFixed(2)}%  ${pct <= 30 ? 'PASS' : '*** FAIL ***'}',
        );
      }
    }

    // --- 情境 B：每張卡獨立取態，固定種子抽樣 ---
    // ignore: avoid_print
    print('');
    for (final amp in amplitudes.entries) {
      final rng = Random(20260912);
      var fixed = 0;
      var total = 0;
      for (final idx in hands) {
        final hand = [
          for (final i in idx)
            shifted(pool[i], rng.nextInt(3) - 1, amp.value),
        ];
        for (final phil in TravelPhilosophy.values) {
          total++;
          if (duskIsFixed(hand, phil)) fixed++;
        }
      }
      final pct = fixed / total * 100;
      // ignore: avoid_print
      print(
        '[混合] ${amp.key.padRight(22)}          '
        '${pct.toStringAsFixed(2)}%  ${pct <= 30 ? 'PASS' : '*** FAIL ***'}',
      );
    }
  },
      timeout: const Timeout(Duration(minutes: 30)),
      // 分析腳本，不是驗收條件。要重跑就拿掉這行。
      skip: '分析腳本，需要時手動解除 skip 重跑');
}
