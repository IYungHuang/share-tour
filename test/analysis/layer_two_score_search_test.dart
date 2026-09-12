// 一次性分析腳本（非驗收測試）：雙層結算的第二層分數落點。
//
// 第一層（滿意度／評等／佣金）不動一個字元，故本腳本完全不呼叫
// ClientReviewEngine —— 第二層是排列無關的純算術，只看「排入了哪些卡、
// 各自是什麼態」。
//
//   網紅「擴散觸及」 reach      = round(Σ(hype × tierFactor) × spotlightLadder[min(絕景數,4)])
//   社畜「CP 值」    valueIndex = round(Σ(hype × tierFactor) / max(Σcost, 500) × 1000)
//
// 母體：AC-A1-5.1 同基準的 16-POI 池，每手 6 張（C(16,6)=8008），
// 每手列舉全部合法提交（3 槽 C(6,3)=20 與 4 槽 C(6,4)=15，共 35 個組合）。
//
// 量四件事：
//   (a) 三態兩兩相異的比例 —— 應為 100%，用來釘住「不再有死區」
//   (b) 相對差 R = (L_perfect − L_failed) / L_normal 的分佈
//   (d) 只把一張卡由 normal 改 failed 的相對降幅
//   (c) 第二層折金幣的係數上界（Layer2 金幣 <= 佣金 15%）
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';

/// 企劃提案 §3.1 的 tierFactor 階梯：難度 -> (failed, normal, perfect)
const tierFactors = <String, (double, double, double)>{
  'tourist': (0.90, 1.00, 1.05),
  'photographer': (0.72, 1.00, 1.22),
  'decisiveMoment': (0.62, 1.00, 1.70),
};

/// 與 ClientReviewEngine.spotlightLadder 相同（D5）
const spotlightLadder = [0.70, 0.75, 0.80, 0.85, 1.00];

double factorOf((double, double, double) f, int tier) =>
    tier > 0 ? f.$3 : (tier == 0 ? f.$2 : f.$1);

/// 網紅第二層：擴散觸及
double reach(List<TravelMaterial> slotted, List<int> tiers,
    (double, double, double) f) {
  var sum = 0.0;
  var spotlights = 0;
  for (var i = 0; i < slotted.length; i++) {
    sum += slotted[i].hypeValue * factorOf(f, tiers[i]);
    if (slotted[i].isSpotlight) spotlights++;
  }
  return sum * spotlightLadder[spotlights > 4 ? 4 : spotlights];
}

/// 社畜第二層：CP 值
int cpFloor = 500;

double valueIndex(List<TravelMaterial> slotted, List<int> tiers,
    (double, double, double) f) {
  var sum = 0.0;
  var cost = 0;
  for (var i = 0; i < slotted.length; i++) {
    sum += slotted[i].hypeValue * factorOf(f, tiers[i]);
    cost += slotted[i].cost;
  }
  return sum / (cost < cpFloor ? cpFloor : cost) * 1000;
}

double median(List<double> xs) {
  xs.sort();
  return xs[xs.length ~/ 2];
}

double pct(List<double> xs, double p) {
  xs.sort();
  return xs[(xs.length * p).floor().clamp(0, xs.length - 1)];
}

void main() {
  test('layer two score distribution', () {
    const manifest = KyotoNightMapManifest();
    const resolver = KyotoPoiMaterialResolver();
    final pool = manifest.districtAttractions
        .map((a) => resolver.resolveMaterialFor(a.id)!)
        .take(16)
        .toList();

    // 每手 6 張的全部合法提交組合（3 槽 20 種 + 4 槽 15 種）
    final subsets = <List<int>>[];
    for (var mask = 0; mask < 64; mask++) {
      final bits = mask.toRadixString(2).split('').where((c) => c == '1').length;
      if (bits != 3 && bits != 4) continue;
      subsets.add([for (var i = 0; i < 6; i++) if (mask & (1 << i) != 0) i]);
    }

    final hands = <List<int>>[];
    for (var i = 0; i < 16; i++) {
      for (var j = i + 1; j < 16; j++) {
        for (var k = j + 1; k < 16; k++) {
          for (var l = k + 1; l < 16; l++) {
            for (var m = l + 1; m < 16; m++) {
              for (var q = m + 1; q < 16; q++) {
                hands.add([i, j, k, l, m, q]);
              }
            }
          }
        }
      }
    }

    // ignore: avoid_print
    print('\n=== 雙層結算：第二層分數落點 ===');
    // ignore: avoid_print
    print('母體：${hands.length} 手 × ${subsets.length} 種合法提交 = '
        '${hands.length * subsets.length} 個行程\n');

    for (final floor in [500, 1000, 1500, 2000, 2500]) {
      cpFloor = floor;
      final f = tierFactors['normal_probe'] ?? (0.72, 1.00, 1.22);
      final xs = <double>[];
      for (final hand in hands) {
        for (final sub in subsets) {
          final slotted = [for (final s in sub) pool[hand[s]]];
          xs.add(valueIndex(slotted, List.filled(slotted.length, 0), f));
        }
      }
      xs.sort();
      // ignore: avoid_print
      print('[社畜 CP 地板掃描] floor=$floor  med ${median(xs).toStringAsFixed(0)}'
          '  p99 ${pct(xs, 0.99).toStringAsFixed(0)}  max ${xs.last.toStringAsFixed(0)}');
    }
    // ignore: avoid_print
    print('');
    cpFloor = 500;

    for (final client in ['網紅 reach', '社畜 CP']) {
      for (final diff in tierFactors.entries) {
        final f = diff.value;
        var total = 0;
        var distinct3 = 0;
        final rels = <double>[];
        final singles = <double>[];
        final normals = <double>[];

        for (final hand in hands) {
          for (final sub in subsets) {
            final slotted = [for (final s in sub) pool[hand[s]]];
            final n = slotted.length;
            double score(List<int> tiers) => client == '網紅 reach'
                ? reach(slotted, tiers, f)
                : valueIndex(slotted, tiers, f);

            final p = score(List.filled(n, 1));
            final nm = score(List.filled(n, 0));
            final fl = score(List.filled(n, -1));
            total++;
            // 以 UI 實際呈現的整數位比較（round），而非浮點原值
            if ({p.round(), nm.round(), fl.round()}.length == 3) distinct3++;
            rels.add((p - fl) / nm);
            normals.add(nm);

            // (d) 只把第一張卡由 normal 改 failed
            final one = List.filled(n, 0)..[0] = -1;
            singles.add((nm - score(one)) / nm);
          }
        }

        normals.sort();
        // ignore: avoid_print
        print(
          '[$client] ${diff.key.padRight(15)} '
          '三態相異 ${(distinct3 / total * 100).toStringAsFixed(1)}%  '
          '相對差 R med ${(median(rels) * 100).toStringAsFixed(1)}% '
          '/ p5 ${(pct(rels, 0.05) * 100).toStringAsFixed(1)}%  '
          '單張降幅 med ${(median(singles) * 100).toStringAsFixed(1)}%  '
          'L2(normal) med ${median(normals).toStringAsFixed(0)} '
          '/ p99 ${pct(normals, 0.99).toStringAsFixed(0)} '
          '/ max ${normals.last.toStringAsFixed(0)}',
        );
      }
      // ignore: avoid_print
      print('');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
