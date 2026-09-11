import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';
import '../../support/core_loop/gathering_continuations.dart';

void main() {
  group('AC-A1-6.2 採集階段第二張絕景與非絕景之取捨決策測試', () {
    test('在同一組可達 POI 中，選第二張絕景之最高滿意度低於選非絕景素材，且差異由 HP 耗盡造成', () {
      const manifest = KyotoNightMapManifest();
      const resolver = KyotoPoiMaterialResolver();

      // 從正式 Kyoto manifest districtAttractions 經正式 resolver 導出可達池 (禁止手抄池)
      final pool = manifest.districtAttractions
          .map((a) => resolver.resolveMaterialFor(a.id)!)
          .toList();
      final poolMap = {for (final m in pool) m.id: m};

      // 1. 初始狀態：腰包未滿 (已採集 1 張卡)，且尚有一張絕景在手
      // 初始手牌：祇園白川辰巳大明神夜櫻 (第一張絕景, risk 1, 6 HP)
      final spot1 = poolMap['kyoto_gion_tatsumi']!;
      expect(spot1.isSpotlight, isTrue);

      // 當前處於一個尚未採集、腰包未滿的狀態 (例如剩餘 30 HP)
      const currentRemainingHp = 30;

      // 2. 候選分支：
      // 分支 A (第二張絕景): 八坂之塔清晨藍調時刻 (isSpotlight = true, risk 2, cost 12 HP)
      final candA = poolMap['kyoto_yasaka_pagoda']!;
      expect(candA.isSpotlight, isTrue);

      // 分支 B (非絕景素材): 先斗町迷路三花貓 (isSpotlight = false, risk 1, cost 6 HP)
      final candB = poolMap['kyoto_pontocho_cat']!;
      expect(candB.isSpotlight, isFalse);

      // 3. 剩餘可用池：
      // 包含高爆發素材伏見稻荷 (cost 24 HP) 與鴨川三角洲 (cost 6 HP)
      final remainingPool = [
        poolMap['kyoto_fushimi_torii']!,
        poolMap['kyoto_kamogawa_delta']!,
      ];

      const philosophy = TravelPhilosophy.midnight;
      const client = ClientSpec.hypeInfluencer;
      const cameraMultiplier = 1.5; // 相機 Lv.1

      // 窮舉受到 HP 與腰包限制下的所有合法採集續局
      final evalA = evaluateGatheringContinuations(
        startHand: [spot1, candA],
        startHp: currentRemainingHp - 12,
        remainingPool: remainingPool,
        philosophy: philosophy,
        client: client,
        cameraMultiplier: cameraMultiplier,
      );

      final evalB = evaluateGatheringContinuations(
        startHand: [spot1, candB],
        startHp: currentRemainingHp - 6,
        remainingPool: remainingPool,
        philosophy: philosophy,
        client: client,
        cameraMultiplier: cameraMultiplier,
      );

      // 斷言：選第二張絕景所得之最高滿意度低於選非絕景素材 (89 < 100)
      expect(
        evalA.maxSatisfaction,
        lessThan(evalB.maxSatisfaction),
        reason: '受到 HP 耗盡限制，第二張絕景分支無法續採高收益素材，滿意度嚴格較低',
      );

      // 4. 無 HP 限制控制組：等化可用 HP 後，第二張絕景分支不得仍嚴格較差
      final ctrlA = evaluateGatheringContinuations(
        startHand: [spot1, candA],
        startHp: 100,
        remainingPool: remainingPool,
        philosophy: philosophy,
        client: client,
        cameraMultiplier: cameraMultiplier,
        ignoreHpLimit: true,
      );

      final ctrlB = evaluateGatheringContinuations(
        startHand: [spot1, candB],
        startHp: 100,
        remainingPool: remainingPool,
        philosophy: philosophy,
        client: client,
        cameraMultiplier: cameraMultiplier,
        ignoreHpLimit: true,
      );

      expect(
        ctrlA.maxSatisfaction,
        greaterThanOrEqualTo(ctrlB.maxSatisfaction),
        reason: '在無 HP 限制的控制組下，第二張絕景分支不可仍嚴格較差，證明劣勢完全由 HP 耗盡造成',
      );
    });
  });
}
