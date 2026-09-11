import 'models/travel_material.dart';
import 'models/travel_philosophy.dart';

typedef MaterialCatalogViolation = ({
  String code,
  String? philosophy,
  String? tag,
  int actual,
  int required,
});

/// 旅行素材庫內容審計純領域函式 (AC-A1-0)
///
/// 檢驗旅行素材庫是否滿足五大旅行哲學的標籤詞彙表覆蓋與平衡契約：
/// - preferredTagCoverage: 每個偏好標籤承載素材數 >= 2 (AC-A1-0.1)
/// - repelledTagDeclaration: 每個哲學排斥標籤宣告數 >= 1 (AC-A1-0.2)
/// - repelledTagUnionCoverage: 每個哲學排斥標籤聯集承載素材數 >= 4 (AC-A1-0.2)
/// - philosophyTagCoverage: 哲學聲明標籤 100% 存在於素材庫 (AC-A1-0.3)
/// - unusedOnlyCardRatio: 僅帶未使用標籤卡片數 <= 全池 1/3 (AC-A1-0.4)
List<MaterialCatalogViolation> auditMaterialCatalog({
  required Iterable<TravelMaterial> materials,
  required Iterable<TravelPhilosophy> philosophies,
}) {
  final violations = <MaterialCatalogViolation>[];
  final materialList = materials.toList();

  for (final philosophy in philosophies) {
    // 1. AC-A1-0.1 偏好標籤覆蓋率：每個偏好標籤至少 2 張素材
    for (final tag in philosophy.preferredTags) {
      final count = materialList.where((m) => m.hasTag(tag)).length;
      if (count < 2) {
        violations.add((
          code: 'preferredTagCoverage',
          philosophy: philosophy.name,
          tag: tag,
          actual: count,
          required: 2,
        ));
      }
    }

    // 2. AC-A1-0.2 排斥標籤宣告：排斥標籤數 >= 1
    if (philosophy.repelledTags.isEmpty) {
      violations.add((
        code: 'repelledTagDeclaration',
        philosophy: philosophy.name,
        tag: null,
        actual: 0,
        required: 1,
      ));
    } else {
      // 排斥標籤聯集覆蓋率：排斥標籤聯集至少 4 張素材
      final unionCount = materialList
          .where((m) => philosophy.repelledTags.any((t) => m.hasTag(t)))
          .length;
      if (unionCount < 4) {
        violations.add((
          code: 'repelledTagUnionCoverage',
          philosophy: philosophy.name,
          tag: null,
          actual: unionCount,
          required: 4,
        ));
      }
    }

    // 3. AC-A1-0.3 哲學標籤覆蓋率：哲學聲明的標籤需 100% 存在於素材庫 (至少 1 張)
    final allDeclaredTags = [
      ...philosophy.preferredTags,
      ...philosophy.repelledTags,
    ];
    for (final tag in allDeclaredTags) {
      final exists = materialList.any((m) => m.hasTag(tag));
      if (!exists) {
        violations.add((
          code: 'philosophyTagCoverage',
          philosophy: philosophy.name,
          tag: tag,
          actual: 0,
          required: 1,
        ));
      }
    }
  }

  // 4. AC-A1-0.4 僅帶未使用標籤卡片比例：僅帶未使用標籤卡片數 <= 1/3 全池
  if (materialList.isNotEmpty) {
    final usedTags = philosophies
        .expand((p) => [...p.preferredTags, ...p.repelledTags])
        .toSet();
    final unusedOnlyCards = materialList
        .where((m) =>
            m.tags.isEmpty || m.tags.every((t) => !usedTags.contains(t)))
        .length;
    final maxAllowed = materialList.length ~/ 3;
    if (unusedOnlyCards * 3 > materialList.length) {
      violations.add((
        code: 'unusedOnlyCardRatio',
        philosophy: null,
        tag: null,
        actual: unusedOnlyCards,
        required: maxAllowed,
      ));
    }
  }

  return violations;
}
