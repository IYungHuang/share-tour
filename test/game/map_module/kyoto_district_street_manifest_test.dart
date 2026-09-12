import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_district_street_manifest.dart';

void main() {
  group('KyotoDistrictStreetManifest 五大分區中觀散步街區規格測試', () {
    test('1. 五大分區覆蓋度：涵蓋洛中、洛東、洛西、洛東北、洛南', () {
      expect(KyotoDistrictType.values.length, 5);
      final codes = KyotoDistrictType.values.map((d) => d.code).toSet();
      expect(codes.contains('kyoto_nakagyo'), isTrue);
      expect(codes.contains('kyoto_higashiyama'), isTrue);
      expect(codes.contains('kyoto_arashiyama'), isTrue);
      expect(codes.contains('kyoto_sakyo'), isTrue);
      expect(codes.contains('kyoto_fushimi_uji'), isTrue);
    });

    test('2. 五大分區景點總數嚴格等於京都 32 處 POI', () {
      int totalSpots = 0;
      final allSpotIds = <String>{};

      for (final district in KyotoDistrictType.values) {
        final manifest = KyotoDistrictStreetManifest(district);
        final attractions = manifest.districtAttractions;
        expect(attractions.length, district.spotCount);
        totalSpots += attractions.length;

        for (final a in attractions) {
          expect(allSpotIds.contains(a.id), isFalse,
              reason: 'POI ${a.id} 重複出現在多個分區中');
          allSpotIds.add(a.id);
          // 像素坐標必須在 1024x1024 畫布內
          expect(a.pixel.x >= 0 && a.pixel.x <= 1024, isTrue);
          expect(a.pixel.y >= 0 && a.pixel.y <= 1024, isTrue);
        }
      }

      expect(totalSpots, 32);
      expect(allSpotIds.length, 32);
    });

    test('3. 五大分區底圖資產均存在且可讀取', () {
      for (final district in KyotoDistrictType.values) {
        final file = File('assets/images/${district.assetPath}');
        expect(file.existsSync(), isTrue,
            reason: '${district.name} 底圖資產不存在: ${district.assetPath}');
      }
    });

    test('4. 降落點在畫布中央安全區域內', () {
      for (final district in KyotoDistrictType.values) {
        final manifest = KyotoDistrictStreetManifest(district);
        final spawn = manifest.defaultSpawnPixel;
        expect(spawn.x >= 200 && spawn.x <= 800, isTrue);
        expect(spawn.y >= 200 && spawn.y <= 850, isTrue);
      }
    });
  });
}
