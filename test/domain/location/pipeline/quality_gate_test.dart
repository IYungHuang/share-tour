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

  test('min() 的後果：裝置回報低速時，大跨距不被速度規則丟棄', () {
    // 規格 REQ-C-03 規則 5 明訂取兩者較小值，理由是裝置的多普勒速度在短
    // 間隔下比兩點差分可靠。代價是：兩者必須【都】超標才會丟棄，
    // 所以「跳了一公里但裝置說我在走路」會通過這道閘門。
    //
    // 這條測試把該取捨釘成可見的行為，而不是留給日後的人意外發現。
    // 真正擋住這種情形的是顯著位移閘門之後的大跨距偵測（REQ-C-07）。
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    final r = g.evaluate(f(lat: 25.009, speed: 1.4, secondsFromEpoch: 1));
    expect(r, isA<Accepted>());
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

  test('AC-3.10 裝置 speed 已量測時取較小值', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    final r = g.evaluate(f(lat: 25.0027, speed: 2, secondsFromEpoch: 1));
    expect(r, isA<Accepted>());
  });

  test('AC-3.11 裝置 speed 未量測時只用兩點差分', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    final r = g.evaluate(
        f(lat: 25.009, speed: 0, hasSpeed: false, secondsFromEpoch: 1));
    expect(r, isA<Rejected>(), reason: '佔位 0.0 不得讓速度閘門失效');
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
