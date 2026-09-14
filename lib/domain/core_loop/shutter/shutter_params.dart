import '../models/shot_tier.dart';
import '../models/shutter_difficulty.dart';

/// 單一難度的時機參數（REQ-M5-01.8）。
///
/// [normalWindowMs] 為 `null` 表示無上限（`tourist` 的無障礙保障）。
class DifficultyTiming {
  const DifficultyTiming({
    required this.tMatchMs,
    required this.perfectWindowMs,
    required this.normalWindowMs,
    required this.animationLengthMs,
  }) : assert(
         perfectWindowMs >= 120,
         '完美窗硬下限 120 ms（REQ-M5-01.9），行動裝置端到端延遲 60~120 ms',
       ),
       assert(
         normalWindowMs == null || normalWindowMs >= perfectWindowMs,
         '普通窗須不小於完美窗',
       );

  /// 吻合時刻（毫秒），常數，不由動畫幀推算。
  final int tMatchMs;

  /// 完美窗寬（毫秒）。
  final int perfectWindowMs;

  /// 普通窗寬（毫秒）。`null` 表示無上限。
  final int? normalWindowMs;

  /// 動畫全長（毫秒），逾時界線 = tMatchMs 起算的參考點，量在指標軸上。
  final int animationLengthMs;
}

/// 三檔難度的時機參數表（REQ-M5-01.8）。
const Map<ShutterDifficulty, DifficultyTiming> kDifficultyTimings = {
  ShutterDifficulty.tourist: DifficultyTiming(
    tMatchMs: 1400,
    perfectWindowMs: 800,
    normalWindowMs: null,
    animationLengthMs: 2000,
  ),
  ShutterDifficulty.photographer: DifficultyTiming(
    tMatchMs: 1100,
    perfectWindowMs: 160,
    normalWindowMs: 720,
    animationLengthMs: 1600,
  ),
  ShutterDifficulty.decisiveMoment: DifficultyTiming(
    tMatchMs: 800,
    perfectWindowMs: 120,
    normalWindowMs: 300,
    animationLengthMs: 1200,
  ),
};

/// 三態係數三元組：(failed, normal, perfect)。`normal` 恆為 1.00。
typedef TierFactorTriple = (double failed, double normal, double perfect);

/// 非絕景 `tierFactor` 表（REQ-M5-02.3）。
const Map<ShutterDifficulty, TierFactorTriple> kNonSpotlightTierFactor = {
  ShutterDifficulty.tourist: (0.90, 1.00, 1.05),
  ShutterDifficulty.photographer: (0.72, 1.00, 1.22),
  ShutterDifficulty.decisiveMoment: (0.62, 1.00, 1.70),
};

/// 絕景專屬 `tierFactor` 表（v7 定案，REQ-M5-02.3）。
///
/// `tourist` 沿用非絕景表——其 `normalWindowMs` 無上限恆無 `failed`，
/// 絕景在其上只讓完美率降低但不產生風險反轉，不需要獨立表。
const Map<ShutterDifficulty, TierFactorTriple> kSpotlightTierFactor = {
  ShutterDifficulty.tourist: (0.90, 1.00, 1.05),
  ShutterDifficulty.photographer: (0.938, 1.00, 1.292),
  ShutterDifficulty.decisiveMoment: (0.735, 1.00, 2.031),
};

/// 依難度與是否絕景查表取得 `tierFactor`。
double tierFactorFor(
  ShutterDifficulty difficulty,
  ShotTier tier, {
  required bool isSpotlight,
}) {
  final table = isSpotlight ? kSpotlightTierFactor : kNonSpotlightTierFactor;
  final (failed, normal, perfect) = table[difficulty]!;
  return switch (tier) {
    ShotTier.failed => failed,
    ShotTier.normal => normal,
    ShotTier.perfect => perfect,
  };
}
