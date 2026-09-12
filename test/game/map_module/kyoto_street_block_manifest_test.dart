import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_street_block_manifest.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('KyotoStreetBlockManifest 中觀街區規格測試', () {
    const manifest = KyotoStreetBlockManifest();

    test('1. 基礎屬性契約：mapId, assetPath, 1024x1024 尺寸', () {
      expect(manifest.mapId, 'kyoto_street_block');
      expect(manifest.assetPath, 'kyoto_night_block.png');
      expect(manifest.mapDimensions, Vector2(1024, 1024));
      expect(manifest.hasOceanWaves, isFalse);
    });

    test('2. 降落點與速度契約：spawn (512, 512)，速度 40 px/s', () {
      expect(manifest.defaultSpawnPixel, Vector2(512.0, 512.0));
      expect(manifest.dpadSpeedPixelsPerSecond, 40.0);
    });

    test('3. 景點資料集：涵蓋 9 處洛中町家核心景點', () {
      final attractions = manifest.districtAttractions;
      expect(attractions.length, 9);
      final ids = attractions.map((a) => a.id).toSet();
      expect(ids.contains('kyoto_kiyamachi_ramen'), isTrue);
      expect(ids.contains('kyoto_pontocho_cat'), isTrue);
      expect(ids.contains('kyoto_nishiki_closed'), isTrue);
      expect(ids.contains('kyoto_sanjo_starbucks'), isTrue);
      expect(ids.contains('kyoto_teramachi_record'), isTrue);
      expect(ids.contains('kyoto_inoda_coffee'), isTrue);
      expect(ids.contains('kyoto_kyogoku_stand'), isTrue);
      expect(ids.contains('kyoto_ghost_vending'), isTrue);
      expect(ids.contains('kyoto_omiya_tachinomi'), isTrue);
    });

    test('4. 底圖資產可解碼：kyoto_night_block.png 存在且可讀', () {
      final file = File('assets/images/${manifest.assetPath}');
      expect(file.existsSync(), isTrue);
    });
  });
}
