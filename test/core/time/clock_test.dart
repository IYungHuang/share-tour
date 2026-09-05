import 'package:flutter_test/flutter_test.dart';
import '../../fakes/fake_clock.dart';

void main() {
  test('單調時間不受牆鐘調整影響', () {
    final clock = FakeClock();
    final before = clock.elapsed;

    // 使用者把系統時間往回調一天
    clock.setWallClock(clock.nowUtc().subtract(const Duration(days: 1)));
    clock.advance(const Duration(seconds: 30));

    expect(clock.elapsed - before, const Duration(seconds: 30),
        reason: '調整牆鐘不得影響已經過的單調時間');
  });

  test('牆鐘一律為 UTC', () {
    final clock = FakeClock();
    expect(clock.nowUtc().isUtc, isTrue);
  });

  test('單調時間只增不減', () {
    final clock = FakeClock();
    final t0 = clock.elapsed;
    clock.advance(const Duration(milliseconds: 1));
    expect(clock.elapsed, greaterThan(t0));
  });

  test('delay 由假時鐘驅動，不需真實等待', () async {
    final clock = FakeClock();
    var fired = false;
    final f = clock.delay(const Duration(seconds: 5)).then((_) => fired = true);
    expect(fired, isFalse);
    clock.advance(const Duration(seconds: 5));
    await f;
    expect(fired, isTrue);
  });
}
