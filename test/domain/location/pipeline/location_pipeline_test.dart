import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/movement_event.dart';
import 'package:share_tour/domain/location/models/rejection_reason.dart';
import 'package:share_tour/domain/location/pipeline/location_pipeline.dart';
import '../../../fakes/fake_clock.dart';
import '../../../fakes/fake_map_manifest.dart';

/// FakeMapManifest.linear() 座標系：(24.0, 121.0) → (100, 100)，恰在路網上。
/// 以緯度位移構造精確公尺距離：1 度緯度 ≈ 110574 公尺。
GeoFix at({
  required double metersNorth,
  double accuracy = 20,
  int second = 0,
  SourceMode mode = SourceMode.gps,
  double baseLat = 24.0,
  double lng = 121.0,
}) =>
    GeoFix(
      latitude: baseLat + metersNorth / 110574.0,
      longitude: lng,
      accuracyMeters: accuracy,
      hasAccuracy: true,
      speedMetersPerSecond: 1.4,
      hasSpeed: true,
      speedAccuracy: 0.5,
      hasSpeedAccuracy: true,
      timestampUtc: DateTime.utc(2026, 1, 1).add(Duration(seconds: second)),
      isMocked: false,
      sourceMode: mode,
    );

void main() {
  late FakeMapManifest manifest;
  late LocationPipeline pipeline;

  setUp(() {
    manifest = FakeMapManifest.linear();
    pipeline = LocationPipeline(manifest: manifest, clock: FakeClock());
  });

  test('AC-0.1 範圍外不進入投影', () {
    manifest.resetCallCounts();
    final out = pipeline.ingest(at(metersNorth: 0, baseLat: 80.0, lng: 0.0));
    expect(out.targetPixel, isNull);
    expect(manifest.projectCallCount, 0,
        reason: 'IDW 對範圍外輸入不報錯，只回傳凸包內看似合理的錯點');
  });

  test('AC-0.3 未顯著移動者不進入後續步驟', () {
    pipeline.ingest(at(metersNorth: 0));
    manifest.resetCallCounts();
    final out = pipeline.ingest(at(metersNorth: 15, second: 1));
    expect(out.targetPixel, isNull);
    expect(out.events, isEmpty);
    expect(manifest.projectCallCount, 0);
  });

  test('AC-0.4 virtual 的 Fix 跳過品質閘門', () {
    pipeline.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
    manifest.resetCallCounts();
    // 位移 5000 公尺、間隔 1 秒 → 18000 km/h，遠超速度門檻
    final out = pipeline
        .ingest(at(metersNorth: 5000, second: 1, mode: SourceMode.virtual));
    expect(out.rejection, isNull, reason: '合成資料沒有量測誤差，品質閘門不適用');
    expect(out.targetPixel, isNotNull);
    expect(manifest.projectCallCount, 1);
  });

  test('品質閘門丟棄者不進入其後任何步驟', () {
    manifest.resetCallCounts();
    final out = pipeline.ingest(at(metersNorth: 0, accuracy: 150));
    expect(out.rejection, RejectionReason.accuracy);
    expect(out.targetPixel, isNull);
    expect(out.events, isEmpty);
    expect(manifest.projectCallCount, 0);
  });

  test('顯著位移產生的事件，距離為投影前的地理距離', () {
    pipeline.ingest(at(metersNorth: 0));
    final out = pipeline.ingest(at(metersNorth: 60, second: 1));
    final e = out.events.whereType<DisplacementEvent>().single;
    expect(e.distanceMeters, closeTo(60, 1),
        reason: '不得改用吸附後的像素差反算——兩者差距可達吸附上限，且逐筆累積');
  });

  test('首筆只建立基準，不產生位移事件', () {
    final out = pipeline.ingest(at(metersNorth: 0));
    expect(out.events, isEmpty);
    expect(out.targetPixel, isNull);
  });

  test('診斷計數隨丟棄遞增', () {
    pipeline.ingest(at(metersNorth: 0, accuracy: 150));
    pipeline.ingest(at(metersNorth: 0).copyWith(hasAccuracy: false));
    expect(pipeline.rejectionsByReason[RejectionReason.accuracy], 1);
    expect(pipeline.rejectionsByReason[RejectionReason.unmeasuredAccuracy], 1);
  });
}
