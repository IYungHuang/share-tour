import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/pipeline/location_pipeline.dart';
import 'package:share_tour/domain/location/trigger_suitability.dart';

/// REQ-C-18 規則 1：三個具名門檻參數，目前同值 30m。不共用同一個常數宣告
/// ——隱式共用同一個值的風險是日後放寬其中一個時，另兩個會被誤以為連動改了。
void main() {
  test('三個具名門檻參數目前相等（相等性斷言，非共用宣告）', () {
    expect(triggerSuitabilityThreshold, mileageQualityThreshold);
    expect(gridEligibilityThreshold, mileageQualityThreshold);
  });

  test('AC-18.1 精度 30m 的 Fix 標記為適用；30.1m 不適用', () {
    expect(isTriggerSuitable(30), isTrue, reason: '門檻值本身視為合格');
    expect(isTriggerSuitable(30.1), isFalse);
  });
}
