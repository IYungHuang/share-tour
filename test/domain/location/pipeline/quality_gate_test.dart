import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/rejection_reason.dart';
import 'package:share_tour/domain/location/pipeline/quality_gate.dart';

GeoFix f({
  double lat = 25.0,
  double lng = 121.0,
  double accuracy = 20,
  bool hasAccuracy = true,
  double speed = 1.4,
  bool hasSpeed = true,
  int secondsFromEpoch = 0,
}) =>
    GeoFix(
      latitude: lat,
      longitude: lng,
      accuracyMeters: accuracy,
      hasAccuracy: hasAccuracy,
      speedMetersPerSecond: speed,
      hasSpeed: hasSpeed,
      speedAccuracy: 0.5,
      hasSpeedAccuracy: true,
      timestampUtc: DateTime.utc(2026, 1, 1).add(Duration(seconds: secondsFromEpoch)),
      isMocked: false,
      sourceMode: SourceMode.gps,
    );

QualityGate gate() => QualityGate(
      accuracyLimitMeters: 100,
      maxSpeedMetersPerSecond: 350 * 1000 / 3600,
      clockAnomalyThreshold: const Duration(days: 1),
      consecutiveRejectLimit: 5,
    );

void main() {
  test('AC-3.1 精度門檻含入', () {
    expect(gate().evaluate(f(accuracy: 150)), isA<Rejected>());
    expect(gate().evaluate(f(accuracy: 20)), isA<Accepted>());
    expect(gate().evaluate(f(accuracy: 100)), isA<Accepted>(),
        reason: '門檻值本身視為合格');
  });

  test('AC-3.2 精度未量測一律丟棄', () {
    final r = gate().evaluate(f(hasAccuracy: false, accuracy: 0));
    expect(r, isA<Rejected>());
    expect((r as Rejected).reason, RejectionReason.unmeasuredAccuracy);
  });

  test('AC-3.3 速度不合理丟棄', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    // 裝置回報的速度與兩點差分一致（都很高）——這才是真正的漂移長相。
    final r = g.evaluate(f(lat: 25.009, speed: 1000, secondsFromEpoch: 1));
    expect((r as Rejected).reason, RejectionReason.speed);
  });

  test('修訂五：裝置回報低速不再豁免速度閘門（F4，不再取 min）', () {
    // 都卜勒解算與位置解算共用同一組衛星幾何，裝置回報速度不是獨立證據源
    // （實測：手機靜止時裝置回報速度中位數 1.85 m/s、最大 14.08 m/s）。
    // 取小值只會讓速度閘門更難丟棄——一個亂報低速的裝置可以整條關掉
    // 350 km/h 閘門。改為僅用兩點差分後，「跳了一公里但裝置說我在走路」
    // 必須被丟棄。
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    final r = g.evaluate(f(lat: 25.009, speed: 1.4, secondsFromEpoch: 1));
    expect((r as Rejected).reason, RejectionReason.speed);
  });

  test('AC-3.4 時戳回捲丟棄', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 10));
    final r = g.evaluate(f(secondsFromEpoch: 5));
    expect((r as Rejected).reason, RejectionReason.timestamp);
  });

  test('AC-3.5 連續丟棄 5 筆後，第 6 筆接受並重置基準', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    for (var i = 1; i <= 5; i++) {
      expect(
          g.evaluate(
              f(lat: 25.0 + i * 0.01, speed: 1000, secondsFromEpoch: i)),
          isA<Rejected>());
    }
    expect(g.evaluate(f(lat: 25.06, speed: 1000, secondsFromEpoch: 6)),
        isA<Accepted>());
  });

  test('AC-3.6 強制接受僅豁免速度規則，精度仍生效', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    for (var i = 1; i <= 5; i++) {
      g.evaluate(f(lat: 25.0 + i * 0.01, speed: 1000, secondsFromEpoch: i));
    }
    final r = g.evaluate(
        f(lat: 25.06, accuracy: 200, speed: 1000, secondsFromEpoch: 6));
    expect(r, isA<Rejected>());
    expect((r as Rejected).reason, RejectionReason.accuracy);
  });

  test('AC-3.7 時鐘異常重置基準而非丟棄', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    final r = g.evaluate(f(secondsFromEpoch: -2 * 86400));
    expect(r, isA<Accepted>(),
        reason: '時鐘被調整時應重置基準，否則後續全被單調性規則丟棄');
  });

  test('規則 9：首筆不受速度規則約束', () {
    expect(gate().evaluate(f()), isA<Accepted>());
  });

  test('resetBaseline 後下一筆視同首筆', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    g.resetBaseline();
    expect(g.evaluate(f(lat: 26.0, secondsFromEpoch: 1)), isA<Accepted>());
  });
}
