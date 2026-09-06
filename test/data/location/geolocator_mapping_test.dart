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

  // --- Android 平台旗標修復 ---
  //
  // geolocator_android 的 AndroidPosition.fromMap 先用 Position.fromMap 算出
  // 正確的 has* 旗標，接著只把數值欄位搬進 AndroidPosition 的建構子——而該
  // 建構子沒有 has* 參數，於是旗標全部掉回父類預設 false。Android 上因此
  // 每一筆 Fix 都是 hasAccuracy=false，實測 100% 被 REQ-C-03 規則 1 丟棄。
  // （iOS 走 Position.fromMap，旗標正確；這是 Android 獨有的缺陷。）
  //
  // 資訊沒有真的遺失：LocationMapper.java 對每個選用欄位都是
  // `if (location.hasAccuracy()) position.put("accuracy", ...)`，平台沒測到
  // 就整個省略 key，Dart 端補 0.0。所以「值非零」等價於「量測過」。

  test('精度旗標為 false 但值非零 → 視為已量測（修復 Android 掉旗標）', () {
    final f = geoFixFromPosition(position(hasAccuracy: false, accuracy: 24.5));
    expect(f.hasAccuracy, isTrue);
    expect(f.accuracyMeters, 24.5);
  });

  test('速度旗標為 false 但值非零 → 視為已量測', () {
    final f = geoFixFromPosition(
        position(hasSpeed: false, speed: 1.4, hasSpeedAccuracy: false));
    expect(f.hasSpeed, isTrue);
    expect(f.hasSpeedAccuracy, isTrue);
  });

  test('旗標為 true 時不因值為 0 而被推翻', () {
    final f = geoFixFromPosition(
        position(hasAccuracy: true, accuracy: 0, hasSpeed: true, speed: 0));
    expect(f.hasAccuracy, isTrue);
    expect(f.hasSpeed, isTrue);
  });

  test('速度恰為 0 且旗標為 false → 仍視為未量測（安全方向）', () {
    // 靜止時速度真的是 0.0，無法與「未量測」區分。判為未量測只會讓裝置
    // 速度不參與 REQ-C-03 規則 5 的交叉檢查，兩點差分照常——這正是規格
    // 對未量測速度規定的行為。
    final f = geoFixFromPosition(position(hasSpeed: false, speed: 0));
    expect(f.hasSpeed, isFalse);
  });

}
