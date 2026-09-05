import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/game/map_module/manifests/taiwan_map_manifest.dart';

/// 錨點資料的回歸測試。
///
/// IDW 投影本身沒有地理知識，輸出完全由錨點的像素座標決定。
/// 錨點若不自洽，投影就會在該區域產生方位錯誤，而這種錯誤
/// 從演算法看不出來，只能靠對資料本身的約束來擋。
void main() {
  final manifest = TaiwanMapManifest();

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
      final pingtung = manifest.projectGpsToPixel(22.669, 120.488);
      final kaohsiung = manifest.projectGpsToPixel(22.611, 120.300);
      expect(
        pingtung.x,
        greaterThan(kaohsiung.x),
        reason: '屏東(lng 120.488) 在高雄(lng 120.300) 以東，投影後 x 應更大',
      );
    });

    test('岡山投影後位於高雄以北', () {
      final gangshan = manifest.projectGpsToPixel(22.796, 120.295);
      final kaohsiung = manifest.projectGpsToPixel(22.611, 120.300);
      expect(gangshan.y, lessThan(kaohsiung.y), reason: '岡山在高雄以北，投影後 y 應更小');
    });

    test('新竹投影後位於台中以北、台北以南', () {
      final hsinchu = manifest.projectGpsToPixel(24.804, 120.972);
      final taichung = manifest.projectGpsToPixel(24.163, 120.640);
      final taipei = manifest.projectGpsToPixel(25.034, 121.564);
      expect(hsinchu.y, lessThan(taichung.y));
      expect(hsinchu.y, greaterThan(taipei.y));
    });
  });

  group('POI 與道路節點', () {
    test('每個 POI 都落在畫布內', () {
      for (final poi in manifest.poiNodes) {
        expect(poi.pixelPosition.x, inInclusiveRange(0, manifest.mapDimensions.x));
        expect(poi.pixelPosition.y, inInclusiveRange(0, manifest.mapDimensions.y));
      }
    });

    test('POI 之間的距離大於觸發半徑總和，避免同時觸發兩個遭遇', () {
      final pois = manifest.poiNodes;
      for (var i = 0; i < pois.length; i++) {
        for (var j = i + 1; j < pois.length; j++) {
          final d = pois[i].pixelPosition.distanceTo(pois[j].pixelPosition);
          expect(
            d,
            greaterThan(pois[i].triggerRadius + pois[j].triggerRadius),
            reason: '${pois[i].title} 與 ${pois[j].title} 的觸發範圍重疊',
          );
        }
      }
    });
  });
}
