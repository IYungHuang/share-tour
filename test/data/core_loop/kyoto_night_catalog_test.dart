import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';

void main() {
  group('京都夜間 30 處特色旅行素材庫測試 (Data DLC)', () {
    test('素材庫包含至少 30 個精選素材，且 ID 無重複', () {
      final catalog = kyotoNightMaterials;
      expect(catalog.length, greaterThanOrEqualTo(30));

      final idSet = catalog.map((m) => m.id).toSet();
      expect(idSet.length, catalog.length, reason: '素材庫存在重複 ID');
    });

    test('包含多種風險等級與焦點絕景 (isSpotlight)', () {
      final catalog = kyotoNightMaterials;
      final spotlights = catalog.where((m) => m.isSpotlight).toList();
      expect(
        spotlights.length,
        greaterThanOrEqualTo(3),
        reason: '至少需有 3 處絕景供網紅挑戰',
      );

      final lowRisk = catalog.where((m) => m.riskLevel <= 2).toList();
      final highRisk = catalog.where((m) => m.riskLevel >= 3).toList();
      expect(lowRisk, isNotEmpty);
      expect(highRisk, isNotEmpty);
    });

    test('涵蓋五大旅行哲學的核心偏好標籤', () {
      final catalog = kyotoNightMaterials;
      final allTags = catalog.expand((m) => m.tags).toSet();

      expect(
        allTags,
        containsAll([
          '#深夜', // midnight
          '#老街', // slow
          '#美食', // gourmet
          '#巷弄秘境', // antiTourism
          '#高風險', // chaos
        ]),
      );
    });

    test('所有素材成本、熱度、主題分數皆合理合法', () {
      for (final m in kyotoNightMaterials) {
        expect(m.name, isNotEmpty);
        expect(m.cost, greaterThanOrEqualTo(0));
        expect(m.themeValue, greaterThanOrEqualTo(0));
        expect(m.hypeValue, greaterThanOrEqualTo(0));
        expect(m.storyValue, inInclusiveRange(1, 5));
        expect(m.riskLevel, inInclusiveRange(1, 5));
      }
    });

    test('AC-A1-6.5 content tax keeps at most one free low-risk spotlight', () {
      final catalog = kyotoNightMaterials;
      final yasaka = catalog.firstWhere((m) => m.id == 'kyoto_yasaka_pagoda');
      expect(yasaka.cost, equals(500));
      expect(yasaka.riskLevel, equals(2));

      final freeLowRiskSpotlights = catalog
          .where((m) => m.isSpotlight && m.cost == 0 && m.riskLevel <= 2)
          .toList();
      expect(freeLowRiskSpotlights.length, lessThanOrEqualTo(1));
    });
  });
}
