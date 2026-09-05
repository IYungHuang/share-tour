import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/core/build_flags.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/domain/location/models/movement_event.dart';
import 'package:share_tour/state/location/location_controller.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_map_manifest.dart';

GeoFix at({required double metersNorth, int second = 0}) => GeoFix(
      latitude: 24.0 + metersNorth / 110574.0,
      longitude: 121.0,
      accuracyMeters: 20,
      hasAccuracy: true,
      speedMetersPerSecond: 1.4,
      hasSpeed: true,
      speedAccuracy: 0.5,
      hasSpeedAccuracy: true,
      timestampUtc: DateTime.utc(2026, 1, 1).add(Duration(seconds: second)),
      isMocked: false,
      sourceMode: SourceMode.gps,
    );

void main() {
  late FakeMapManifest layerA;
  late FakeMapManifest layerB;
  late LocationController c;

  setUp(() {
    layerA = FakeMapManifest.linear();
    layerB = FakeMapManifest.linear(originPixel: Vector2(500, 500));
    c = LocationController.forTest(
      manifest: layerA,
      clock: FakeClock(),
      flags: const BuildFlags.debug(),
    );
  });

  test('AC-15.1 換層後目標點來自新模組', () {
    c.ingest(at(metersNorth: 0));
    c.ingest(at(metersNorth: 60, second: 1));
    final before = c.state.targetPixel!.clone();
    c.switchLayer(layerB);
    expect(c.activeManifest, layerB);
    expect(c.state.renderedPixel, isNot(before));
  });

  test('AC-15.2 換層不發出任何傳送事件', () {
    c.ingest(at(metersNorth: 0));
    c.ingest(at(metersNorth: 60, second: 1));
    final before = c.events.whereType<RelocationEvent>().length;
    c.switchLayer(layerB);
    expect(c.events.whereType<RelocationEvent>().length, before,
        reason: '大跨距判準是地理位移，換層時地理位置不變 → 位移為 0，'
            '該路徑在建構上不可達');
  });

  test('AC-15.3 換層前後分桶距離連續', () {
    c.ingest(at(metersNorth: 0));
    c.ingest(at(metersNorth: 60, second: 1));
    final before = c.state.realDistanceMeters;
    expect(before, greaterThan(0));
    c.switchLayer(layerB);
    expect(c.state.realDistanceMeters, before, reason: '不得清零');

    // 換層重置了顯著性閘門的基準，所以第一筆只重建基準、不產生位移——
    // 與訊號恢復後同理。跨越換層那一刻的距離不該被計入，因為地理上
    // 玩家並沒有移動。
    c.ingest(at(metersNorth: 120, second: 2));
    expect(c.state.realDistanceMeters, before, reason: '首筆只重建基準');

    c.ingest(at(metersNorth: 180, second: 3));
    expect(c.state.realDistanceMeters, greaterThan(before),
        reason: '基準建立後恢復累計');
  });

  test('AC-15.4 換層後首筆 Fix 不因速度規則被丟棄', () {
    c.ingest(at(metersNorth: 0));
    c.switchLayer(layerB);
    // 相對前一筆是巨大位移，但基準已重置，應被接受
    c.ingest(at(metersNorth: 100000, second: 1));
    expect(c.state.diagnostics.rejectedFixCount, 0);
  });

  test('AC-15.5 公尺門檻依新圖層重算', () {
    final scaled = FakeMapManifest.fixedScale(370.4);
    c.ingest(at(metersNorth: 0));
    final before = c.arrivalThresholdPixels;
    expect(before, closeTo(2.0, 0.01));
    c.switchLayer(scaled);
    expect(c.arrivalThresholdPixels, closeTo(0.0054, 0.0005));
  });

  test('AC-15.6 換層後位置在新模組範圍外 → 換層仍成功，coverage = outside', () {
    final far = FakeMapManifest.linearAt(minLat: 40, minLng: 100);
    c.ingest(at(metersNorth: 0));
    c.switchLayer(far);
    expect(c.activeManifest, far, reason: '不得拒絕換層，否則玩家卡在舊圖層');
    c.ingest(at(metersNorth: 60, second: 1));
    expect(c.state.status.coverage, CoverageState.outside);
  });
}
