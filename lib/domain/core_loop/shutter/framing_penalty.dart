import '../models/shot_tier.dart';
import '../models/shutter_difficulty.dart';

/// 絕景構圖偏差的門檻（取景框邊長比例，0.0~1.0，REQ-M5-03.5 待決 2 定案）。
///
/// 難度愈高門檻愈嚴——`decisiveMoment` 的動作本身已經很趕，構圖不該同時
/// 也是三檔中最嚴的。
const Map<ShutterDifficulty, double> kFramingMaxOffset = {
  ShutterDifficulty.tourist: 0.25,
  ShutterDifficulty.photographer: 0.18,
  ShutterDifficulty.decisiveMoment: 0.12,
};

/// 構圖是否通過（REQ-M5-03.5）：偏移量須不超過該難度的門檻。
bool framingOk(double compositionOffset, double maxOffset) =>
    compositionOffset <= maxOffset;

/// 構圖降階（REQ-M5-03.5）：不通過時最終態較時機態降一階，
/// `perfect → normal`、`normal → failed`、`failed → failed`。
ShotTier applyFramingPenalty(ShotTier timingTier, {required bool framingOk}) {
  if (framingOk) return timingTier;
  return switch (timingTier) {
    ShotTier.perfect => ShotTier.normal,
    ShotTier.normal => ShotTier.failed,
    ShotTier.failed => ShotTier.failed,
  };
}
