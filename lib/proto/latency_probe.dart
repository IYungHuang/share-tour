/// 端到端延遲量測 —— 回答 v4 §6 待決 1：`decisiveMoment` 的 120 ms 完美窗
/// 是「難但可練」還是「抽獎」。
///
/// 判準（v4 §6 待決 1）：
///
/// > 若實機抖動 σ > 40 ms，則 Wp = 120 ms 判定為抽獎 —— ±60 ms 只有 1.5 個
/// > 抖動標準差，練習改善不了。
///
/// 這是**數據回答，不是感覺判斷**。裝置差異可達 2~3 倍，而它直接決定最高
/// 難度存不存在。
library;

import 'dart:math' as math;

/// 一次「按下 → 畫面更新」的延遲樣本（毫秒）。
///
/// 量法：記錄 `PointerDownEvent.timeStamp`，在**下一個實際上屏的幀**的
/// `SchedulerBinding.currentFrameTimeStamp` 回調裡取差值。
/// 兩者時基不同，故此值只用於**抖動統計**（σ），不用於 QTE 判定 ——
/// 判定一律走 down/up 的指標時戳（v4 REQ-M5-01.3）。
class LatencySample {
  const LatencySample(this.millis);
  final double millis;
}

/// 延遲樣本的滾動統計。
class LatencyStats {
  LatencyStats({this.capacity = 120});

  final int capacity;
  final List<double> _samples = [];

  void add(double millis) {
    if (millis < 0 || millis > 1000) return; // 明顯是量測雜訊，丟棄
    _samples.add(millis);
    if (_samples.length > capacity) _samples.removeAt(0);
  }

  void clear() => _samples.clear();

  int get count => _samples.length;

  double get median {
    if (_samples.isEmpty) return 0;
    final sorted = [..._samples]..sort();
    return sorted[sorted.length ~/ 2];
  }

  double get mean {
    if (_samples.isEmpty) return 0;
    return _samples.reduce((a, b) => a + b) / _samples.length;
  }

  /// 抖動 —— 即判準要看的那個數字。
  double get sigma {
    if (_samples.length < 2) return 0;
    final m = mean;
    final variance = _samples
            .map((x) => (x - m) * (x - m))
            .reduce((a, b) => a + b) /
        (_samples.length - 1);
    return math.sqrt(variance);
  }

  /// 抖動判準的上限（v4 §6 待決 1）。
  static const double jitterCeilingMs = 40;

  /// 樣本數下限 —— 低於此值的 σ 不可信。
  static const int minSamplesForVerdict = 30;

  /// 依 §6 待決 1 的判準給出裁決。
  LatencyVerdict get verdict {
    if (count < minSamplesForVerdict) return LatencyVerdict.insufficientData;
    return sigma > jitterCeilingMs
        ? LatencyVerdict.lottery
        : LatencyVerdict.trainable;
  }

  /// 在當前抖動下，要讓完美窗仍是技巧而非抽獎，所需的最小窗寬。
  ///
  /// 以「窗寬至少涵蓋 ±1.5σ」反推：$W \ge 3\sigma$。
  double get recommendedMinWindowMs =>
      math.max(3 * sigma, ShutterWindowFloor.absolute);
}

/// 完美窗的絕對下限，與 `ShutterParams.minPerfectWindowMs` 同值。
/// 獨立宣告以免本檔相依判定層。
abstract final class ShutterWindowFloor {
  static const double absolute = 120;
}

enum LatencyVerdict {
  /// 樣本不足，尚無法裁決。
  insufficientData,

  /// σ ≤ 40 ms：完美窗是可練的技巧。
  trainable,

  /// σ > 40 ms：完美窗被裝置抖動主導，練習改善不了。
  lottery,
}
