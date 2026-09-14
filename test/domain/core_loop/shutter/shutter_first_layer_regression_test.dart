@Tags(['slow'])
library;

// AC-M5-9.3：全母體三態齊一下的 satisfaction/outcome 分佈，與 M5 動
// client_review_engine.dart 之前擷取的 golden fixture 逐格零差異。
//
// 用同一個「指紋」比對法（見 tool/capture_pre_m5_golden.dart 的說明）：
// 任一格不同，序列的雜湊就會改變。三態齊一（全 normal、全 perfect、
// 全 failed）都要對得上同一份 golden——因為第一層「一個字元不動」
// （REQ-M5-02.5 規則 5），不管三態怎麼混，satisfaction/outcome 都該
// 與 M5 之前完全相同。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';

const _mask60 = 0xFFFFFFFFFFFFFFF;

String _fnv1a64Hex(List<int> bytes) {
  const prime = 0x100000001b3;
  var hash = 0xcbf29ce484222325 & _mask60;
  for (final b in bytes) {
    hash = (hash ^ b) & _mask60;
    hash = (hash * prime) & _mask60;
  }
  return hash.toRadixString(16).padLeft(15, '0');
}

void main() {
  test('AC-M5-9.3: 三態齊一下 satisfaction/outcome 與 golden 指紋逐格零差異', () {
    final goldenFile = File(
      'test/fixtures/pre_m5_satisfaction_outcome_golden.json',
    );
    final golden = jsonDecode(goldenFile.readAsStringSync()) as Map;
    final expectedFingerprint =
        golden['fingerprintOfSatisfactionOutcomeSequence'] as String;
    final expectedPopulation = golden['populationSize'] as int;

    const manifest = KyotoNightMapManifest();
    const resolver = KyotoPoiMaterialResolver();
    final pool = manifest.districtAttractions
        .map((a) => resolver.resolveMaterialFor(a.id)!)
        .take(16)
        .toList();

    final subsets = <List<int>>[];
    for (var mask = 0; mask < 64; mask++) {
      final bits =
          mask.toRadixString(2).split('').where((c) => c == '1').length;
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

    const clients = [ClientSpec.budgetWorker, ClientSpec.hypeInfluencer];
    const philosophy = TravelPhilosophy.midnight;

    // 三態齊一（normal 為基準——這是原始 golden 擷取時卡表的實際狀態，
    // 因為 shotTier 預設 normal，卡表沒有指定 tier 時就是全 normal）。
    for (final tier in [ShotTier.normal, ShotTier.perfect, ShotTier.failed]) {
      final buffer = StringBuffer();
      var total = 0;

      for (final hand in hands) {
        for (final sub in subsets) {
          final List<TravelMaterial?> slots = List.filled(4, null);
          for (var i = 0; i < sub.length; i++) {
            final base = pool[hand[sub[i]]];
            slots[i] = tier == ShotTier.normal ? base : base.copyWith(shotTier: tier);
          }
          final stats = TimelineItinerary(slots: slots).calculateStats(
            philosophy: philosophy,
            cameraMultiplier: 1.5,
          );
          for (final client in clients) {
            final report = ClientReviewEngine.evaluate(
              client: client,
              stats: stats,
              philosophy: philosophy,
            );
            buffer.write('${report.satisfaction},${report.outcome.name};');
            total++;
          }
        }
      }

      expect(total, expectedPopulation, reason: '母體規模須與 golden 一致（$tier）');
      final fingerprint = _fnv1a64Hex(utf8.encode(buffer.toString()));
      expect(
        fingerprint,
        expectedFingerprint,
        reason: 'shotTier=$tier 時 satisfaction/outcome 序列與 golden 不符——'
            '第一層被 M5 的改動動到了',
      );
    }
  });
}
