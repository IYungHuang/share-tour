import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';
import 'package:share_tour/data/core_loop/kyoto_poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';

void main() {
  group('KyotoPoiMaterialResolver 嚴格京都 POI 素材解析器測試 (T0b)', () {
    const resolver = KyotoPoiMaterialResolver();

    test('實作 PoiMaterialResolver 介面', () {
      expect(resolver, isA<PoiMaterialResolver>());
    });

    test('已知 ID 精確解析為京都夜間素材庫對應卡牌', () {
      for (final expected in kyotoNightMaterials) {
        final resolved = resolver.resolveMaterialFor(expected.id);
        expect(resolved, isNotNull);
        expect(resolved, equals(expected));
        expect(resolved!.id, equals(expected.id));
        expect(resolved.name, equals(expected.name));
        expect(resolved.cost, equals(expected.cost));
        expect(resolved.riskLevel, equals(expected.riskLevel));
      }
    });

    test('未知 ID 一律回傳 null，不得合成兜底卡', () {
      expect(resolver.resolveMaterialFor('unknown_poi'), isNull);
      expect(resolver.resolveMaterialFor(''), isNull);
      expect(resolver.resolveMaterialFor('taiwan_taichung_station'), isNull);
    });

    test('重複查詢決定性一致', () {
      final first = resolver.resolveMaterialFor('kyoto_yasaka_pagoda');
      final second = resolver.resolveMaterialFor('kyoto_yasaka_pagoda');
      expect(first, isNotNull);
      expect(identical(first, second) || first == second, isTrue);
    });
  });
}
