import '../models/shot_tier.dart';
import '../models/shutter_difficulty.dart';
import 'framing_penalty.dart';
import 'shutter_input.dart';
import 'shutter_judge.dart';

/// 三態判定與構圖降階的單一對外入口（REQ-M5-04.2 的重用點）。
///
/// 非絕景只走時機判定；絕景先算時機態再套構圖降階。[compositionOffset]
/// 為 `null` 時視為構圖不通過——這是中斷路徑的專用值：中斷沒有放開，
/// $d_c$ 沒有取樣可用，不得把「無法驗證」當作「驗證通過」。
ShotTier resolveShotTier({
  required ShutterInput input,
  required ShutterDifficulty difficulty,
  required bool isSpotlight,
  double? compositionOffset,
}) {
  final timingTier = judgeShutter(input, difficulty);
  if (!isSpotlight) {
    return timingTier;
  }
  final ok = compositionOffset != null &&
      framingOk(compositionOffset, kFramingMaxOffset[difficulty]!);
  return applyFramingPenalty(timingTier, framingOk: ok);
}
