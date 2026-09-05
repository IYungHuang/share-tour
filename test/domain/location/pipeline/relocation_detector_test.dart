import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/pipeline/relocation_detector.dart';

RelocationDetector detector() => RelocationDetector(
      jumpLimitMeters: 2000,
      jumpSpeedLimitMps: 120 * 1000 / 3600,
    );

RelocationDecision? evaluate({
  double toLat = 25.0,
  Duration interval = const Duration(minutes: 10),
  bool continuous = true,
  RelocationNote note = RelocationNote.realMovement,
}) =>
    detector().evaluate(
      previousLat: 25.0,
      previousLng: 121.0,
      currentLat: toLat,
      currentLng: 121.0,
      interval: interval,
      subscriptionWasContinuous: continuous,
      note: note,
    );

void main() {
  test('AC-7.1 位移 5 公里構成大跨距', () {
    final d = evaluate(toLat: 25.045);
    expect(d, isNotNull);
    expect(d!.distanceMeters, closeTo(5000, 200));
  });

  test('AC-7.2 位移 300 公尺、步行速度 → 不構成', () {
    final d = evaluate(toLat: 25.0027, interval: const Duration(minutes: 4));
    expect(d, isNull);
  });

  test('AC-7.3 酬載帶跨距與速度', () {
    final d = evaluate(toLat: 25.045, interval: const Duration(seconds: 60))!;
    expect(d.distanceMeters, closeTo(5000, 200));
    expect(d.speedMetersPerSecond, closeTo(5000 / 60, 5));
  });

  test('AC-7.4 背景恢復造成的跨距 → discontinuity，附註非空', () {
    final d = evaluate(
      toLat: 25.045,
      interval: const Duration(seconds: 30),
      continuous: false,
      note: RelocationNote.backgroundResume,
    )!;
    expect(d.cause, RelocationCause.discontinuity);
    expect(d.note, RelocationNote.backgroundResume);
  });

  test('AC-7.5 連續追蹤中以 200 km/h 移動 → continuousTracking', () {
    final d = evaluate(toLat: 25.03, interval: const Duration(seconds: 60))!;
    expect(d.cause, RelocationCause.continuousTracking);
    expect(d.speedMetersPerSecond, closeTo(200 * 1000 / 3600, 3));
  });

  test('速度超標但位移小 → 仍構成大跨距', () {
    // 500 公尺 / 5 秒 = 360 km/h > 120 km/h 門檻
    final d = evaluate(toLat: 25.0045, interval: const Duration(seconds: 5));
    expect(d, isNotNull);
  });

  test('成因只由訂閱是否連續決定', () {
    final a = evaluate(toLat: 25.045, continuous: true)!;
    final b = evaluate(toLat: 25.045, continuous: false)!;
    expect(a.cause, RelocationCause.continuousTracking);
    expect(b.cause, RelocationCause.discontinuity);
  });
}
