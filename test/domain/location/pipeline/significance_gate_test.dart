import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/pipeline/significance_gate.dart';

/// 以緯度位移構造精確的公尺距離：1 度緯度 ≈ 110574 公尺。
GeoFix atMeters(double metersNorth, {double accuracy = 20, int second = 0}) =>
    GeoFix(
      latitude: 25.0 + metersNorth / 110574.0,
      longitude: 121.0,
      accuracyMeters: accuracy,
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
  test('AC-3.8 精度 20m 兩筆相距 15m → 未顯著，不累計', () {
    final g = SignificanceGate(coefficient: 0.75);
    g.evaluate(atMeters(0));
    expect(g.evaluate(atMeters(15, second: 1)), isNull);
  });

  test('AC-3.8b 相距 60m → 顯著', () {
    final g = SignificanceGate(coefficient: 0.75);
    g.evaluate(atMeters(0));
    final d = g.evaluate(atMeters(60, second: 1));
    expect(d, isNotNull);
    expect(d!, closeTo(60, 1));
  });

  test('AC-3.9 基準凍結：恰有第 3 筆顯著，累計 36m', () {
    final g = SignificanceGate(coefficient: 0.75);
    final significant = <double>[];
    for (var i = 0; i <= 5; i++) {
      final d = g.evaluate(atMeters(i * 12.0, second: i));
      if (d != null) significant.add(d);
    }
    // 門檻 0.75 * (20+20) = 30m。基準凍結在 0m：
    //   12 否、24 否、36 是（基準移到 36）、48 距新基準 12 否、60 距 24 否
    expect(significant.length, 1,
        reason: '基準前移的實作會得到 0 次；每筆都算的實作會得到 5 次');
    expect(significant.single, closeTo(36, 1));
  });

  test('AC-13.5 合成路徑：500m、每 10m 一筆、精度 20m → 累計約 480m', () {
    final g = SignificanceGate(coefficient: 0.75);
    var total = 0.0;
    for (var i = 1; i <= 50; i++) {
      total += g.evaluate(atMeters(i * 10.0, second: i)) ?? 0;
    }
    expect(total, inInclusiveRange(400, 550),
        reason: '基準前移的實作會得到 0，這條是里程「少算」的唯一防線');
  });

  test('精度變差時門檻隨之放寬', () {
    final g = SignificanceGate(coefficient: 0.75);
    g.evaluate(atMeters(0, accuracy: 80));
    // 門檻 0.75 * (80+80) = 120m，故 100m 位移仍不顯著
    expect(g.evaluate(atMeters(100, accuracy: 80, second: 1)), isNull);
  });

  test('reset 後下一筆重新建立基準', () {
    final g = SignificanceGate(coefficient: 0.75);
    g.evaluate(atMeters(0));
    g.reset();
    expect(g.evaluate(atMeters(1000, second: 1)), isNull,
        reason: 'reset 後首筆只建立基準，不產生位移');
  });
}
