import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/domain/location/pipeline/motion_tracker.dart';
import '../../../fakes/fake_clock.dart';

void main() {
  late FakeClock clock;
  late MotionTracker tracker;

  setUp(() {
    clock = FakeClock();
    tracker = MotionTracker(
      clock: clock,
      stillAfter: const Duration(seconds: 30),
      acquiringAfter: const Duration(seconds: 45),
    );
  });

  test('初始為 still 與 acquiring（AC-14.10）', () {
    expect(tracker.motion, MotionState.still);
    expect(tracker.acquisition, AcquisitionState.acquiring);
  });

  test('AC-14.4 完全不推送任何 Fix，30 秒後為 still', () {
    tracker.onSignificantMove();
    expect(tracker.motion, MotionState.moving);
    clock.advance(const Duration(seconds: 31));
    expect(tracker.motion, MotionState.still,
        reason: '平台在玩家靜止時根本不推 Fix，'
            '用 Fix 到達判定在真機永遠不會變 still');
  });

  test('AC-14.5 出現顯著位移即回到 moving', () {
    clock.advance(const Duration(seconds: 60));
    expect(tracker.motion, MotionState.still);
    tracker.onSignificantMove();
    expect(tracker.motion, MotionState.moving);
  });

  test('AC-14.8 取得首筆被接受的 Fix → acquired；45 秒後回到 acquiring', () {
    tracker.onAcceptedFix();
    expect(tracker.acquisition, AcquisitionState.acquired);
    clock.advance(const Duration(seconds: 46));
    expect(tracker.acquisition, AcquisitionState.acquiring);
  });

  test('AC-14.9 Fix 全被丟棄達 45 秒 → acquiring（地下街情境）', () {
    tracker.onAcceptedFix();
    // 期間有推送但全被品質閘門丟棄，故不呼叫 onAcceptedFix
    clock.advance(const Duration(seconds: 46));
    expect(tracker.acquisition, AcquisitionState.acquiring);
  });

  test('門檻值本身視為未逾時', () {
    tracker.onSignificantMove();
    clock.advance(const Duration(seconds: 30));
    expect(tracker.motion, MotionState.moving);
  });
}
