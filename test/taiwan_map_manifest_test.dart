import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/game/map_module/manifests/taiwan_map_manifest.dart';

/// 錨點資料的回歸測試。
///
/// IDW 投影本身沒有地理知識，輸出完全由錨點的像素座標決定。
/// 錨點若不自洽，投影就會在該區域產生方位錯誤，而這種錯誤
/// 從演算法看不出來，只能靠對資料本身的約束來擋。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TaiwanMapManifest manifest;

  setUpAll(() async {
    manifest = await TaiwanMapManifest.load();
  });

  group('錨點資料自洽性', () {
    test('像素 x 隨經度單調遞增', () {
      final sorted = [...manifest.anchors]..sort((a, b) => a.lng.compareTo(b.lng));
      for (var i = 0; i < sorted.length - 1; i++) {
        final west = sorted[i];
        final east = sorted[i + 1];
        expect(
          west.pixelPos.x,
          lessThan(east.pixelPos.x),
          reason: '${west.name}(lng ${west.lng}) 在 ${east.name}(lng ${east.lng}) 以西，'
              '像素 x 卻不小於它：${west.pixelPos.x} vs ${east.pixelPos.x}',
        );
      }
    });

    test('像素 y 隨緯度單調遞減', () {
      final sorted = [...manifest.anchors]..sort((a, b) => a.lat.compareTo(b.lat));
      for (var i = 0; i < sorted.length - 1; i++) {
        final south = sorted[i];
        final north = sorted[i + 1];
        expect(
          south.pixelPos.y,
          greaterThan(north.pixelPos.y),
          reason: '${south.name} 在 ${north.name} 以南，像素 y 卻不大於它',
        );
      }
    });

    test('所有錨點落在畫布範圍內', () {
      for (final a in manifest.anchors) {
        expect(a.pixelPos.x, inInclusiveRange(0, manifest.mapDimensions.x));
        expect(a.pixelPos.y, inInclusiveRange(0, manifest.mapDimensions.y));
      }
    });
  });

  group('投影方位正確性', () {
    // 以真實地點驗證投影後的相對方位。這些點刻意不是錨點，
    // 才能驗證 IDW 在錨點之間的插值結果，而非只驗證錨點命中。
    test('屏東市投影後位於高雄以東', () {
      final pingtung = manifest.projectToPixel(22.669, 120.488);
      final kaohsiung = manifest.projectToPixel(22.611, 120.300);
      expect(
        pingtung.x,
        greaterThan(kaohsiung.x),
        reason: '屏東(lng 120.488) 在高雄(lng 120.300) 以東，投影後 x 應更大',
      );
    });

    test('岡山投影後位於高雄以北', () {
      final gangshan = manifest.projectToPixel(22.796, 120.295);
      final kaohsiung = manifest.projectToPixel(22.611, 120.300);
      expect(gangshan.y, lessThan(kaohsiung.y), reason: '岡山在高雄以北，投影後 y 應更小');
    });

    test('新竹投影後位於台中以北、台北以南', () {
      final hsinchu = manifest.projectToPixel(24.804, 120.972);
      final taichung = manifest.projectToPixel(24.163, 120.640);
      final taipei = manifest.projectToPixel(25.034, 121.564);
      expect(hsinchu.y, lessThan(taichung.y));
      expect(hsinchu.y, greaterThan(taipei.y));
    });
  });

  // POI 之間的距離約束、道路節點與 POI 的幾何間距檢查，已隨修訂四移至
  // manifest_geometry_check_test.dart（REQ-C-18，AC-18.3）。

  group('地理範圍判定（修訂四：分類遮罩）', () {
    test('每個 POI 都落在畫布內', () {
      for (final poi in manifest.poiNodes) {
        expect(poi.pixel.x, inInclusiveRange(0, manifest.mapDimensions.x));
        expect(poi.pixel.y, inInclusiveRange(0, manifest.mapDimensions.y));
      }
    });

    test('AC-10.1 反投影往返誤差小於 2 像素', () {
      for (final p in [Vector2(1162, 148), Vector2(909, 408), Vector2(816, 871)]) {
        final geo = manifest.unprojectToGeo(p);
        final back = manifest.projectToPixel(geo.latitude, geo.longitude);
        expect((back - p).length, lessThan(2.0), reason: '$p 往返失敗');
      }
    });

    test('有效地理範圍涵蓋台灣本島', () {
      expect(manifest.containsGeo(25.034, 121.564), isTrue, reason: '台北');
      expect(manifest.containsGeo(21.902, 120.852), isTrue, reason: '鵝鑾鼻');
      expect(manifest.containsGeo(35.011, 135.768), isFalse, reason: '京都');
    });

    test('舊矩形框（lat 21.4~25.7、lng 119.7~122.3）內的海域現在正確判為範圍外',
        () {
      // 修訂四動機：原本的矩形框把台灣海峽、巴士海峽、太平洋全部含在內。
      // 台灣海峽中點約 (24.0, 119.9)——在舊矩形框內，但在遮罩上是海洋。
      expect(manifest.containsGeo(24.0, 119.9), isFalse,
          reason: '台灣海峽中點：矩形框會誤判為範圍內，遮罩正確判為範圍外');
    });
  });
}
