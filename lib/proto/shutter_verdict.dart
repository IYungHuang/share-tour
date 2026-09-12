/// 快門 QTE 的三態判定 —— 純 Dart，零框架相依。
///
/// 對應 `SPEC_MVP_MICRO_ACTION.md` v4 REQ-M5-01。這是丟棄式原型，目的是產出
/// 一組可用的調校參數與「這個機制成不成立」的判斷，不是 M5 的第一塊實作。
///
/// 判定以**時間**為準，收縮環是純表現（REQ-M5-01.3）。
library;

/// 三態。完整且互斥，不存在第四種結果（REQ-M5-01.1）。
enum ShutterTier { perfect, normal, failed }

/// 難度三檔（REQ-M5-05.1）。採攝影師語彙而非難度形容詞。
enum ShutterDifficulty { tourist, photographer, decisiveMoment }

/// QTE 的輸入。
///
/// 逾時在型別上是**輸入的一種**，不是 [Pressed.offsetMs] 的極值
/// （REQ-M5-01.7）—— 否則 `tourist` 的無上限普通窗會把逾時判成 `normal`。
sealed class ShutterInput {
  const ShutterInput();
}

/// 玩家放開了手指。[offsetMs] 為與吻合時刻的偏差絕對值。
final class Pressed extends ShutterInput {
  const Pressed(this.offsetMs) : assert(offsetMs >= 0);
  final int offsetMs;
}

/// 動畫全長結束仍未放開。
final class TimedOut extends ShutterInput {
  const TimedOut();
}

/// 單一難度的 QTE 參數（毫秒）。
///
/// 難度**同時縮放動畫全長**，不只縮放窗寬 —— 無障礙的門檻是「按得到」而非
/// 「按得準」（REQ-M5-01.8）。
class ShutterParams {
  const ShutterParams({
    required this.matchMs,
    required this.perfectWindowMs,
    required this.normalWindowMs,
    required this.totalMs,
  })  : assert(
          perfectWindowMs >= minPerfectWindowMs,
          '完美窗不得低於 $minPerfectWindowMs ms：行動裝置的端到端延遲本身就有'
          '數十毫秒抖動，低於此下限的判定是抽獎而非技巧',
        ),
        assert(
          normalWindowMs == null || normalWindowMs >= perfectWindowMs,
          '普通窗不得窄於完美窗',
        );

  /// 完美窗硬下限（REQ-M5-01.9）。
  static const int minPerfectWindowMs = 120;

  /// 吻合時刻，自按下起算。
  final int matchMs;

  /// 完美窗總寬度。
  final int perfectWindowMs;

  /// 普通窗總寬度。`null` 表示不設上限 —— 只要放開就不可能 `failed`（逾時除外）。
  final int? normalWindowMs;

  /// 動畫全長。逾時界線。
  final int totalMs;

  /// 單次 QTE 儀式的邏輯時間上限 = 動畫全長 + 轉場與浮字（REQ-M5-09.1）。
  static const int ceremonyOverheadMs = 1200;
  int get ceremonyMs => totalMs + ceremonyOverheadMs;
}

/// v4 REQ-M5-01.8 的初始值。**待實機調校**（v4 §6 待決 1）。
const shutterParamTable = <ShutterDifficulty, ShutterParams>{
  ShutterDifficulty.tourist: ShutterParams(
    matchMs: 1400,
    perfectWindowMs: 800,
    normalWindowMs: null,
    totalMs: 2000,
  ),
  ShutterDifficulty.photographer: ShutterParams(
    matchMs: 1100,
    perfectWindowMs: 240,
    normalWindowMs: 720,
    totalMs: 1600,
  ),
  ShutterDifficulty.decisiveMoment: ShutterParams(
    matchMs: 800,
    perfectWindowMs: 120,
    normalWindowMs: 300,
    totalMs: 1200,
  ),
};

/// 判定為純函式：給定難度與輸入，結果唯一確定。
///
/// 不依賴當下時間、亂數或外部狀態（CC-3 / REQ-M5-01.11）。
ShutterTier judgeShutter(ShutterDifficulty difficulty, ShutterInput input) {
  // 逾時優先於一切難度參數。否則最低難度會退化為「不按也能拿普通版」，
  // 等同已排除的跳過機制（REQ-M5-01.7）。
  if (input is TimedOut) return ShutterTier.failed;

  final params = shutterParamTable[difficulty]!;
  final offset = (input as Pressed).offsetMs;

  if (offset <= params.perfectWindowMs / 2) return ShutterTier.perfect;

  final normal = params.normalWindowMs;
  if (normal == null || offset <= normal / 2) return ShutterTier.normal;

  return ShutterTier.failed;
}

/// 絕景的構圖是**二元**判定：通過則最終態等於時機態，不通過則下降一階
/// （REQ-M5-03.5）。
///
/// 「取兩者較差」會使絕景失手率約為一般卡的 7.8 倍，而絕景幅度最大、
/// 階梯是網紅端最大槓桿，京都又只有 5 張。
ShutterTier applyFramingPenalty(ShutterTier timing, {required bool framingOk}) {
  if (framingOk) return timing;
  return switch (timing) {
    ShutterTier.perfect => ShutterTier.normal,
    ShutterTier.normal => ShutterTier.failed,
    ShutterTier.failed => ShutterTier.failed,
  };
}
