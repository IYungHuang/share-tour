import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/domain/core_loop/shutter/indicator_state.dart';
import 'package:share_tour/domain/core_loop/shutter/visual_elapsed_ms.dart';

void main() {
  group('AC-M5-11.5: 逾時事前告知', () {
    test('過 tMatch 之後回 pastMatch，之前回 beforeMatch', () {
      // decisiveMoment tMatch=800
      expect(
        indicatorState(
          const VisualElapsedMs(799),
          ShutterDifficulty.decisiveMoment,
        ),
        IndicatorState.beforeMatch,
      );
      expect(
        indicatorState(
          const VisualElapsedMs(800),
          ShutterDifficulty.decisiveMoment,
        ),
        IndicatorState.pastMatch,
      );
      expect(
        indicatorState(
          const VisualElapsedMs(801),
          ShutterDifficulty.decisiveMoment,
        ),
        IndicatorState.pastMatch,
      );
    });

    test('達動畫全長判 timedOut（animationLengthMs=1200）', () {
      expect(
        indicatorState(
          const VisualElapsedMs(1200),
          ShutterDifficulty.decisiveMoment,
        ),
        IndicatorState.timedOut,
      );
    });
  });

  group('AC-M5-11.7: 不得預告完美窗（區間不變量）', () {
    test('1 ms 步長掃 [0, tMatch) 恆為 beforeMatch，即使跨越完美窗邊界', () {
      // decisiveMoment tMatch=800, Wp=120 → 完美窗邊界在 740。
      for (var ms = 0; ms < 800; ms++) {
        expect(
          indicatorState(
            VisualElapsedMs(ms),
            ShutterDifficulty.decisiveMoment,
          ),
          IndicatorState.beforeMatch,
          reason: 'ms=$ms 在 tMatch 之前，不得預告完美窗',
        );
      }
    });
  });
}
