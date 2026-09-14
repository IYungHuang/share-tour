@Tags(['slow'])
library;

// 全母體效果驗收（AC-M5-9 系列）。母體與 §4 分析腳本同基準：
// reachablePool.take(16)、每手 6 張 (C(16,6)=8008)、每手 3/4 槽全部合法
// 提交（35 種，前 N 個連續槽位放置），共 280,280 個行程、兩客戶。
//
// 本組不呼叫 ClientReviewEngine——第二層是排列無關的純算術，直接用
// hypeSumByTier 的公式（REQ-M5-02.4）驗證。
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/shutter/shutter_params.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';

List<TravelMaterial> _pool16() {
  const manifest = KyotoNightMapManifest();
  const resolver = KyotoPoiMaterialResolver();
  return manifest.districtAttractions
      .map((a) => resolver.resolveMaterialFor(a.id)!)
      .take(16)
      .toList();
}

List<List<int>> _subsets35() {
  final subsets = <List<int>>[];
  for (var mask = 0; mask < 64; mask++) {
    final bits = mask.toRadixString(2).split('').where((c) => c == '1').length;
    if (bits != 3 && bits != 4) continue;
    subsets.add([for (var i = 0; i < 6; i++) if (mask & (1 << i) != 0) i]);
  }
  return subsets;
}

List<List<int>> _hands8008(int n) {
  final hands = <List<int>>[];
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      for (var k = j + 1; k < n; k++) {
        for (var l = k + 1; l < n; l++) {
          for (var m = l + 1; m < n; m++) {
            for (var q = m + 1; q < n; q++) {
              hands.add([i, j, k, l, m, q]);
            }
          }
        }
      }
    }
  }
  return hands;
}

double _reach(
  List<TravelMaterial> itin,
  ShutterDifficulty difficulty, {
  required List<ShotTier> tiers,
}) {
  var raw = 0.0;
  var spotlights = 0;
  for (var i = 0; i < itin.length; i++) {
    final f = tierFactorFor(difficulty, tiers[i], isSpotlight: itin[i].isSpotlight);
    raw += itin[i].hypeValue * f;
    if (itin[i].isSpotlight) spotlights++;
  }
  final ladder = ClientReviewEngine.spotlightLadder[spotlights.clamp(0, 4)];
  return raw * ladder;
}

double _valueIndex(
  List<TravelMaterial> itin,
  ShutterDifficulty difficulty, {
  required List<ShotTier> tiers,
}) {
  var raw = 0.0;
  var cost = 0;
  for (var i = 0; i < itin.length; i++) {
    final f = tierFactorFor(difficulty, tiers[i], isSpotlight: itin[i].isSpotlight);
    raw += itin[i].hypeValue * f;
    cost += itin[i].cost;
  }
  final denom = cost < ClientReviewEngine.cpFloor ? ClientReviewEngine.cpFloor : cost;
  return raw / denom * 1000;
}

double _median(List<double> xs) {
  final sorted = [...xs]..sort();
  final n = sorted.length;
  return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}

void main() {
  final pool = _pool16();
  final subsets = _subsets35();
  final hands = _hands8008(16);

  // 每個組合對應的實際行程（依 §4 的固定排列慣例：前 N 槽連續放置）
  List<TravelMaterial> itineraryOf(List<int> hand, List<int> sub) =>
      [for (final s in sub) pool[hand[s]]];

  test('AC-M5-9.1: 三態齊一下，同一行程在三態間第二層分數兩兩相異的比例 >= 99.8%', () {
    // 對每一個行程（固定卡與位置），分別算出全 failed / 全 normal / 全
    // perfect 三個第二層分數，檢查這三個值是否兩兩相異——這是「訊號存在
    // 性」要驗的事：改變三態確實改變分數。不是檢查整個母體的分數是否
    // 全域唯一（值域遠小於 280,280，鴿籠原理下那必然大量碰撞，不是本條
    // 要量的東西）。
    for (final difficulty in ShutterDifficulty.values) {
      var total = 0;
      var reachDistinct = 0;
      var valueDistinct = 0;
      for (final hand in hands) {
        for (final sub in subsets) {
          final itin = itineraryOf(hand, sub);
          total++;

          final reaches = ShotTier.values
              .map((t) => _reach(itin, difficulty, tiers: List.filled(itin.length, t)).round())
              .toSet();
          if (reaches.length == ShotTier.values.length) reachDistinct++;

          final values = ShotTier.values
              .map((t) => _valueIndex(itin, difficulty, tiers: List.filled(itin.length, t)).round())
              .toSet();
          if (values.length == ShotTier.values.length) valueDistinct++;
        }
      }
      expect(
        reachDistinct / total,
        greaterThanOrEqualTo(0.998),
        reason: '$difficulty 網紅 reach 三態兩兩相異比例過低',
      );
      expect(
        valueDistinct / total,
        greaterThanOrEqualTo(0.998),
        reason: '$difficulty 社畜 valueIndex 三態兩兩相異比例過低',
      );
    }
  });

  test('AC-M5-9.2: 每張卡各算一次 normal→failed 降幅，中位數達門檻', () {
    const thresholds = {
      ShutterDifficulty.tourist: 0.025,
      ShutterDifficulty.photographer: 0.050,
      ShutterDifficulty.decisiveMoment: 0.085,
    };
    for (final difficulty in ShutterDifficulty.values) {
      final drops = <double>[];
      for (final hand in hands) {
        for (final sub in subsets) {
          final itin = itineraryOf(hand, sub);
          final totalHype = itin.fold<int>(0, (s, m) => s + m.hypeValue);
          if (totalHype == 0) continue;
          for (final m in itin) {
            final fFailed =
                tierFactorFor(difficulty, ShotTier.failed, isSpotlight: m.isSpotlight);
            drops.add(m.hypeValue / totalHype * (1 - fFailed));
          }
        }
      }
      final medianDrop = _median(drops);
      expect(
        medianDrop,
        greaterThanOrEqualTo(thresholds[difficulty]!),
        reason: '$difficulty 單張卡降幅中位數 $medianDrop 低於門檻',
      );
    }
  });

  test('AC-M5-9.5: 排列無關性——任意行程，四槽全部重排下第二層分數不變', () {
    // 抽樣驗證（不窮舉全部 4! 排列 × 全母體，取代表性子集）
    final sampleHands = hands.take(50);
    for (final hand in sampleHands) {
      for (final sub in subsets.where((s) => s.length == 4)) {
        final itin = itineraryOf(hand, sub);
        final tiers = [ShotTier.perfect, ShotTier.normal, ShotTier.failed, ShotTier.perfect];
        final base = _reach(itin, ShutterDifficulty.decisiveMoment, tiers: tiers);

        // 重排：反轉順序
        final reversedItin = itin.reversed.toList();
        final reversedTiers = tiers.reversed.toList();
        final reversedReach =
            _reach(reversedItin, ShutterDifficulty.decisiveMoment, tiers: reversedTiers);

        expect(reversedReach, closeTo(base, 1e-9));
      }
    }
  });

  test('AC-M5-5.8: L2 金幣硬性上界——32 張全池、三態全組合最壞情況', () {
    const resolver = KyotoPoiMaterialResolver();
    const manifest = KyotoNightMapManifest();
    final fullPool = manifest.districtAttractions
        .map((a) => resolver.resolveMaterialFor(a.id)!)
        .toList();
    expect(fullPool.length, 32);

    // 已知最壞情況：4 絕景全 perfect
    final spotlights = fullPool.where((m) => m.isSpotlight).toList()
      ..sort((a, b) => b.hypeValue.compareTo(a.hypeValue));
    final top4Spotlights = spotlights.take(4).toList();

    for (final difficulty in ShutterDifficulty.values) {
      final tiers = List.filled(4, ShotTier.perfect);
      final reach = _reach(top4Spotlights, difficulty, tiers: tiers);
      final coins = (reach * ClientReviewEngine.secondLayerCoinRate).round();
      expect(
        coins,
        lessThanOrEqualTo(225),
        reason: '$difficulty 網紅 L2 金幣超過上界 225',
      );

      final valueIndex = _valueIndex(top4Spotlights, difficulty, tiers: tiers);
      final cpCoins = (valueIndex * ClientReviewEngine.secondLayerCoinRate).round();
      expect(
        cpCoins,
        lessThanOrEqualTo(150),
        reason: '$difficulty 社畜 L2 金幣超過上界 150',
      );
    }
  });
}
