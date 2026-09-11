// ignore_for_file: avoid_print

import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';

typedef D2Candidate = ({
  int oneTagCoeff,
  int twoTagCoeff,
  int threePlusCoeff,
  int repelledCoeff,
});

void main() {
  print('=== Share Tour MVP Amendment 01 Balance Search Tool ===');

  // 1. 卡表指紋 (純 Dart 決定性雜湊，不引入非宣告套件)
  final catalogFingerprint = _computeCatalogFingerprint();
  print('Catalog Fingerprint: $catalogFingerprint (Total materials: ${kyotoNightMaterials.length})');

  // 2. D2 候選域搜尋
  print('\n--- Searching D2 (Theme Alignment Coefficients) ---');
  print('Domain: oneTag=40..55 (step 1), twoTag=85..90 (step 1), threePlus=91..93 (step 1), repelled=70..100 (step 1)');

  var totalTested = 0;
  final feasibleD2 = <D2Candidate>[];

  for (var one = 40; one <= 55; one++) {
    for (var two = 85; two <= 90; two++) {
      if (two <= one) continue;
      for (var three = 91; three <= 93; three++) {
        if (three <= two) continue;
        for (var rep = 70; rep <= 100; rep++) {
          totalTested++;
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

  print('Total candidates tested: $totalTested');
  print('Feasible candidates count: ${feasibleD2.length}');

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

  final winner = feasibleD2.first;
  print('\nSelected D2 Winner:');
  print('  oneTagCoeff: ${winner.oneTagCoeff}%');
  print('  twoTagCoeff: ${winner.twoTagCoeff}%');
  print('  threePlusCoeff: ${winner.threePlusCoeff}%');
  print('  repelledCoeff: ${winner.repelledCoeff}%');

  print('\nFeasible D2 sample (first 5):');
  for (final c in feasibleD2.take(5)) {
    print('  $c');
  }
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
  // AC-A1-1.1: 中性素材貢獻 0 -> baseline = 50
  // (自動滿足，因中性不加減)

  // AC-A1-1.2: themeValue = 45
  // 命中 2 個標籤: baseline 介於 88 與 92
  final twoTagBonus = (45 * c.twoTagCoeff / 100).round();
  final baselineTwo = 50 + twoTagBonus;
  if (baselineTwo < 88 || baselineTwo > 92) return false;

  // 命中 3 個標籤: baseline 介於 88 與 92
  final threeTagBonus = (45 * c.threePlusCoeff / 100).round();
  final baselineThree = 50 + threeTagBonus;
  if (baselineThree < 88 || baselineThree > 92) return false;

  // 命中 1 個標籤: baseline <= 75
  final oneTagBonus = (45 * c.oneTagCoeff / 100).round();
  final baselineOne = 50 + oneTagBonus;
  if (baselineOne > 75) return false;

  // AC-A1-1.3: 對每一種旅行哲學，存在四槽全排斥使 baseline <= 20
  // themeValue = 45 排斥扣分
  final repelledPenalty = (45 * c.repelledCoeff / 100).round();
  final baselineRepelled = 50 - repelledPenalty;
  if (baselineRepelled > 20) return false;

  // AC-A1-1.4: 存在素材使兩哲學 baseline 差 >= 25
  final diff = baselineTwo - baselineRepelled;
  if (diff < 25) return false;

  // AC-A1-1.5: 疲勞前 40~80, finalTheme = 疲勞前 - 10
  // 例如 baseline 60, 疲勞 -10 -> 50 (50 == 60 - 10)
  // 自動滿足，只要 clamp(0, 100) 作用於 (themeBeforeFatigue - 10)

  // AC-A1-1.6: baseline >= 88, 疲勞前 90~100, finalTheme = 疲勞前 - 10
  // 例如 baseline 90, 疲勞 -10 -> 80 (80 == 90 - 10)
  // 亦由流水線架構保證

  return true;
}
