import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_tour/data/location/geolocator_location_source.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';

Position position({
  double accuracy = 20,
  bool hasAccuracy = true,
  double speed = 1.4,
  bool hasSpeed = true,
  double speedAccuracy = 0.5,
  bool hasSpeedAccuracy = true,
  bool isMocked = false,
  DateTime? timestamp,
}) =>
    Position(
      longitude: 121.564,
      latitude: 25.034,
      timestamp: timestamp ?? DateTime.utc(2026, 1, 1),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: speedAccuracy,
      isMocked: isMocked,
      hasAccuracy: hasAccuracy,
      hasSpeed: hasSpeed,
      hasSpeedAccuracy: hasSpeedAccuracy,
    );

void main() {
  test('經緯度、精度與速度原樣轉換', () {
    final f = geoFixFromPosition(position());
    expect(f.latitude, 25.034);
    expect(f.longitude, 121.564);
    expect(f.accuracyMeters, 20);
    expect(f.speedMetersPerSecond, 1.4);
    expect(f.sourceMode, SourceMode.gps);
  });

  test('已量測旗標必須原樣帶過，不得推斷', () {
    // 平台在無法量測時回傳 0.0 佔位值。若轉換時丟掉旗標，下游會把
    // 「未量測」當成「零誤差」與「靜止」，同時關掉精度閘門與速度閘門。
    final f = geoFixFromPosition(
        position(hasAccuracy: false, accuracy: 0, hasSpeed: false, speed: 0));
    expect(f.hasAccuracy, isFalse);
    expect(f.hasSpeed, isFalse);
    expect(f.accuracyMeters, 0);
    expect(f.speedMetersPerSecond, 0);
  });

  test('時戳一律轉為 UTC', () {
    final local = DateTime(2026, 1, 1, 12); // 本地時間
    final f = geoFixFromPosition(position(timestamp: local));
    expect(f.timestampUtc.isUtc, isTrue);
    expect(f.timestampUtc, local.toUtc());
  });

  test('isMocked 原樣帶過', () {
    expect(geoFixFromPosition(position(isMocked: true)).isMocked, isTrue);
    expect(geoFixFromPosition(position()).isMocked, isFalse);
  });

  test('平台權限與精度列舉的對應', () {
    expect(mapPlatformPermission(LocationPermission.denied).name, 'denied');
    expect(mapPlatformPermission(LocationPermission.deniedForever).name,
        'deniedForever');
    expect(mapPlatformPermission(LocationPermission.whileInUse).name, 'granted');
    expect(mapPlatformPermission(LocationPermission.always).name, 'granted');
    expect(mapPlatformPermission(LocationPermission.unableToDetermine).name,
        'notDetermined');

    expect(mapPlatformAccuracy(LocationAccuracyStatus.precise).name, 'precise');
    expect(mapPlatformAccuracy(LocationAccuracyStatus.reduced).name, 'reduced');
  });
}
