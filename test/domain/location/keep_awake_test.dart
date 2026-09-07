import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/keep_awake.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/location_status.dart';

bool eval({
  SourceMode mode = SourceMode.gps,
  PermissionState permission = PermissionState.ready,
  bool isForeground = true,
  bool featureEnabled = true,
}) =>
    shouldKeepAwake(
      mode: mode,
      permission: permission,
      isForeground: isForeground,
      featureEnabled: featureEnabled,
    );

void main() {
  test('AC-16.1 mode=gps、permission=ready、在前景 → 為真', () {
    expect(eval(), isTrue);
  });

  test('AC-16.2 mode=virtual → 為假', () {
    expect(eval(mode: SourceMode.virtual), isFalse);
  });

  test('AC-16.3 permission 離開 ready → 為假', () {
    expect(eval(permission: PermissionState.approximate), isFalse);
    expect(eval(permission: PermissionState.denied), isFalse);
    expect(eval(permission: PermissionState.serviceDisabled), isFalse);
    expect(eval(permission: PermissionState.deniedForever), isFalse);
    expect(eval(permission: PermissionState.unavailable), isFalse);
  });

  test('AC-16.4 進入背景 → 為假', () {
    expect(eval(isForeground: false), isFalse);
  });

  test('AC-16.6 玩家關閉本功能 → 為假', () {
    expect(eval(featureEnabled: false), isFalse);
  });

  // AC-16.5（powerMode 變 suspended 時維持為真）、AC-16.7（dispose 後釋放）
  // 依賴 powerMode 與 dispose 生命週期，兩者都不是本述詞的輸入——
  // 見 test/state/location/keep_awake_wiring_test.dart。
}
