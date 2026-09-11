import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/core/engine_pause_coordinator.dart';

void main() {
  group('巢狀彈窗引擎暫停協調 (AC-M4-4.4)', () {
    late List<String> log;
    late EnginePauseCoordinator coordinator;

    setUp(() {
      log = [];
      coordinator = EnginePauseCoordinator(
        onPause: () => log.add('pause'),
        onResume: () => log.add('resume'),
      );
    });

    test('第一次取得暫停才呼叫 onPause，巢狀取得不重複呼叫', () {
      coordinator.acquire();
      coordinator.acquire();

      expect(log, ['pause']);
      expect(coordinator.refCount, 2);
      expect(coordinator.isPaused, isTrue);
    });

    test('巢狀彈窗：只有最後一層釋放才恢復引擎', () {
      // 行前委託彈窗 → 由它開啟黑市彈窗
      coordinator.acquire();
      coordinator.acquire();

      coordinator.release(); // 黑市關閉，委託仍開著
      expect(log, ['pause']);
      expect(coordinator.isPaused, isTrue);

      coordinator.release(); // 委託關閉
      expect(log, ['pause', 'resume']);
      expect(coordinator.isPaused, isFalse);
    });

    test('多餘的釋放不得使計數為負，也不得重複恢復', () {
      coordinator.acquire();
      coordinator.release();
      coordinator.release();
      coordinator.release();

      expect(log, ['pause', 'resume']);
      expect(coordinator.refCount, 0);
    });

    test('恢復之後可再次暫停', () {
      coordinator.acquire();
      coordinator.release();
      coordinator.acquire();

      expect(log, ['pause', 'resume', 'pause']);
      expect(coordinator.isPaused, isTrue);
    });

    test('尚未取得時釋放不觸發任何回呼', () {
      coordinator.release();

      expect(log, isEmpty);
      expect(coordinator.refCount, 0);
    });

    test('回呼拋出例外時計數仍保持正確，不會卡在永久暫停', () {
      final crashing = EnginePauseCoordinator(
        onPause: () => throw StateError('引擎尚未附著'),
        onResume: () {},
      );

      expect(crashing.acquire, throwsA(isA<StateError>()));
      // 計數必須已經遞增，否則對應的 release 會讓狀態錯位
      expect(crashing.refCount, 1);
    });
  });
}
