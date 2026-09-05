import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:share_tour/domain/location/pipeline/manifest_geometry_check.dart';

void main() {
  test('AC-4.6 規則本身正確：合法資料無衝突', () {
    final conflicts = findSnapTriggerConflicts(
      roadNodes: [Vector2(0, 0), Vector2(1000, 0)],
      pois: [
        PoiMarker(id: 'far', pixel: Vector2(500, 500), triggerRadiusMeters: 50)
      ],
      snapLimitMeters: 50,
      metersPerPixel: 1.0,
    );
    expect(conflicts, isEmpty);
  });

  test('AC-4.6 規則本身正確：節點壓在 POI 上會被抓到', () {
    final conflicts = findSnapTriggerConflicts(
      roadNodes: [Vector2(500, 500)],
      pois: [
        PoiMarker(id: 'onTop', pixel: Vector2(500, 500), triggerRadiusMeters: 50)
      ],
      snapLimitMeters: 50,
      metersPerPixel: 1.0,
    );
    expect(conflicts, hasLength(1));
    expect(conflicts.single, contains('onTop'));
  });

  // AC-4.6 對台灣圖資的驗證移至 Task 4b：它需要 TaiwanMapManifest 實作
  // snapLimitMeters 與 metersPerPixelAt，那是 4b 的產出。
  // 計劃的相依圖漏了這條邊，執行時撞出來。
}
