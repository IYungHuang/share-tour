import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/material_catalog_audit.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';

void main() {
  group('MaterialCatalogAudit 標籤詞彙表與內容審計 (AC-A1-0)', () {
    TravelMaterial makeMaterial({
      required String id,
      required List<String> tags,
    }) {
      return TravelMaterial(
        id: id,
        name: id,
        tags: tags,
        themeValue: 10,
        hypeValue: 10,
        cost: 0,
        riskLevel: 1,
      );
    }

    test('AC-A1-0.1 偏好標籤覆蓋率：每個偏好標籤至少 2 張素材', () {
      final materials = [
        makeMaterial(id: 'm1', tags: ['#深夜']),
        makeMaterial(id: 'm2', tags: ['#深夜']),
        makeMaterial(id: 'm3', tags: ['#小酌']),
      ];

      final violations = auditMaterialCatalog(
        materials: materials,
        philosophies: [TravelPhilosophy.midnight],
      );

      expect(
        violations.any((v) =>
            v.code == 'preferredTagCoverage' &&
            v.philosophy == 'midnight' &&
            v.tag == '#小酌' &&
            v.actual == 1 &&
            v.required == 2),
        isTrue,
      );
    });

    test('AC-A1-0.2 排斥標籤宣告：排斥標籤數需 >= 1', () {
      final materials = [
        makeMaterial(id: 'm1', tags: ['#深夜']),
        makeMaterial(id: 'm2', tags: ['#深夜']),
      ];

      // 若有哲學未宣告排斥標籤
      final violations = auditMaterialCatalog(
        materials: materials,
        philosophies: [TravelPhilosophy.midnight],
      );

      // 當 midnight 宣告了 #拉車 時，不觸發 repelledTagDeclaration
      expect(
        violations.any((v) => v.code == 'repelledTagDeclaration'),
        isFalse,
      );
    });

    test('AC-A1-0.2 排斥標籤聯集覆蓋率：排斥標籤聯集至少 4 張素材', () {
      final materials = [
        makeMaterial(id: 'm1', tags: ['#深夜']),
        makeMaterial(id: 'm2', tags: ['#深夜']),
        makeMaterial(id: 'm3', tags: ['#小酌']),
        makeMaterial(id: 'm4', tags: ['#小酌']),
        makeMaterial(id: 'r1', tags: ['#拉車']),
        makeMaterial(id: 'r2', tags: ['#拉車']),
        makeMaterial(id: 'r3', tags: ['#拉車']),
      ];

      final violations = auditMaterialCatalog(
        materials: materials,
        philosophies: [TravelPhilosophy.midnight],
      );

      expect(
        violations.any((v) =>
            v.code == 'repelledTagUnionCoverage' &&
            v.philosophy == 'midnight' &&
            v.actual == 3 &&
            v.required == 4),
        isTrue,
      );
    });

    test('AC-A1-0.3 哲學標籤覆蓋率：哲學聲明的所有標籤必須 100% 存在於素材庫', () {
      final materials = [
        makeMaterial(id: 'm1', tags: ['#深夜']),
        makeMaterial(id: 'm2', tags: ['#深夜']),
        makeMaterial(id: 'm3', tags: ['#拉車']),
        makeMaterial(id: 'm4', tags: ['#拉車']),
        makeMaterial(id: 'm5', tags: ['#拉車']),
        makeMaterial(id: 'm6', tags: ['#拉車']),
      ]; // 缺少 #小酌

      final violations = auditMaterialCatalog(
        materials: materials,
        philosophies: [TravelPhilosophy.midnight],
      );

      expect(
        violations.any((v) =>
            v.code == 'philosophyTagCoverage' &&
            v.philosophy == 'midnight' &&
            v.tag == '#小酌' &&
            v.actual == 0 &&
            v.required == 1),
        isTrue,
      );
    });

    test('AC-A1-0.4 未使用標籤卡片比例：僅帶未使用標籤卡片數 <= 1/3', () {
      // 3 張卡中恰好 1 張僅帶未使用標籤 (1/3) -> 通過
      final boundaryPool = [
        makeMaterial(id: 'm1', tags: ['#深夜']),
        makeMaterial(id: 'm2', tags: ['#小酌']),
        makeMaterial(id: 'm3', tags: ['#咖啡']), // 未被 midnight 使用
      ];

      final boundaryViolations = auditMaterialCatalog(
        materials: boundaryPool,
        philosophies: [TravelPhilosophy.midnight],
      );

      expect(
        boundaryViolations.any((v) => v.code == 'unusedOnlyCardRatio'),
        isFalse,
      );

      // 3 張卡中有 2 張僅帶未使用標籤 (2/3 > 1/3) -> 違規
      final overLimitPool = [
        makeMaterial(id: 'm1', tags: ['#深夜']),
        makeMaterial(id: 'm2', tags: ['#咖啡']),
        makeMaterial(id: 'm3', tags: ['#浪漫']),
      ];

      final overLimitViolations = auditMaterialCatalog(
        materials: overLimitPool,
        philosophies: [TravelPhilosophy.midnight],
      );

      expect(
        overLimitViolations.any((v) =>
            v.code == 'unusedOnlyCardRatio' &&
            v.actual == 2 &&
            v.required == 1),
        isTrue,
      );
    });
  });
}
