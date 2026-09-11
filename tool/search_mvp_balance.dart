// ignore_for_file: avoid_print

import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';

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
    // 1. 兩客戶 Theme 90 參考分最接近 90
    final diff90A = _diffFrom90(a);
    final diff90B = _diffFrom90(b);
    if (diff90A != diff90B) return diff90A.compareTo(diff90B);

    // 2. Theme 30 降幅最接近 25
    final dropDiffA = _dropDiffFrom25(a);
    final dropDiffB = _dropDiffFrom25(b);
    if (dropDiffA != dropDiffB) return dropDiffA.compareTo(dropDiffB);

    // 3. (themeWeight, floor) 字典序
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
}

int _diffFrom90(D3Candidate c) {
  // 社畜：sat90 = (100 - tw) + round(tw * 90 / 100)
  final sat90Bw = (100 - c.themeWeight) + (c.themeWeight * 90 / 100).round();
  // 網紅：sat90 = round(100.0 * (fl + (100 - fl) * 0.90) / 100)
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
  // AC-A1-1.7 社畜:
  final sat90Bw = (100 - c.themeWeight) + (c.themeWeight * 90 / 100).round();
  if (sat90Bw < 85 || sat90Bw > 95) return false;
  final sat30Bw = (100 - c.themeWeight) + (c.themeWeight * 30 / 100).round();
  if (sat90Bw - sat30Bw < 20) return false;

  // AC-A1-1.7 網紅:
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
