// 一次性工具腳本（不是測試）：在 G5 修改 client_review_engine.dart「之前」
// 執行，擷取全母體 satisfaction/outcome 分佈的指紋，寫入
// test/fixtures/pre_m5_satisfaction_outcome_golden.json。
//
// AC-M5-9.3 的守門測試（G10 任務）會在 G5 完成後重跑同一母體，比對指紋
// 逐格零差異——只要 (satisfaction, outcome) 序列有任何一格不同，SHA-256
// 雜湊就會改變，不需要保存全部 560,560 筆原始值。
//
// 母體與 test/analysis/golden_slot_tier_regression_test.dart 同基準：
// reachablePool.take(16)、每手 6 張 (C(16,6)=8008)、每手 3/4 槽全部合法
// 提交（35 種），兩客戶，共 280,280 個行程 × 2 = 560,560 筆。
import 'dart:convert';
import 'dart:io';

import 'package:share_tour/data/core_loop/kyoto_poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/timeline_itinerary.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_review_engine.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';

void main() {
  const manifest = KyotoNightMapManifest();
  const resolver = KyotoPoiMaterialResolver();
  final pool = manifest.districtAttractions
      .map((a) => resolver.resolveMaterialFor(a.id)!)
      .take(16)
      .toList();

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

  const clients = [ClientSpec.budgetWorker, ClientSpec.hypeInfluencer];
  const philosophy = TravelPhilosophy.midnight;

  final buffer = StringBuffer();
  final satisfactionHistogram = <int, int>{};
  final outcomeHistogram = <String, int>{};
  var total = 0;

  for (final hand in hands) {
    for (final sub in subsets) {
      // 每個組合固定放在前 N 個連續槽位（3 張 → [0,1,2]，4 張 → 全滿）。
      // 這是「35 種提交」的具體化：一個組合對應一種排列，不窮舉全部排列
      // ——第一層滿意度雖依排列而變，但本檔只需要「同一組固定排列」在
      // G5 前後產生相同結果，不需要窮舉每個組合的所有排列。
      final List<TravelMaterial?> slots = List.filled(4, null);
      for (var i = 0; i < sub.length; i++) {
        slots[i] = pool[hand[sub[i]]];
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
        satisfactionHistogram[report.satisfaction] =
            (satisfactionHistogram[report.satisfaction] ?? 0) + 1;
        outcomeHistogram[report.outcome.name] =
            (outcomeHistogram[report.outcome.name] ?? 0) + 1;
        total++;
      }
    }
  }

  final digest = _fnv1a64Hex(utf8.encode(buffer.toString()));

  final out = {
    'description': 'AC-M5-9.3 golden fixture：G5 修改 client_review_engine.dart '
        '之前擷取，供第一層零改動的比對基準。',
    'populationSize': total,
    'handsCount': hands.length,
    'subsetsCount': subsets.length,
    'clientsCount': clients.length,
    'philosophy': philosophy.name,
    'fingerprintOfSatisfactionOutcomeSequence': digest,
    'satisfactionHistogram': {
      for (final e in satisfactionHistogram.entries) '${e.key}': e.value,
    },
    'outcomeHistogram': outcomeHistogram,
  };

  final path = 'test/fixtures/pre_m5_satisfaction_outcome_golden.json';
  File(path).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(out),
  );
  // ignore: avoid_print
  print('寫入 $path，population=$total，指紋=$digest');
}

/// FNV-1a 風格雜湊，遮罩在 60 位元以確保 Dart 64 位元有號 int 恆為非負值
/// （64 位元會踩到符號位，`toRadixString` 對負數印出減號而非位元組樣）。
///
/// 不追求密碼學安全，只需要「任一格不同就改變」的指紋——避免引入
/// `package:crypto` 這個 lib/ 之外才會有的直接相依（CLAUDE.md §6）。
String _fnv1a64Hex(List<int> bytes) {
  const prime = 0x100000001b3;
  var hash = 0xcbf29ce484222325 & mask60;
  for (final b in bytes) {
    hash = (hash ^ b) & mask60;
    hash = (hash * prime) & mask60;
  }
  return hash.toRadixString(16).padLeft(15, '0');
}

const mask60 = 0xFFFFFFFFFFFFFFF;
