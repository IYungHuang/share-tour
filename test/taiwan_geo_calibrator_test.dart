import 'package:flutter_test/flutter_test.dart';
import 'package:flame/extensions.dart';
import 'package:share_tour/game/map_module/manifests/taiwan_map_manifest.dart';
import 'package:share_tour/game/map_module/utils/taiwan_geo_calibrator.dart';

void main() {
  group('TaiwanGeoCalibrator Test', () {
    final manifest = TaiwanMapManifest();

    // 斷言改為對照 manifest 的錨點資料，而非硬編碼像素值，
    // 這樣校正錨點時不必同步修改測試。
    test('Exact match on Taipei 101 anchor', () {
      final anchor = manifest.anchors.firstWhere((a) => a.name == '台北101');
      final pixel = manifest.projectGpsToPixel(anchor.lat, anchor.lng);
      expect((pixel.x - anchor.pixelPos.x).abs() < 1.0, isTrue);
      expect((pixel.y - anchor.pixelPos.y).abs() < 1.0, isTrue);
    });

    test('Road snapping within threshold', () {
      final node = manifest.roadNodes.first;
      final rawPos = node + Vector2(5, 5);
      final snapped =
          TaiwanGeoCalibrator.snapToRoad(rawPos, manifest.roadNodes, threshold: 40.0);
      expect(snapped, equals(node));
    });

    test('Road snapping beyond threshold keeps original position', () {
      final rawPos = Vector2(2000, 2000);
      final snapped =
          TaiwanGeoCalibrator.snapToRoad(rawPos, manifest.roadNodes, threshold: 40.0);
      expect(snapped, equals(rawPos));
    });
  });
}
