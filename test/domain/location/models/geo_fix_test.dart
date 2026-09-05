import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';

GeoFix fix({bool hasAccuracy = true, double accuracy = 20}) => GeoFix(
      latitude: 25.034,
      longitude: 121.564,
      accuracyMeters: accuracy,
      hasAccuracy: hasAccuracy,
      speedMetersPerSecond: 1.4,
      hasSpeed: true,
      speedAccuracy: 0.5,
      hasSpeedAccuracy: true,
      timestampUtc: DateTime.utc(2026, 1, 1),
      isMocked: false,
      sourceMode: SourceMode.gps,
    );

void main() {
  test('時戳必須為 UTC', () {
    expect(fix().timestampUtc.isUtc, isTrue);
  });

  test('未量測精度時，旗標與值分開表達', () {
    // 平台在無法量測時回傳 0.0 佔位值。若不帶旗標，下游會把
    // 「未量測」當成「零誤差」，精度閘門與顯著性閘門會同時失效。
    final f = fix(hasAccuracy: false, accuracy: 0);
    expect(f.hasAccuracy, isFalse);
    expect(f.accuracyMeters, 0);
  });

  test('相同內容的兩個實例相等', () {
    expect(fix(), equals(fix()));
  });

  test('copyWith 不改動其他欄位', () {
    final f = fix().copyWith(accuracyMeters: 50);
    expect(f.accuracyMeters, 50);
    expect(f.latitude, 25.034);
  });
}
