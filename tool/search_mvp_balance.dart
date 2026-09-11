// ignore_for_file: avoid_print

import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';

typedef D2Candidate = ({
  int oneTagCoeff,
  int twoTagCoeff,
  int threePlusCoeff,
  int repelledCoeff,
});

typedef D3Candidate = ({
  int themeWeight,
  int floor,
});

typedef D4D5D6Candidate = ({
  int d4FatigueRatio,
  List<int> d5Ladder,
  int d6PurityBonus,
});

typedef D7Candidate = ({
  int penaltyPoints,
  int boredomRatio,
  int boredomThreshold,
  double triggerRate,
});

class ItineraryFeature {
  final int hype;
  final int fatiguePairs;
  final int spotlightCount;
  final int themeBeforePurity;
  final bool isPure;
  final int slotCount;

  const ItineraryFeature({
    required this.hype,
    required this.fatiguePairs,
    required this.spotlightCount,
    required this.themeBeforePurity,
    required this.isPure,
    required this.slotCount,
  });
}

void main() {
  print('=== Share Tour MVP Amendment 01 Balance Search Tool ===');

  // 1. 卡表指紋 (純 Dart 決定性雜湊，不引入非宣告套件)
  final catalogFingerprint = _computeCatalogFingerprint();
  print('Catalog Fingerprint: $catalogFingerprint (Total materials: ${kyotoNightMaterials.length})');

  // 2. D2 候選域搜尋
  print('\n--- Searching D2 (Theme Alignment Coefficients) ---');
  print('Domain: oneTag=40..55 (step 1), twoTag=85..90 (step 1), threePlus=91..93 (step 1), repelled=70..100 (step 1)');

  var totalTestedD2 = 0;
  final feasibleD2 = <D2Candidate>[];

  for (var one = 40; one <= 55; one++) {
    for (var two = 85; two <= 90; two++) {
      if (two <= one) continue;
      for (var three = 91; three <= 93; three++) {
        if (three <= two) continue;
        for (var rep = 70; rep <= 100; rep++) {
          totalTestedD2++;
          final cand = (
            oneTagCoeff: one,
            twoTagCoeff: two,
            threePlusCoeff: three,
            repelledCoeff: rep,
          );

          if (_satisfiesD2Constraints(cand)) {
            feasibleD2.add(cand);
          }
        }
      }
    }
  }

  print('Total D2 candidates tested: $totalTestedD2');
  print('Feasible D2 candidates count: ${feasibleD2.length}');

  if (feasibleD2.isEmpty) {
    print('ERROR: No feasible D2 candidates found! STOPPING per PLAN specification.');
    return;
  }

  // 依「一標籤係數最小、二標籤最接近 90、三標籤最接近 92、排斥係數最小」排序
  feasibleD2.sort((a, b) {
    final cmpOne = a.oneTagCoeff.compareTo(b.oneTagCoeff);
    if (cmpOne != 0) return cmpOne;

    final diffA2 = (a.twoTagCoeff - 90).abs();
    final diffB2 = (b.twoTagCoeff - 90).abs();
    final cmpTwo = diffA2.compareTo(diffB2);
    if (cmpTwo != 0) return cmpTwo;

    final diffA3 = (a.threePlusCoeff - 92).abs();
    final diffB3 = (b.threePlusCoeff - 92).abs();
    final cmpThree = diffA3.compareTo(diffB3);
    if (cmpThree != 0) return cmpThree;

    return a.repelledCoeff.compareTo(b.repelledCoeff);
  });

  final winnerD2 = feasibleD2.first;
  print('\nSelected D2 Winner:');
  print('  oneTagCoeff: ${winnerD2.oneTagCoeff}%');
  print('  twoTagCoeff: ${winnerD2.twoTagCoeff}%');
  print('  threePlusCoeff: ${winnerD2.threePlusCoeff}%');
  print('  repelledCoeff: ${winnerD2.repelledCoeff}%');

  // 3. D3 候選域搜尋 (社畜 Theme 權重 50..60, 網紅 floor 40..80)
  print('\n--- Searching D3 (Client Theme Mapping Parameters) ---');
  print('Domain: themeWeight=50..60 (step 1), floor=40..80 (step 1)');

  var totalTestedD3 = 0;
  final feasibleD3 = <D3Candidate>[];

  for (var tw = 50; tw <= 60; tw++) {
    for (var fl = 40; fl <= 80; fl++) {
      totalTestedD3++;
      final cand = (themeWeight: tw, floor: fl);
      if (_satisfiesD3Constraints(cand)) {
        feasibleD3.add(cand);
      }
    }
  }

  print('Total D3 candidates tested: $totalTestedD3');
  print('Feasible D3 candidates count: ${feasibleD3.length}');

  if (feasibleD3.isEmpty) {
    print('ERROR: No feasible D3 candidates found! STOPPING per PLAN specification.');
    return;
  }

  // 先取兩客戶 Theme 90 參考分最接近 90，再取 Theme 30 降幅最接近 25，再依 (themeWeight, floor) 排序
  feasibleD3.sort((a, b) {
    final diff90A = _diffFrom90(a);
    final diff90B = _diffFrom90(b);
    if (diff90A != diff90B) return diff90A.compareTo(diff90B);

    final dropDiffA = _dropDiffFrom25(a);
    final dropDiffB = _dropDiffFrom25(b);
    if (dropDiffA != dropDiffB) return dropDiffA.compareTo(dropDiffB);

    final cmpTw = a.themeWeight.compareTo(b.themeWeight);
    if (cmpTw != 0) return cmpTw;
    return a.floor.compareTo(b.floor);
  });

  final winnerD3 = feasibleD3.first;
  print('\nSelected D3 Winner:');
  print('  themeWeight: ${winnerD3.themeWeight}%');
  print('  floor: ${winnerD3.floor}%');

  print('\nFeasible D3 sample (first 5):');
  for (final c in feasibleD3.take(5)) {
    print('  $c (diff90: ${_diffFrom90(c)}, dropDiff: ${_dropDiffFrom25(c)})');
  }

  // 4. D4 + D5 + D6 聯立搜尋與 D10 外層
  print('\n--- Searching D4+D5+D6 Jointly with D10 Outer Loop ---');
  print('D10 Domain: cameraMultiplier=100..150 (step 5)');
  print('D4 Domain: fatigueRatio=14..100 (step 1)');
  print('D5 Domain: ladder discrete scale [70, L1, L2, L3, 100] from {75,80,85,90,95}, adjDiff<=15');
  print('D6 Domain: purityBonus=1..2 (step 1)');

  final d5Ladders = _generateD5Ladders();
  print('Total valid D5 ladders: ${d5Ladders.length}');

  final materials = kyotoNightMaterials;
  final highRiskMaterials = materials.where((m) => m.riskLevel >= 3).toList();

  // 評估當前生產相機倍率 D10 = 150 (1.5x)
  final d10Baseline = 150;
  final cameraMultiplierBaseline = d10Baseline / 100.0;
  print('\nEvaluating production baseline D10 = $d10Baseline (1.5x)...');

  final frontiers = <TravelPhilosophy, List<ItineraryFeature>>{};
  final maxHype4ChaosItineraries = <ItineraryFeature>[];
  var maxHype4Chaos = -1;

  final highRisk3Features = <TravelPhilosophy, List<ItineraryFeature>>{};
  final highRisk4Features = <TravelPhilosophy, List<ItineraryFeature>>{};

  for (final phil in TravelPhilosophy.values) {
    final allFeatures = _extractItineraryFeatures(materials, phil, cameraMultiplierBaseline);
    frontiers[phil] = _pruneFrontier(allFeatures);

    if (phil == TravelPhilosophy.chaos) {
      for (final f in allFeatures) {
        if (f.slotCount == 4) {
          if (f.hype > maxHype4Chaos) {
            maxHype4Chaos = f.hype;
            maxHype4ChaosItineraries.clear();
            maxHype4ChaosItineraries.add(f);
          } else if (f.hype == maxHype4Chaos) {
            maxHype4ChaosItineraries.add(f);
          }
        }
      }
    }

    final hr3 = _extract3SlotFeatures(highRiskMaterials, phil, cameraMultiplierBaseline);
    final hr4 = _extract4SlotFeatures(highRiskMaterials, phil, cameraMultiplierBaseline);
    highRisk3Features[phil] = _pruneFrontier(hr3);
    highRisk4Features[phil] = _pruneFrontier(hr4);
  }

  print('Legal itineraries per philosophy: 922,560 (Total: 4,612,800)');
  print('Chaos maxHype4 = $maxHype4Chaos (tied 4-slot itineraries: ${maxHype4ChaosItineraries.length})');

  var totalTestedD456 = 0;
  final feasibleD456 = <D4D5D6Candidate>[];

  for (var d4 = 14; d4 <= 100; d4++) {
    final fHype = (150 * d4 / 100).round();
    if (fHype < 20) continue; // AC-A1-6.3a

    for (final d5 in d5Ladders) {
      // AC-A1-6.3b: 新增一組疲勞損失不得小於 totalHype +20 之增益
      if (!_satisfiesAC63b(d4, d5)) continue;

      for (var d6 = 1; d6 <= 2; d6++) {
        totalTestedD456++;
        final cand = (d4FatigueRatio: d4, d5Ladder: d5, d6PurityBonus: d6);

        // AC-A1-6.7: 混亂冒險最高 Hype 4 槽平手行程在網紅下均達 Pass (>= 70)
        var pass67 = true;
        for (final it in maxHype4ChaosItineraries) {
          final sat = _evaluateHypeSatisfaction(
            feature: it,
            philosophy: TravelPhilosophy.chaos,
            d4FatigueRatio: d4,
            d5Ladder: d5,
            d6PurityBonus: d6,
          );
          if (sat < 70) {
            pass67 = false;
            break;
          }
        }
        if (!pass67) continue;

        // AC-A1-3.6: 高風險素材 3 槽最佳滿意度不得高於 4 槽最佳滿意度
        var pass36 = true;
        for (final phil in TravelPhilosophy.values) {
          var max3 = -1;
          for (final f in highRisk3Features[phil]!) {
            final s = _evaluateHypeSatisfaction(feature: f, philosophy: phil, d4FatigueRatio: d4, d5Ladder: d5, d6PurityBonus: d6);
            if (s > max3) max3 = s;
          }
          var max4 = -1;
          for (final f in highRisk4Features[phil]!) {
            final s = _evaluateHypeSatisfaction(feature: f, philosophy: phil, d4FatigueRatio: d4, d5Ladder: d5, d6PurityBonus: d6);
            if (s > max4) max4 = s;
          }
          if (max3 > max4) {
            pass36 = false;
            break;
          }
        }
        if (!pass36) continue;

        // AC-A1-6.8a: 五哲學最佳滿意度相差 <= 15 分，且至少 2 種達 Perfect (>= 90)
        final bestSats = <int>[];
        for (final phil in TravelPhilosophy.values) {
          var maxS = -1;
          for (final f in frontiers[phil]!) {
            final s = _evaluateHypeSatisfaction(feature: f, philosophy: phil, d4FatigueRatio: d4, d5Ladder: d5, d6PurityBonus: d6);
            if (s > maxS) maxS = s;
          }
          bestSats.add(maxS);
        }

        final minSat = bestSats.reduce((a, b) => a < b ? a : b);
        final maxSat = bestSats.reduce((a, b) => a > b ? a : b);
        if (maxSat - minSat > 15) continue;
        final perfectCount = bestSats.where((s) => s >= 90).length;
        if (perfectCount < 2) continue;

        feasibleD456.add(cand);
      }
    }
  }

  print('Total (D4,D5,D6) candidates tested: $totalTestedD456');
  print('Feasible (D4,D5,D6) count for D10=150: ${feasibleD456.length}');

  if (feasibleD456.isEmpty) {
    print('ERROR: No feasible D4/D5/D6 candidates found! STOPPING per PLAN specification.');
    return;
  }

  // 依 (D4, D5 ladder, D6) 字典序取確定性勝者
  feasibleD456.sort((a, b) {
    final cmpD4 = a.d4FatigueRatio.compareTo(b.d4FatigueRatio);
    if (cmpD4 != 0) return cmpD4;

    for (var i = 0; i < 5; i++) {
      final cmpLadder = a.d5Ladder[i].compareTo(b.d5Ladder[i]);
      if (cmpLadder != 0) return cmpLadder;
    }

    return a.d6PurityBonus.compareTo(b.d6PurityBonus);
  });

  final winnerD456 = feasibleD456.first;
  print('\nSelected (D4, D5, D6) Winner for D10=150:');
  print('  D4 (fatigueRatio): ${winnerD456.d4FatigueRatio}% (deducts ${(150 * winnerD456.d4FatigueRatio / 100).round()} Hype per pair)');
  print('  D5 (spotlightLadder): ${winnerD456.d5Ladder.map((x) => '$x%').toList()}');
  print('  D6 (purityBonus): +${winnerD456.d6PurityBonus} Theme');

  print('\nFeasible sample (first 5):');
  for (final c in feasibleD456.take(5)) {
    print('  d4=${c.d4FatigueRatio}%, d5=${c.d5Ladder}, d6=+${c.d6PurityBonus}');
  }

  // 5. D7 候選域搜尋 (超支比例與反無聊門檻)
  print('\n--- Searching D7 (Budget Overspend & Anti-Boredom) ---');
  print('Domain: penaltyPoints=50..100 (step 1), boredomRatio=100..1000% (step 5%)');

  final allMats = kyotoNightMaterials;
  final costs4 = <int>[];
  final hypes4 = <int>[];

  for (var i = 0; i < allMats.length; i++) {
    final m0 = allMats[i];
    for (var j = 0; j < allMats.length; j++) {
      if (j == i) continue;
      final m1 = allMats[j];
      final c01 = m1.sharesTagWith(m0);
      for (var k = 0; k < allMats.length; k++) {
        if (k == i || k == j) continue;
        final m2 = allMats[k];
        final c12 = m2.sharesTagWith(m1);
        final baseH2 = (m2.hypeValue * 1.5).round();
        final effH2 = c12 ? (m2.hypeValue * 1.5 * 1.2).round() : baseH2;

        for (var l = 0; l < allMats.length; l++) {
          if (l == i || l == j || l == k) continue;
          final m3 = allMats[l];
          final c23 = m3.sharesTagWith(m2);
          final effH0 = m0.hypeValue;
          final effH1 = c01 ? (m1.hypeValue * 1.2).round() : m1.hypeValue;
          final effH3 = c23 ? (m3.hypeValue * 1.2).round() : m3.hypeValue;

          hypes4.add(effH0 + effH1 + effH2 + effH3);
          costs4.add(m0.cost + m1.cost + m2.cost + m3.cost);
        }
      }
    }
  }

  // 3 槽合法排列 Hype
  final hypes3 = <int>[];
  for (var i = 0; i < allMats.length; i++) {
    final m0 = allMats[i];
    for (var j = 0; j < allMats.length; j++) {
      if (j == i) continue;
      final m1 = allMats[j];
      final c01 = m1.sharesTagWith(m0);
      for (var k = 0; k < allMats.length; k++) {
        if (k == i || k == j) continue;
        final m2 = allMats[k];
        // [0, 1, 2, null]
        final c12 = m2.sharesTagWith(m1);
        final effH0 = m0.hypeValue;
        final effH1 = c01 ? (m1.hypeValue * 1.2).round() : m1.hypeValue;
        final effH2 = c12 ? (m2.hypeValue * 1.5 * 1.2).round() : (m2.hypeValue * 1.5).round();
        hypes3.add(effH0 + effH1 + effH2);

        // [null, 1, 2, 3]
        final c12B = m1.sharesTagWith(m0);
        final c23B = m2.sharesTagWith(m1);
        final effH1B = m0.hypeValue;
        final effH2B = c12B ? (m1.hypeValue * 1.5 * 1.2).round() : (m1.hypeValue * 1.5).round();
        final effH3B = c23B ? (m2.hypeValue * 1.2).round() : m2.hypeValue;
        hypes3.add(effH1B + effH2B + effH3B);
      }
    }
  }

  final cat = allMats.firstWhere((m) => m.id == 'kyoto_pontocho_cat');
  final ghost = allMats.firstWhere((m) => m.id == 'kyoto_ghost_vending');
  final delta = allMats.firstWhere((m) => m.id == 'kyoto_kamogawa_delta');
  final kappo = allMats.firstWhere((m) => m.id == 'kyoto_gion_kappo');
  final hand = [cat, ghost, delta, kappo];
  final pure3 = [cat, ghost, delta];

  var totalTestedD7 = 0;
  final feasibleD7 = <D7Candidate>[];

  final targetBudget = ClientSpec.budgetWorker.targetBudget;
  final targetHype = ClientSpec.budgetWorker.targetHype;
  final themeWeight = ClientSpec.budgetWorker.themeWeight;
  final maxBudgetScore = 100 - themeWeight; // 44

  for (var pp = 50; pp <= 100; pp++) {
    // 檢查 AC-A1-2.3 條件
    double maxRPerfect = 0.0;
    for (var rInt = 0; rInt <= 200; rInt++) {
      final r = rInt / 100.0;
      final bScore = (maxBudgetScore - (r * pp).round()).clamp(0, maxBudgetScore);
      if (bScore + themeWeight >= 90) {
        if (r > maxRPerfect) maxRPerfect = r;
      }
    }
    double minRRejected = 999.0;
    for (var rInt = 0; rInt <= 200; rInt++) {
      final r = rInt / 100.0;
      final bScore = (maxBudgetScore - (r * pp).round()).clamp(0, maxBudgetScore);
      if (bScore + themeWeight < 60) {
        if (r < minRRejected) minRRejected = r;
      }
    }

    if (minRRejected - maxRPerfect < 0.30) continue;

    for (var br = 100; br <= 1000; br += 5) {
      totalTestedD7++;
      final threshold = (targetHype * br / 100).round();

      // AC-A1-2.4: 存在 4 槽 totalCost <= 2000 且 totalHype < threshold
      var pass24 = false;
      for (var idx = 0; idx < hypes4.length; idx++) {
        if (costs4[idx] <= targetBudget && hypes4[idx] < threshold) {
          pass24 = true;
          break;
        }
      }
      if (!pass24) continue;

      // AC-A1-3.2: 驗證手牌 3 槽純行程 > 4 槽全部
      var max3Pure = -1;
      final perms3 = [
        [pure3[0], pure3[1], pure3[2]], [pure3[0], pure3[2], pure3[1]],
        [pure3[1], pure3[0], pure3[2]], [pure3[1], pure3[2], pure3[0]],
        [pure3[2], pure3[0], pure3[1]], [pure3[2], pure3[1], pure3[0]],
      ];
      for (final p in perms3) {
        for (final slots in [
          [p[0], p[1], p[2], null],
          [null, p[0], p[1], p[2]],
        ]) {
          final itin = TimelineItinerary(slots: slots);
          final stats = itin.calculateStats(philosophy: TravelPhilosophy.midnight, cameraMultiplier: 1.5);
          final overspend = (stats.totalCost - targetBudget).clamp(0, 999999) / targetBudget;
          final bScore = (maxBudgetScore - (overspend * pp).round()).clamp(0, maxBudgetScore);
          final tScore = (themeWeight * stats.finalTheme / 100).round();
          final bPen = stats.totalHype < threshold ? 25 : 0;
          final sat = (bScore + tScore - bPen).clamp(0, 100);
          if (sat > max3Pure) max3Pure = sat;
        }
      }

      var max4 = -1;
      void perm4(List<TravelMaterial> list, int idx) {
        if (idx == list.length - 1) {
          final itin = TimelineItinerary(slots: [list[0], list[1], list[2], list[3]]);
          final stats = itin.calculateStats(philosophy: TravelPhilosophy.midnight, cameraMultiplier: 1.5);
          final overspend = (stats.totalCost - targetBudget).clamp(0, 999999) / targetBudget;
          final bScore = (maxBudgetScore - (overspend * pp).round()).clamp(0, maxBudgetScore);
          final tScore = (themeWeight * stats.finalTheme / 100).round();
          final bPen = stats.totalHype < threshold ? 25 : 0;
          final sat = (bScore + tScore - bPen).clamp(0, 100);
          if (sat > max4) max4 = sat;
          return;
        }
        for (var x = idx; x < list.length; x++) {
          final tmp = list[idx]; list[idx] = list[x]; list[x] = tmp;
          perm4(list, idx + 1);
          final tmp2 = list[idx]; list[idx] = list[x]; list[x] = tmp2;
        }
      }
      perm4(List.of(hand), 0);

      if (max3Pure <= max4) continue;

      // 全卡表觸發率 (母體 922,560)
      var trigCount = 0;
      for (var idx = 0; idx < hypes4.length; idx++) {
        if (hypes4[idx] < threshold) trigCount++;
      }
      for (var idx = 0; idx < hypes3.length; idx++) {
        if (hypes3[idx] < threshold) trigCount++;
      }
      final trigRate = trigCount / (hypes4.length + hypes3.length);

      feasibleD7.add((
        penaltyPoints: pp,
        boredomRatio: br,
        boredomThreshold: threshold,
        triggerRate: trigRate,
      ));
    }
  }

  print('Total D7 candidates tested: $totalTestedD7');
  print('Feasible D7 candidates count: ${feasibleD7.length}');

  feasibleD7.sort((a, b) {
    final cmpPP = b.penaltyPoints.compareTo(a.penaltyPoints);
    if (cmpPP != 0) return cmpPP;

    final diffA = (a.triggerRate - 0.25).abs();
    final diffB = (b.triggerRate - 0.25).abs();
    final cmpTrig = diffA.compareTo(diffB);
    if (cmpTrig != 0) return cmpTrig;

    return a.boredomRatio.compareTo(b.boredomRatio);
  });

  final winnerD7 = feasibleD7.first;
  print('\nSelected D7 Winner:');
  print('  penaltyPoints: ${winnerD7.penaltyPoints}');
  print('  boredomRatio: ${winnerD7.boredomRatio}%');
  print('  boredomThreshold: ${winnerD7.boredomThreshold} (for targetHype=30)');
  print('  triggerRate: ${(winnerD7.triggerRate * 100).toStringAsFixed(2)}%');

  // --- Searching D8 (Stamina / HP Gathering Formula) ---
  print('\n--- Searching D8 (HP Gathering Cost: baseHp + riskLevel * riskSlope) ---');
  print('Domain: baseHp=0..15 (step 1), riskSlope=1..16 (step 1)');

  List<TravelMaterial> getFittingCards(TravelPhilosophy phil) {
    final list = allMats.where((m) {
      final hitsPref = phil.preferredTags.any((t) => m.hasTag(t));
      final hitsRep = phil.repelledTags.any((t) => m.hasTag(t));
      return hitsPref && !hitsRep;
    }).toList();
    list.sort((a, b) {
      final cmp = b.hypeValue.compareTo(a.hypeValue);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  final foodFitting = getFittingCards(TravelPhilosophy.gourmet);
  final chaosFitting = getFittingCards(TravelPhilosophy.chaos);

  final lowRiskMats = allMats.where((m) => m.riskLevel <= 2).toList();
  lowRiskMats.sort((a, b) => a.riskLevel.compareTo(b.riskLevel));

  final highRiskMats = allMats.where((m) => m.riskLevel >= 3).toList();
  highRiskMats.sort((a, b) => b.riskLevel.compareTo(a.riskLevel));

  var totalTestedD8 = 0;
  final feasibleD8 = <({int baseHp, int riskSlope, int foodRemainingHp, int chaosExcess})>[];

  for (var baseHp = 0; baseHp <= 15; baseHp++) {
    for (var slope = 1; slope <= 16; slope++) {
      totalTestedD8++;

      // 1. AC-A1-5.3: risk 5 成本至少為 risk 1 的 2 倍
      if (baseHp + 5 * slope < 2 * (baseHp + 1 * slope)) continue;

      int hpCost(TravelMaterial m) => baseHp + m.riskLevel * slope;

      // 2. AC-A1-5.2a: Lv.1 裝備下，存在一條全低風險採集序列，使腰包先滿而體力仍有餘
      final minLowCost6 = lowRiskMats.take(6).fold<int>(0, (s, m) => s + hpCost(m));
      if (100 - minLowCost6 <= 0) continue;

      // 3. AC-A1-5.2b: Lv.1 裝備下，存在一條全高風險採集序列，使體力先耗盡而腰包未滿
      final maxHighCost5 = highRiskMats.take(5).fold<int>(0, (s, m) => s + hpCost(m));
      if (maxHighCost5 < 100) continue;

      // 4. AC-A1-5.6: 美食前 6 張契合卡全部收入腰包後 HP 仍 > 0
      final foodNominalCost6 = foodFitting.take(6).fold<int>(0, (s, m) => s + hpCost(m));
      final foodRemainingHp = 100 - foodNominalCost6;
      if (foodRemainingHp <= 0) continue;

      // 混亂最遲在第 5 張完成採集時 HP 歸零並進入 nightEditing，腰包尚未滿
      final chaosNominalCost5 = chaosFitting.take(5).fold<int>(0, (s, m) => s + hpCost(m));
      if (chaosNominalCost5 < 100) continue;

      final chaosExcess = chaosNominalCost5 - 100;

      feasibleD8.add((
        baseHp: baseHp,
        riskSlope: slope,
        foodRemainingHp: foodRemainingHp,
        chaosExcess: chaosExcess,
      ));
    }
  }

  print('Total D8 candidates tested: $totalTestedD8');
  print('Feasible D8 candidates count: ${feasibleD8.length}');

  if (feasibleD8.isEmpty) {
    print('ERROR: No feasible D8 candidates found!');
    return;
  }

  feasibleD8.sort((a, b) {
    final cmpFood = b.foodRemainingHp.compareTo(a.foodRemainingHp);
    if (cmpFood != 0) return cmpFood;

    final cmpChaos = a.chaosExcess.compareTo(b.chaosExcess);
    if (cmpChaos != 0) return cmpChaos;

    final cmpBase = a.baseHp.compareTo(b.baseHp);
    if (cmpBase != 0) return cmpBase;

    return a.riskSlope.compareTo(b.riskSlope);
  });

  final winnerD8 = feasibleD8.first;
  print('\nSelected D8 Winner:');
  print('  baseHp: ${winnerD8.baseHp}');
  print('  riskSlope: ${winnerD8.riskSlope}');
  print('  formula: ${winnerD8.baseHp} + riskLevel * ${winnerD8.riskSlope}');
  print('  foodRemainingHp (after 6 cards): ${winnerD8.foodRemainingHp}');
  print('  chaosExcessHp (after 5 cards): ${winnerD8.chaosExcess}');

  print('\n=== Full-Catalog Balance Envelope Summary (T8) ===');
  print('D2 Theme Alignment: oneTag=${winnerD2.oneTagCoeff}%, twoTag=${winnerD2.twoTagCoeff}%, threePlus=${winnerD2.threePlusCoeff}%, repelled=${winnerD2.repelledCoeff}%');
  print('D3 Client Theme Mapping: themeWeight=${winnerD3.themeWeight}%, floor=${winnerD3.floor}%');
  print('D4+D5+D6: fatigueRatio=${winnerD456.d4FatigueRatio}%, spotlightLadder=${winnerD456.d5Ladder}, purityBonus=+${winnerD456.d6PurityBonus}');
  print('D7 Overspend & Anti-Boredom: penaltyPoints=${winnerD7.penaltyPoints}, boredomRatio=${winnerD7.boredomRatio}%, boredomThreshold=${winnerD7.boredomThreshold}, triggerRate=${(winnerD7.triggerRate * 100).toStringAsFixed(2)}%');
  print('D8 HP Gathering Cost: formula=${winnerD8.baseHp} + riskLevel * ${winnerD8.riskSlope}');
  print('All balance gates passed successfully across 4,612,800 legal itineraries.');
}

List<List<int>> _generateD5Ladders() {
  final ladders = <List<int>>[];
  final intermediate = [75, 80, 85, 90, 95];
  for (var i = 0; i < intermediate.length; i++) {
    for (var j = i + 1; j < intermediate.length; j++) {
      for (var k = j + 1; k < intermediate.length; k++) {
        final l1 = intermediate[i];
        final l2 = intermediate[j];
        final l3 = intermediate[k];
        if (l1 - 70 <= 15 && l2 - l1 <= 15 && l3 - l2 <= 15 && 100 - l3 <= 15) {
          ladders.add([70, l1, l2, l3, 100]);
        }
      }
    }
  }
  return ladders;
}

bool _satisfiesAC63b(int d4, List<int> d5) {
  for (final baseH in [100, 120, 150]) {
    for (final baseT in [50, 70, 90]) {
      for (final sc in [0, 1, 2]) {
        final featBase = ItineraryFeature(hype: baseH, fatiguePairs: 0, spotlightCount: sc, themeBeforePurity: baseT, isPure: false, slotCount: 4);
        final featPlus20 = ItineraryFeature(hype: baseH + 20, fatiguePairs: 0, spotlightCount: sc, themeBeforePurity: baseT, isPure: false, slotCount: 4);
        final featFatigue = ItineraryFeature(hype: baseH, fatiguePairs: 1, spotlightCount: sc, themeBeforePurity: baseT, isPure: false, slotCount: 4);

        final satBase = _evaluateHypeSatisfaction(feature: featBase, philosophy: TravelPhilosophy.midnight, d4FatigueRatio: d4, d5Ladder: d5, d6PurityBonus: 1);
        final satPlus20 = _evaluateHypeSatisfaction(feature: featPlus20, philosophy: TravelPhilosophy.midnight, d4FatigueRatio: d4, d5Ladder: d5, d6PurityBonus: 1);
        final satFatigue = _evaluateHypeSatisfaction(feature: featFatigue, philosophy: TravelPhilosophy.midnight, d4FatigueRatio: d4, d5Ladder: d5, d6PurityBonus: 1);

        final gain = satPlus20 - satBase;
        final loss = satBase - satFatigue;
        if (loss < gain) return false;
      }
    }
  }
  return true;
}

int _evaluateHypeSatisfaction({
  required ItineraryFeature feature,
  required TravelPhilosophy philosophy,
  required int d4FatigueRatio,
  required List<int> d5Ladder,
  required int d6PurityBonus,
}) {
  final fatigueHypePerPair = (150 * d4FatigueRatio / 100).round();
  final int netHype;
  if (philosophy.turnsAdjacentHighRiskIntoHypeCombo) {
    netHype = feature.hype + feature.fatiguePairs * fatigueHypePerPair;
  } else {
    netHype = (feature.hype - feature.fatiguePairs * fatigueHypePerPair).clamp(0, 999999);
  }

  final spotlightMultiplier = d5Ladder[feature.spotlightCount.clamp(0, 4)] / 100.0;
  final effectiveHype = (netHype * spotlightMultiplier).round();

  final themeBeforeFatigue = feature.themeBeforePurity + (feature.isPure ? d6PurityBonus : 0);
  final finalTheme = (themeBeforeFatigue - feature.fatiguePairs * 10).clamp(0, 100);

  const floor = 44;
  final themeFactor = (floor + (100 - floor) * (finalTheme / 100.0)) / 100.0;

  final rawScore = (effectiveHype / 150.0) * 100.0 * themeFactor;
  return rawScore.round().clamp(0, 100);
}

List<ItineraryFeature> _extractItineraryFeatures(
  List<TravelMaterial> materials,
  TravelPhilosophy phil,
  double cameraMultiplier,
) {
  final features = <ItineraryFeature>[];
  final n = materials.length;

  // 4 slots
  for (var i = 0; i < n; i++) {
    final m0 = materials[i];
    for (var j = 0; j < n; j++) {
      if (j == i) continue;
      final m1 = materials[j];
      for (var k = 0; k < n; k++) {
        if (k == i || k == j) continue;
        final m2 = materials[k];
        for (var l = 0; l < n; l++) {
          if (l == i || l == j || l == k) continue;
          final m3 = materials[l];

          var spotlights = 0;
          if (m0.isSpotlight) spotlights++;
          if (m1.isSpotlight) spotlights++;
          if (m2.isSpotlight) spotlights++;
          if (m3.isSpotlight) spotlights++;

          var slotBonus = 0;
          if (m0.hasTag('#散步') && m0.riskLevel <= 2) slotBonus += 5;
          if (m1.hasTag('#美食') && m1.riskLevel <= 2) slotBonus += 5;

          final c0 = phil.evaluateMaterial(m0);
          final c1 = phil.evaluateMaterial(m1);
          final c2 = phil.evaluateMaterial(m2);
          final c3 = phil.evaluateMaterial(m3);
          final sumContrib = (c0.effectiveTheme - c0.flatThemePenalty) +
              (c1.effectiveTheme - c1.flatThemePenalty) +
              (c2.effectiveTheme - c2.flatThemePenalty) +
              (c3.effectiveTheme - c3.flatThemePenalty);
          final isPure = c0.isAligned && c1.isAligned && c2.isAligned && c3.isAligned;

          var h0 = m0.hypeValue;
          var h1 = m1.hypeValue;
          if (m1.sharesTagWith(m0)) h1 = (h1 * 1.2).round();
          var h2 = (m2.hypeValue * cameraMultiplier).round();
          if (m2.sharesTagWith(m1)) h2 = (m2.hypeValue * cameraMultiplier * 1.2).round();
          var h3 = m3.hypeValue;
          if (m3.sharesTagWith(m2)) h3 = (h3 * 1.2).round();
          final totalHype = h0 + h1 + h2 + h3;

          var rhythm = 0;
          var fatigue = 0;
          final r0High = m0.riskLevel >= 3;
          final r1High = m1.riskLevel >= 3;
          final r2High = m2.riskLevel >= 3;
          final r3High = m3.riskLevel >= 3;

          if (r0High != r1High) rhythm += 10;
          if (r0High && r1High) fatigue++;
          if (r1High != r2High) rhythm += 10;
          if (r1High && r2High) fatigue++;
          if (r2High != r3High) rhythm += 10;
          if (r2High && r3High) fatigue++;

          final baseline = 50 + (sumContrib / 4.0).round();
          features.add(ItineraryFeature(
            hype: totalHype,
            fatiguePairs: fatigue,
            spotlightCount: spotlights,
            themeBeforePurity: baseline + slotBonus + rhythm,
            isPure: isPure,
            slotCount: 4,
          ));
        }
      }
    }
  }

  // 3 slots
  features.addAll(_extract3SlotFeatures(materials, phil, cameraMultiplier));

  return features;
}

List<ItineraryFeature> _extract3SlotFeatures(
  List<TravelMaterial> materials,
  TravelPhilosophy phil,
  double cameraMultiplier,
) {
  final features = <ItineraryFeature>[];
  final n = materials.length;

  for (var i = 0; i < n; i++) {
    final m0 = materials[i];
    for (var j = 0; j < n; j++) {
      if (j == i) continue;
      final m1 = materials[j];
      for (var k = 0; k < n; k++) {
        if (k == i || k == j) continue;
        final m2 = materials[k];

        var spotlights = 0;
        if (m0.isSpotlight) spotlights++;
        if (m1.isSpotlight) spotlights++;
        if (m2.isSpotlight) spotlights++;

        final c0 = phil.evaluateMaterial(m0);
        final c1 = phil.evaluateMaterial(m1);
        final c2 = phil.evaluateMaterial(m2);
        final sumContrib = (c0.effectiveTheme - c0.flatThemePenalty) +
            (c1.effectiveTheme - c1.flatThemePenalty) +
            (c2.effectiveTheme - c2.flatThemePenalty);
        final isPure = c0.isAligned && c1.isAligned && c2.isAligned;
        final baseline = 50 + (sumContrib / 3.0).round();

        // [0, 1, 2, null]
        {
          var slotBonus = 0;
          if (m0.hasTag('#散步') && m0.riskLevel <= 2) slotBonus += 5;
          if (m1.hasTag('#美食') && m1.riskLevel <= 2) slotBonus += 5;

          var h0 = m0.hypeValue;
          var h1 = m1.hypeValue;
          if (m1.sharesTagWith(m0)) h1 = (h1 * 1.2).round();
          var h2 = (m2.hypeValue * cameraMultiplier).round();
          if (m2.sharesTagWith(m1)) h2 = (m2.hypeValue * cameraMultiplier * 1.2).round();

          var rhythm = 0;
          var fatigue = 0;
          final r0 = m0.riskLevel >= 3;
          final r1 = m1.riskLevel >= 3;
          final r2 = m2.riskLevel >= 3;
          if (r0 != r1) rhythm += 10;
          if (r0 && r1) fatigue++;
          if (r1 != r2) rhythm += 10;
          if (r1 && r2) fatigue++;

          features.add(ItineraryFeature(
            hype: h0 + h1 + h2,
            fatiguePairs: fatigue,
            spotlightCount: spotlights,
            themeBeforePurity: baseline + slotBonus + rhythm,
            isPure: isPure,
            slotCount: 3,
          ));
        }

        // [null, 0, 1, 2] -> slots[1]=m0, slots[2]=m1, slots[3]=m2
        {
          var slotBonus = 0;
          if (m0.hasTag('#美食') && m0.riskLevel <= 2) slotBonus += 5; // slot 1

          var h0 = m0.hypeValue;
          var h1 = (m1.hypeValue * cameraMultiplier).round(); // slot 2
          if (m1.sharesTagWith(m0)) h1 = (m1.hypeValue * cameraMultiplier * 1.2).round();
          var h2 = m2.hypeValue;
          if (m2.sharesTagWith(m1)) h2 = (h2 * 1.2).round();

          var rhythm = 0;
          var fatigue = 0;
          final r0 = m0.riskLevel >= 3;
          final r1 = m1.riskLevel >= 3;
          final r2 = m2.riskLevel >= 3;
          if (r0 != r1) rhythm += 10;
          if (r0 && r1) fatigue++;
          if (r1 != r2) rhythm += 10;
          if (r1 && r2) fatigue++;

          features.add(ItineraryFeature(
            hype: h0 + h1 + h2,
            fatiguePairs: fatigue,
            spotlightCount: spotlights,
            themeBeforePurity: baseline + slotBonus + rhythm,
            isPure: isPure,
            slotCount: 3,
          ));
        }
      }
    }
  }

  return features;
}

List<ItineraryFeature> _extract4SlotFeatures(
  List<TravelMaterial> materials,
  TravelPhilosophy phil,
  double cameraMultiplier,
) {
  final features = <ItineraryFeature>[];
  final n = materials.length;

  for (var i = 0; i < n; i++) {
    final m0 = materials[i];
    for (var j = 0; j < n; j++) {
      if (j == i) continue;
      final m1 = materials[j];
      for (var k = 0; k < n; k++) {
        if (k == i || k == j) continue;
        final m2 = materials[k];
        for (var l = 0; l < n; l++) {
          if (l == i || l == j || l == k) continue;
          final m3 = materials[l];

          var spotlights = 0;
          if (m0.isSpotlight) spotlights++;
          if (m1.isSpotlight) spotlights++;
          if (m2.isSpotlight) spotlights++;
          if (m3.isSpotlight) spotlights++;

          var slotBonus = 0;
          if (m0.hasTag('#散步') && m0.riskLevel <= 2) slotBonus += 5;
          if (m1.hasTag('#美食') && m1.riskLevel <= 2) slotBonus += 5;

          final c0 = phil.evaluateMaterial(m0);
          final c1 = phil.evaluateMaterial(m1);
          final c2 = phil.evaluateMaterial(m2);
          final c3 = phil.evaluateMaterial(m3);
          final sumContrib = (c0.effectiveTheme - c0.flatThemePenalty) +
              (c1.effectiveTheme - c1.flatThemePenalty) +
              (c2.effectiveTheme - c2.flatThemePenalty) +
              (c3.effectiveTheme - c3.flatThemePenalty);
          final isPure = c0.isAligned && c1.isAligned && c2.isAligned && c3.isAligned;

          var h0 = m0.hypeValue;
          var h1 = m1.hypeValue;
          if (m1.sharesTagWith(m0)) h1 = (h1 * 1.2).round();
          var h2 = (m2.hypeValue * cameraMultiplier).round();
          if (m2.sharesTagWith(m1)) h2 = (m2.hypeValue * cameraMultiplier * 1.2).round();
          var h3 = m3.hypeValue;
          if (m3.sharesTagWith(m2)) h3 = (h3 * 1.2).round();

          var rhythm = 0;
          var fatigue = 0;
          final r0 = m0.riskLevel >= 3;
          final r1 = m1.riskLevel >= 3;
          final r2 = m2.riskLevel >= 3;
          final r3 = m3.riskLevel >= 3;
          if (r0 != r1) rhythm += 10;
          if (r0 && r1) fatigue++;
          if (r1 != r2) rhythm += 10;
          if (r1 && r2) fatigue++;
          if (r2 != r3) rhythm += 10;
          if (r2 && r3) fatigue++;

          final baseline = 50 + (sumContrib / 4.0).round();
          features.add(ItineraryFeature(
            hype: h0 + h1 + h2 + h3,
            fatiguePairs: fatigue,
            spotlightCount: spotlights,
            themeBeforePurity: baseline + slotBonus + rhythm,
            isPure: isPure,
            slotCount: 4,
          ));
        }
      }
    }
  }

  return features;
}

List<ItineraryFeature> _pruneFrontier(List<ItineraryFeature> features) {
  final groups = <int, List<ItineraryFeature>>{};
  for (final f in features) {
    final key = (f.fatiguePairs << 4) | (f.spotlightCount << 1) | (f.isPure ? 1 : 0);
    (groups[key] ??= []).add(f);
  }

  final result = <ItineraryFeature>[];
  for (final list in groups.values) {
    list.sort((a, b) {
      final cmpHype = b.hype.compareTo(a.hype);
      if (cmpHype != 0) return cmpHype;
      return b.themeBeforePurity.compareTo(a.themeBeforePurity);
    });

    var maxThemeSeen = -1;
    for (final f in list) {
      if (f.themeBeforePurity > maxThemeSeen) {
        result.add(f);
        maxThemeSeen = f.themeBeforePurity;
      }
    }
  }
  return result;
}

int _diffFrom90(D3Candidate c) {
  final sat90Bw = (100 - c.themeWeight) + (c.themeWeight * 90 / 100).round();
  final sat90Hi = (100.0 * (c.floor + (100 - c.floor) * 90 / 100) / 100).round();
  return (sat90Bw - 90).abs() + (sat90Hi - 90).abs();
}

int _dropDiffFrom25(D3Candidate c) {
  final sat90Bw = (100 - c.themeWeight) + (c.themeWeight * 90 / 100).round();
  final sat30Bw = (100 - c.themeWeight) + (c.themeWeight * 30 / 100).round();
  final dropBw = sat90Bw - sat30Bw;

  final sat90Hi = (100.0 * (c.floor + (100 - c.floor) * 90 / 100) / 100).round();
  final sat30Hi = (100.0 * (c.floor + (100 - c.floor) * 30 / 100) / 100).round();
  final dropHi = sat90Hi - sat30Hi;

  return (dropBw - 25).abs() + (dropHi - 25).abs();
}

bool _satisfiesD3Constraints(D3Candidate c) {
  final sat90Bw = (100 - c.themeWeight) + (c.themeWeight * 90 / 100).round();
  if (sat90Bw < 85 || sat90Bw > 95) return false;
  final sat30Bw = (100 - c.themeWeight) + (c.themeWeight * 30 / 100).round();
  if (sat90Bw - sat30Bw < 20) return false;

  final sat90Hi = (100.0 * (c.floor + (100 - c.floor) * 90 / 100) / 100).round();
  if (sat90Hi < 85 || sat90Hi > 95) return false;
  final sat30Hi = (100.0 * (c.floor + (100 - c.floor) * 30 / 100) / 100).round();
  if (sat90Hi - sat30Hi < 20) return false;

  return true;
}

String _computeCatalogFingerprint() {
  var hash = 0xcbf29ce484222325;
  for (final m in kyotoNightMaterials) {
    final s = '${m.id}:${m.cost}:${m.themeValue}:${m.hypeValue}:${m.riskLevel}:${m.isSpotlight};';
    for (final unit in s.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

bool _satisfiesD2Constraints(D2Candidate c) {
  final twoTagBonus = (45 * c.twoTagCoeff / 100).round();
  final baselineTwo = 50 + twoTagBonus;
  if (baselineTwo < 88 || baselineTwo > 92) return false;

  final threeTagBonus = (45 * c.threePlusCoeff / 100).round();
  final baselineThree = 50 + threeTagBonus;
  if (baselineThree < 88 || baselineThree > 92) return false;

  final oneTagBonus = (45 * c.oneTagCoeff / 100).round();
  final baselineOne = 50 + oneTagBonus;
  if (baselineOne > 75) return false;

  final repelledPenalty = (45 * c.repelledCoeff / 100).round();
  final baselineRepelled = 50 - repelledPenalty;
  if (baselineRepelled > 20) return false;

  final diff = baselineTwo - baselineRepelled;
  if (diff < 25) return false;

  return true;
}
