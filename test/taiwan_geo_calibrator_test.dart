import 'package:flutter_test/flutter_test.dart';
import 'package:flame/extensions.dart';
import 'package:share_tour/game/map_module/manifests/taiwan_map_manifest.dart';
import 'package:share_tour/game/map_module/utils/taiwan_geo_calibrator.dart';

void main() {
  group('TaiwanGeoCalibrator Test', () {
    final manifest = TaiwanMapManifest();

    test('Exact match on Taipei 101 anchor', () {
      final pixel = manifest.projectGpsToPixel(25.034, 121.564);
      expect((pixel.x - 1050).abs() < 1.0, isTrue);
      expect((pixel.y - 180).abs() < 1.0, isTrue);
    });

    test('Road snapping within threshold', () {
      // Near Taipei 101 (1050, 180)
      final rawPos = Vector2(1055, 185);
      final snapped = TaiwanGeoCalibrator.snapToRoad(rawPos, manifest.roadNodes, threshold: 40.0);
      expect(snapped, equals(Vector2(1050, 180)));
    });

    test('Road snapping beyond threshold keeps original position', () {
      final rawPos = Vector2(2000, 2000);
      final snapped = TaiwanGeoCalibrator.snapToRoad(rawPos, manifest.roadNodes, threshold: 40.0);
      expect(snapped, equals(rawPos));
    });
  });
}
