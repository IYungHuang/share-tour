import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/core/build_flags.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/data/location/virtual_location_source.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_map_manifest.dart';

void main() {
  late FakeClock clock;
  late FakeMapManifest manifest;
  late VirtualLocationSource source;

  setUp(() {
    clock = FakeClock();
    manifest = FakeMapManifest.linear(); // dpadSpeedPixelsPerSecond = 40
    source = VirtualLocationSource(manifest: manifest, clock: clock, hertz: 15);
  });

  /// 推進 n 個 tick，每個 tick 讓非同步迴圈跑一輪。
  ///
  /// 間隔取自來源本身，不自行推導：差一微秒就會與內部的到期時間錯開每一拍。
  Future<void> tick(int n) async {
    for (var i = 0; i < n; i++) {
      await clock.advanceAsync(source.interval);
    }
  }

  test('AC-10.2 方向鍵 10 秒產生約 150 筆，位移符合圖層宣告速度', () async {
    final received = <GeoFix>[];
    final sub = source.fixes.listen(received.add);
    await source.start();
    source.setDirection(Vector2(1, 0));
    await tick(150);
    await sub.cancel();
    await source.stop();

    expect(received.length, inInclusiveRange(145, 155));
    final first = manifest.projectToPixel(
        received.first.latitude, received.first.longitude);
    final last =
        manifest.projectToPixel(received.last.latitude, received.last.longitude);
    expect((last - first).length, closeTo(40 * 10, 25),
        reason: '40 px/s × 10 s = 400 px');
  });

  test('AC-10.1 點擊尋路：反投影往返誤差 < 2 像素', () async {
    final received = <GeoFix>[];
    final sub = source.fixes.listen(received.add);
    await source.start();
    source.tapNavigateTo(Vector2(120, 140));
    await tick(1);
    await sub.cancel();
    await source.stop();

    expect(received, isNotEmpty);
    final back = manifest.projectToPixel(
        received.last.latitude, received.last.longitude);
    expect((back - Vector2(120, 140)).length, lessThan(2.0));
  });

  test('AC-10.5 每筆 Fix 的 sourceMode 為 virtual', () async {
    final received = <GeoFix>[];
    final sub = source.fixes.listen(received.add);
    await source.start();
    source.setDirection(Vector2(0, 1));
    await tick(5);
    await sub.cancel();
    await source.stop();

    expect(received, isNotEmpty);
    expect(received.every((f) => f.sourceMode == SourceMode.virtual), isTrue);
  });

  test('AC-10.4 release 旗標下除錯工廠回傳 null', () {
    expect(
      debugSourceFactory(
          flags: const BuildFlags.release(), manifest: manifest, clock: clock),
      isNull,
    );
    expect(
      debugSourceFactory(
          flags: const BuildFlags.debug(), manifest: manifest, clock: clock),
      isNotNull,
    );
  });

  test('虛擬 Fix 的精度已量測且為小值', () async {
    final received = <GeoFix>[];
    final sub = source.fixes.listen(received.add);
    await source.start();
    source.setDirection(Vector2(1, 0));
    await tick(1);
    await sub.cancel();
    await source.stop();

    expect(received.first.hasAccuracy, isTrue);
    expect(received.first.accuracyMeters, lessThan(5));
  });

  test('停止移動後不再產生新的位移', () async {
    final received = <GeoFix>[];
    final sub = source.fixes.listen(received.add);
    await source.start();
    source.setDirection(Vector2(1, 0));
    await tick(5);
    source.stopMoving();
    final atStop = manifest.projectToPixel(
        received.last.latitude, received.last.longitude);
    await tick(5);
    await sub.cancel();
    await source.stop();

    final atEnd = manifest.projectToPixel(
        received.last.latitude, received.last.longitude);
    expect((atEnd - atStop).length, lessThan(0.001));
  });
}
