import '../models/shot_tier.dart';
import '../models/shutter_difficulty.dart';
import 'shutter_input.dart';
import 'shutter_params.dart';

/// 三態判定純函式（REQ-M5-01.3）。
///
/// 給定難度與輸入，結果唯一確定（CC-3）。不讀取幀時間或系統時鐘——
/// [Pressed] 的 [HeldMs] 已經是兩個指標時戳的差，[TimedOut] 不帶時間，
/// 兩者都與「現在幾點」無關。
ShotTier judgeShutter(ShutterInput input, ShutterDifficulty difficulty) {
  if (input is TimedOut) {
    return ShotTier.failed;
  }
  final pressed = input as Pressed;
  final timing = kDifficultyTimings[difficulty]!;
  final deltaMs = (pressed.heldMs.toInt() - timing.tMatchMs).abs();

  if (deltaMs <= timing.perfectWindowMs / 2) {
    return ShotTier.perfect;
  }
  final normalWindow = timing.normalWindowMs;
  if (normalWindow == null || deltaMs <= normalWindow / 2) {
    return ShotTier.normal;
  }
  return ShotTier.failed;
}
