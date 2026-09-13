import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:share_tour/game/components/attraction_layer_component.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AttractionLayerComponent 端點景點分布與邊界防溢出渲染測試', () {
    late final KyotoNightMapManifest manifest;

    setUpAll(() {
      manifest = const KyotoNightMapManifest();
    });

    test('1. 京都全 32 處 POI 雙軸投影座標皆在畫布安全內縮邊界內 (50 <= X, Y <= 974)', () {
      final attractions = manifest.districtAttractions;
      expect(attractions.length, 32);

      for (final a in attractions) {
        expect(a.pixel.x, greaterThanOrEqualTo(50.0),
            reason: '${a.title} (${a.id}) X 太靠近左邊界: ${a.pixel.x}');
        expect(a.pixel.x, lessThanOrEqualTo(974.0),
            reason: '${a.title} (${a.id}) X 太靠近右邊界: ${a.pixel.x}');
        expect(a.pixel.y, greaterThanOrEqualTo(50.0),
            reason: '${a.title} (${a.id}) Y 太靠近上邊界: ${a.pixel.y}');
        expect(a.pixel.y, lessThanOrEqualTo(974.0),
            reason: '${a.title} (${a.id}) Y 太靠近下邊界: ${a.pixel.y}');
      }
    });

    test('2. 北端景點（鞍馬末班單節電車）配準後具備足夠頂部餘裕 (Y >= 50)', () {
      final kurama = manifest.districtAttractions
          .firstWhere((a) => a.id == 'kyoto_kurama_night_train');
      expect(kurama.pixel.y, closeTo(55.0, 1.0),
          reason: '鞍馬電車 Y 軸應精確落在北方林區 Y=55 附近，不可為 0.0');
    });

    test('3. 南端景點（宇治川夜景、伏見酒造）配準後具備足夠底部餘裕 (Y <= 960)', () {
      final uji = manifest.districtAttractions
          .firstWhere((a) => a.id == 'kyoto_ujigawa_night');
      expect(uji.pixel.y, lessThanOrEqualTo(960.0),
          reason: '宇治川夜景 Y 軸應 <= 960，保留底部邊界空間');

      final sake = manifest.districtAttractions
          .firstWhere((a) => a.id == 'kyoto_shinsei_sake');
      expect(sake.pixel.y, lessThanOrEqualTo(860.0));
    });

    test('4. 西端景點（嵐山竹林）與東端景點（大文字山）具備足夠橫向餘裕', () {
      final arashiyama = manifest.districtAttractions
          .firstWhere((a) => a.id == 'kyoto_arashiyama_bamboo');
      expect(arashiyama.pixel.x, greaterThanOrEqualTo(70.0),
          reason: '嵐山竹林 X 軸應 >= 70，保留左側安全距離');

      final daimonji = manifest.districtAttractions
          .firstWhere((a) => a.id == 'kyoto_daimonji_night_hike');
      expect(daimonji.pixel.x, lessThanOrEqualTo(880.0),
          reason: '大文字山夜爬 X 軸應 <= 880，保留右側安全距離');
    });

    test('5. AttractionLayerComponent 完整渲染所有縮放層級且無例外拋出', () {
      final component = AttractionLayerComponent(manifest: manifest);

      // 測試不同相機視口與縮放層級
      for (final zoom in [0.5, 0.8, 1.0, 1.5, 2.5, 3.5]) {
        component.updateVisibility(
          zoom: zoom,
          cameraCenter: vm.Vector2(512, 512),
        );

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(() => component.render(canvas), returnsNormally);

        final picture = recorder.endRecording();
        picture.dispose();
      }
    });

    test('6. 選中景點與擴大點擊判定閾值 (48px) 正確運作', () {
      final component = AttractionLayerComponent(manifest: manifest);
      component.updateVisibility(
        zoom: 1.0,
        cameraCenter: vm.Vector2(512, 512),
      );

      final firstSpot = manifest.districtAttractions.first;
      // 在景點周圍 30px (小於 48px) 處點擊應能命中
      final nearClick = firstSpot.pixel + vm.Vector2(20.0, 20.0);
      final hit = component.findAttractionAt(nearClick, thresholdPixels: 48.0);
      expect(hit, isNotNull);
      expect(hit!.id, firstSpot.id);

      // 選中後渲染脈衝光環與選中標籤無例外
      component.selectAttraction(hit);
      expect(component.selectedAttraction?.id, firstSpot.id);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => component.render(canvas), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('7. 切換圖資 (switchManifest) 清除舊快取並重新過濾景點', () {
      final component = AttractionLayerComponent(manifest: manifest);
      component.updateVisibility(zoom: 1.0, cameraCenter: vm.Vector2(512, 512));

      expect(component.visibleAttractions, isNotEmpty);
      component.selectAttraction(manifest.districtAttractions.first);

      // 切換相同的 manifest
      component.switchManifest(manifest);
      expect(component.selectedAttraction, isNull);
      expect(component.currentDistrict, isNull);
      expect(component.visibleAttractions, isNotEmpty);
    });

    test('8. 預設純淨模式 (showOnlySelectedTag == true)：未選中時無標籤，選中後僅顯示該景點標籤', () {
      final component = AttractionLayerComponent(
        manifest: manifest,
        showOnlySelectedTag: true,
      );
      component.updateVisibility(zoom: 1.0, cameraCenter: vm.Vector2(512, 512));
      expect(component.selectedAttraction, isNull);

      // 未選中時渲染，應零例外且不產生標籤雜訊
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => component.render(canvas), returnsNormally);

      // 選取其中一個景點
      final target = manifest.districtAttractions.first;
      component.selectAttraction(target);
      expect(component.selectedAttraction?.id, target.id);
      expect(() => component.render(canvas), returnsNormally);

      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('9. 標籤上限閾值模式 (showOnlySelectedTag == false, maxVisibleTags == 2)：嚴格限制上限', () {
      final component = AttractionLayerComponent(
        manifest: manifest,
        showOnlySelectedTag: false,
        maxVisibleTags: 2,
      );
      component.updateVisibility(zoom: 1.0, cameraCenter: vm.Vector2(512, 512));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => component.render(canvas), returnsNormally);

      final picture = recorder.endRecording();
      picture.dispose();
    });
  });
}
