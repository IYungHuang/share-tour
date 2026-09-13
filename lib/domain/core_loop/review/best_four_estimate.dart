import '../models/shutter_difficulty.dart';
import '../models/travel_material.dart';
import '../shutter/shutter_params.dart';
import 'client_review_engine.dart';
import 'client_spec.dart';

/// 野外 HUD 即時預估（REQ-M5-11.5）：對現有素材窮舉 $\binom{n}{4}$ 子集，
/// 取該客戶第二層公式（reach／valueIndex，不含 c 折算）的真實 argmax。
///
/// **不是** $\text{hype} \times \text{tierFactor}$ 排序取前 4——那條近似對
/// 兩個客戶都不是 argmax：網紅端有 `spotlightLadder` 非線性加成，排序前 4
/// 若恰漏掉湊滿階梯的第 4 張絕景，真實最佳解會是另一組；社畜端分母是
/// $\max(\sum \text{cost}, 2000)$，排序法忽略成本，選到一張 hype 略高但
/// 成本極大的卡會讓真實 CP 遠低於排除該卡的組合（AC-M5-11.4b）。
///
/// $n \le 10$（腰包容量上限）故 $\binom{10}{4}=210$ 組，即時窮舉可算。
num bestFourSecondLayerEstimate(
  List<TravelMaterial> materials, {
  required ClientType clientType,
  required ShutterDifficulty difficulty,
}) {
  if (materials.isEmpty) return 0;
  if (materials.length <= 4) {
    return _scoreOf(materials, clientType: clientType, difficulty: difficulty);
  }
  num best = 0;
  for (final subset in _combinationsOfFour(materials)) {
    final score = _scoreOf(subset, clientType: clientType, difficulty: difficulty);
    if (score > best) best = score;
  }
  return best;
}

num _scoreOf(
  List<TravelMaterial> subset, {
  required ClientType clientType,
  required ShutterDifficulty difficulty,
}) {
  var raw = 0.0;
  var spotlights = 0;
  var cost = 0;
  for (final m in subset) {
    raw += m.hypeValue * tierFactorFor(difficulty, m.shotTier, isSpotlight: m.isSpotlight);
    cost += m.cost;
    if (m.isSpotlight) spotlights++;
  }
  if (clientType == ClientType.hypeInfluencer) {
    return raw * ClientReviewEngine.spotlightLadder[spotlights.clamp(0, 4)];
  }
  final denom = cost < ClientReviewEngine.cpFloor ? ClientReviewEngine.cpFloor : cost;
  return raw / denom * 1000;
}

Iterable<List<TravelMaterial>> _combinationsOfFour(List<TravelMaterial> pool) sync* {
  final n = pool.length;
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      for (var k = j + 1; k < n; k++) {
        for (var l = k + 1; l < n; l++) {
          yield [pool[i], pool[j], pool[k], pool[l]];
        }
      }
    }
  }
}
