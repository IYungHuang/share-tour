import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KyotoNightMapManifest 契約與幾何規格測試 (Commit 12, T10)', () {
    late final KyotoNightMapManifest manifest;

    setUpAll(() {
      manifest = const KyotoNightMapManifest();
    });

    test('1. 基礎屬性契約：mapId, assetPath, 1024x1024 尺寸, 空 poiNodes', () {
      expect(manifest.mapId, 'kyoto_night_block');
      expect(manifest.assetPath, 'kyoto_night_block.png');
      expect(manifest.mapDimensions, Vector2(1024, 1024));
      expect(manifest.poiNodes, isEmpty);
      expect(manifest.oceanColorArgb, isNonZero);
    });

    test('2. 降落點與速度契約：spawn (128, 112)，速度 40 px/s', () {
      expect(manifest.defaultSpawnPixel, Vector2(128, 112));
      expect(manifest.dpadSpeedPixelsPerSecond, 40.0);
    });

    test('3. 邊界判定 (containsGeo)：京都核心街區內部為 true，外部為 false', () {
      // 中心點在範圍內
      expect(manifest.containsGeo(35.0000, 135.7600), isTrue);
      // 台北 (25.0330, 121.5654) 必須判定為不在圖資內
      expect(manifest.containsGeo(25.0330, 121.5654), isFalse);
      // 東京 (35.6762, 139.6503) 在圖資外
      expect(manifest.containsGeo(35.6762, 139.6503), isFalse);
    });

    test('4. 投影往返 (projectToPixel <-> unprojectToGeo) 逆運算誤差小於 1 像素', () {
      final testPixels = [
        Vector2(0, 0),
        Vector2(128, 112),
        Vector2(512, 512),
        Vector2(1024, 1024),
        Vector2(160, 224),
      ];

      for (final p in testPixels) {
        final geo = manifest.unprojectToGeo(p);
        final projected = manifest.projectToPixel(geo.latitude, geo.longitude);
        expect((projected - p).length, lessThan(1.0),
            reason: 'Pixel $p projected to $geo and back to $projected');
      }
    });

    test('5. 公尺/像素比例 (metersPerPixelAt) 保留嚴格正值', () {
      expect(manifest.metersPerPixelAt(Vector2.zero()), greaterThan(0));
      expect(manifest.metersPerPixelAt(Vector2(512, 512)), greaterThan(0));
      expect(manifest.metersPerPixelAt(Vector2(1024, 1024)), greaterThan(0));
    });

    test('6. 景點資料集：唯一 ID、涵蓋 32 處夜間素材庫，每個景點顯式給定 triggerRadiusPixels', () {
      final attractions = manifest.districtAttractions;
      expect(attractions.length, equals(kyotoNightMaterials.length));

      final idSet = attractions.map((a) => a.id).toSet();
      expect(idSet.length, equals(attractions.length), reason: '景點 ID 必須唯一');

      final catalogIds = kyotoNightMaterials.map((m) => m.id).toSet();
      expect(idSet, equals(catalogIds), reason: '景點集必須與 32 筆京都夜間卡表一一對應');

      for (final a in attractions) {
        expect(a.triggerRadiusPixels, isNotNull);
        expect(a.triggerRadiusPixels, greaterThan(0));
        // 像素座標必須在 1024x1024 畫布邊界內
        expect(a.pixel.x, greaterThanOrEqualTo(0));
        expect(a.pixel.x, lessThanOrEqualTo(1024));
        expect(a.pixel.y, greaterThanOrEqualTo(0));
        expect(a.pixel.y, lessThanOrEqualTo(1024));
      }
    });

    test('7. AC-A1-4.2 觸發窗口直徑（像素）>= 方向鍵速度 * 0.25 秒', () {
      final minRequiredDiameter = manifest.dpadSpeedPixelsPerSecond * 0.25;
      for (final a in manifest.districtAttractions) {
        final diameter = a.triggerRadiusPixels! * 2;
        expect(diameter, greaterThanOrEqualTo(minRequiredDiameter),
            reason: '景點 ${a.id} 直徑 $diameter 需 >= $minRequiredDiameter');
      }
    });

    test('8. 底圖資產可解碼：kyoto_night_block.png 存在且為 1024x1024 圖像', () async {
      final file = File('assets/images/${manifest.assetPath}');
      expect(file.existsSync(), isTrue, reason: '底圖資產檔案必須存在於 assets/images/');

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      expect(image.width, 1024);
      expect(image.height, 1024);
    });
  });
}
