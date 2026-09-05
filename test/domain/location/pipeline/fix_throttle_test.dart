import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/pipeline/fix_throttle.dart';
import '../../../fakes/fake_clock.dart';

GeoFix at({int second = 0, SourceMode mode = SourceMode.gps}) => GeoFix(
      latitude: 24.0,
      longitude: 121.0,
      accuracyMeters: 20,
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
  late FakeClock clock;
  late FixThrottle throttle;
  late List<GeoFix> out;

  setUp(() {
    clock = FakeClock();
    throttle = FixThrottle(clock: clock, window: const Duration(seconds: 1));
    out = [];
    throttle.output.listen(out.add);
  });

  tearDown(() => throttle.dispose());

  test('AC-2.1 以 2 秒間隔推送 5 筆 → 收到 5 筆，順序內容一致', () async {
    for (var i = 0; i < 5; i++) {
      throttle.add(at(second: i * 2));
      await clock.advanceAsync(const Duration(seconds: 2));
    }
    expect(out.length, 5);
    expect(out.map((f) => f.timestampUtc.second).toList(), [0, 2, 4, 6, 8]);
  });

  test('AC-2.2 1 秒內推送 10 筆 → 收到 2 筆：第 1 筆與窗尾最新筆', () async {
    for (var i = 0; i < 10; i++) {
      throttle.add(at(second: i));
      await clock.advanceAsync(const Duration(milliseconds: 90));
    }
    await clock.advanceAsync(const Duration(seconds: 1));
    expect(out.length, 2);
    expect(out.first.timestampUtc.second, 0, reason: 'leading 立即放行');
    expect(out.last.timestampUtc.second, 9,
        reason: '窗尾補發的必須是最新那筆，不是第 2 筆');
  });

  test('AC-10.6 虛擬來源的 Fix 不被合併', () async {
    for (var i = 0; i < 10; i++) {
      throttle.add(at(second: i, mode: SourceMode.virtual));
      await clock.advanceAsync(const Duration(milliseconds: 10));
    }
    expect(out.length, 10);
  });
}
