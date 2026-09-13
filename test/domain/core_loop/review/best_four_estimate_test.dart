import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/review/best_four_estimate.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';

TravelMaterial _m({
  required String id,
  required int hype,
  int cost = 0,
  bool isSpotlight = false,
}) =>
    TravelMaterial(
      id: id,
      name: id,
      tags: const [],
      themeValue: 0,
      hypeValue: hype,
      cost: cost,
      isSpotlight: isSpotlight,
    );

void main() {
  group('AC-M5-11.4a: 同一 4 張輸入，其值與客戶第二層公式輸出相等', () {
    test('4 張以下（不足以窮舉子集）直接用全部輸入計分', () {
      final materials = [
        _m(id: 'a', hype: 10),
        _m(id: 'b', hype: 20),
      ];
      final result = bestFourSecondLayerEstimate(
        materials,
        clientType: ClientType.hypeInfluencer,
        difficulty: ShutterDifficulty.tourist,
      );
      // 0 絕景 → spotlightLadder[0] = 0.70；raw = 30 * tierFactor(normal)=1.0
      expect(result, closeTo(30 * 0.70, 1e-9));
    });
  });

  group('AC-M5-11.4b: 「最佳」須為真 argmax，非排序近似', () {
    test('網紅端：排序取前 4 漏掉湊滿絕景階梯的第 4 張', () {
      // 4 張絕景各 hype=10（tierFactor normal=1.0），另一張非絕景 hype=15。
      // 依 hype 排序前 4：[非絕景15, 絕景10, 絕景10, 絕景10] → 3 絕景。
      // 真正最佳：全取 4 張絕景才能湊滿階梯 (4 絕景 ladder=1.00)。
      final materials = [
        _m(id: 's1', hype: 10, isSpotlight: true),
        _m(id: 's2', hype: 10, isSpotlight: true),
        _m(id: 's3', hype: 10, isSpotlight: true),
        _m(id: 's4', hype: 10, isSpotlight: true),
        _m(id: 'n1', hype: 15),
      ];

      final naiveSortTop4Score = (15 + 10 + 10 + 10) * 0.85; // 3 絕景 ladder
      final trueArgmaxScore = (10 + 10 + 10 + 10) * 1.00; // 4 絕景 ladder

      final result = bestFourSecondLayerEstimate(
        materials,
        clientType: ClientType.hypeInfluencer,
        difficulty: ShutterDifficulty.tourist,
      );

      expect(trueArgmaxScore, greaterThan(naiveSortTop4Score), reason: '反例腰包必須讓兩規則分岔');
      expect(result, closeTo(trueArgmaxScore, 1e-9));
    });

    test('社畜端：排序取前 4 忽略成本，選到高 hype 高成本卡拖垮 CP', () {
      // A: hype=100, cost=5000（單張就把分母推過 2000 下限）
      // B/C/D: hype=20, cost=100；E: hype=15, cost=100
      // 排序前 4（依 hype）：A,B,C,D → 分母被 A 的成本拉到 5300。
      // 真正最佳：排除 A，改用 B,C,D,E → 分母落在 2000 下限，CP 反而更高。
      final materials = [
        _m(id: 'a', hype: 100, cost: 5000),
        _m(id: 'b', hype: 20, cost: 100),
        _m(id: 'c', hype: 20, cost: 100),
        _m(id: 'd', hype: 20, cost: 100),
        _m(id: 'e', hype: 15, cost: 100),
      ];

      final naiveSortTop4Score = (100 + 20 + 20 + 20) / 5300 * 1000;
      final trueArgmaxScore = (20 + 20 + 20 + 15) / 2000 * 1000; // cost 400 < 2000 下限

      final result = bestFourSecondLayerEstimate(
        materials,
        clientType: ClientType.budgetWorker,
        difficulty: ShutterDifficulty.tourist,
      );

      expect(trueArgmaxScore, greaterThan(naiveSortTop4Score), reason: '反例腰包必須讓兩規則分岔');
      expect(result, closeTo(trueArgmaxScore, 1e-9));
    });
  });
}
