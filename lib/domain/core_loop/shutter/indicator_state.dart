import '../models/shutter_difficulty.dart';
import 'shutter_params.dart';
import 'visual_elapsed_ms.dart';

/// 收縮指示的可讀狀態（REQ-M5-01.13）。
///
/// 這條純函式吃的是視覺經過時間（[VisualElapsedMs]），不是判定用的
/// [HeldMs]——REQ-M5-01.5 未被鬆綁：視覺可用 dt，判定不可用。
/// 兩者型別不相容（AC-M5-1.13），杜絕順手把視覺 elapsed 餵進判定路徑。
enum IndicatorState { beforeMatch, pastMatch, timedOut }

/// [visualElapsedMs] 達 [DifficultyTiming.animationLengthMs] 前恆為
/// `beforeMatch`；到達吻合時刻起改為 `pastMatch`（事後資訊，AC-M5-11.5）；
/// 到達動畫全長判 `timedOut`。三段之間不存在「進入完美窗提前變色」的分支
/// ——完美窗邊界不出現在本函式的任何比較式裡（AC-M5-11.7）。
IndicatorState indicatorState(
  VisualElapsedMs visualElapsedMs,
  ShutterDifficulty difficulty,
) {
  final timing = kDifficultyTimings[difficulty]!;
  final elapsed = visualElapsedMs.value;
  if (elapsed >= timing.animationLengthMs) {
    return IndicatorState.timedOut;
  }
  if (elapsed >= timing.tMatchMs) {
    return IndicatorState.pastMatch;
  }
  return IndicatorState.beforeMatch;
}
