/// 輸入抖動量測 —— 回答 v4 §6 待決 1：`decisiveMoment` 的 120 ms 完美窗
/// 是「難但可練」還是「抽獎」。
///
/// 判準（v4 §6 待決 1）：完美窗須 $\ge 3\sigma$，且不低於 120 ms 的絕對下限。
///
/// **實測修正史**：第一版用 σ 當主統計，結果 n=32 時得 12.8 ms、n=69 時得
/// 40.2 ms —— 3 倍跳幅。原因是 σ 對離群值極度敏感，而「閒置之後的第一次按壓」
/// 會帶著主 isolate 從空閒喚醒的延遲。故改用**穩健統計**（MAD）為主，σ 僅
/// 併列參考。
///
/// 第二版另外排除了閒置後的第一筆，門檻 1500 ms —— **那是錯的，已移除**。
/// 實測每次 15.1 s，42 筆裡 39 筆被丟棄，n 只剩 3。門檻設在人的再進入時間
/// （看結果、重新握好、決定再按，實測 3.8~6.4 s）以下，於是永遠通不過。
/// 且方向也錯：兩次取材之間玩家要走路，「閒置後按下」正是遊戲內的典型情境，
/// 排除它會讓抖動估計偏樂觀。現在全部收下，靠 MAD 擋離群值。
library;

import 'dart:math' as math;

/// 抖動樣本的滾動統計。
///
/// 量的是「指標事件時戳」與「本地單調時鐘」之差的離散度。兩者 epoch 不同
/// （前者自裝置開機、後者自 App 啟動），故絕對值無意義，只有離散度有意義。
///
/// **已知污染**：讀取本地時鐘發生在 Dart 處理事件時，故差值含主 isolate 的
/// 排程延遲，其量化誤差達一整個幀週期（60 Hz 下 16.7 ms）。所以本量測是
/// 「輸入延遲 + 排程延遲」的上界，不是純輸入抖動 —— 用它下「窗寬夠不夠」
/// 的結論是保守的（偏嚴），這個方向是安全的。
class JitterStats {
  JitterStats({this.capacity = 240});

  final int capacity;
  final List<double> _samples = [];

  /// 第一筆的絕對差值，當作基準扣掉。
  ///
  /// 指標時戳的 epoch 是裝置開機時間，本地 `Stopwatch` 的 epoch 是 App 啟動 ——
  /// 兩者相差整個開機時長（可達數億毫秒）。不先扣基準，任何以絕對值為界的
  /// 濾波都會把全部樣本丟掉（實際踩過：n 一直是 0）。
  double? _baseline;

  /// 連續按壓的子集：與前一筆間隔在 [idleGap] 之內者。
  ///
  /// **不參與裁決**，只作對照 —— 它與全樣本的差距就是「閒置喚醒延遲」的量。
  /// 兩者分歧大，代表遊戲內的走路間隔會實質推高抖動。
  final List<double> _continuous = [];

  /// 上一次收樣的本地時刻，用於分辨連續與閒置。
  Duration? _lastAt;

  /// 連續／閒置的分界。**只用來分類，不再用來丟棄。**
  static const idleGap = Duration(milliseconds: 1500);

  /// 收一筆樣本。
  ///
  /// [rawDeltaMs] 為（本地單調時鐘 − 事件時戳）的毫秒差。
  /// [at] 為本地單調時鐘的當下值，用於閒置偵測。
  ///
  /// 回傳是否被採計，方便呼叫端顯示「丟棄了幾筆」。
  bool add(double rawDeltaMs, Duration at) {
    final previous = _lastAt;
    _lastAt = at;

    _baseline ??= rawDeltaMs;
    final centred = rawDeltaMs - _baseline!;

    // 扣掉基準後仍離群的才是真雜訊（例如 App 被切出去又切回來）。
    if (centred.abs() > 1000) return false;

    _samples.add(centred);
    if (_samples.length > capacity) _samples.removeAt(0);

    // 第一筆沒有前筆可比，不算連續。
    if (previous != null && at - previous <= idleGap) {
      _continuous.add(centred);
      if (_continuous.length > capacity) _continuous.removeAt(0);
    }
    return true;
  }

  void clear() {
    _samples.clear();
    _continuous.clear();
    _baseline = null;
    _lastAt = null;
  }

  int get count => _samples.length;

  /// 連續子集的樣本數。與 [count] 的差就是閒置後按下的次數。
  int get continuousCount => _continuous.length;

  /// 連續子集的穩健抖動估計 —— 對照用，不是裁決依據。
  double get continuousRobustSigma => 1.4826 * _madOf(_continuous);

  List<double> get _sorted => [..._samples]..sort();

  double get median {
    if (_samples.isEmpty) return 0;
    return _sorted[_samples.length ~/ 2];
  }

  /// 標準差 —— 保留供對照，但**不作為裁決依據**（對離群值過度敏感）。
  double get sigma {
    if (_samples.length < 2) return 0;
    final m = _samples.reduce((a, b) => a + b) / _samples.length;
    final variance =
        _samples.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) /
            (_samples.length - 1);
    return math.sqrt(variance);
  }

  /// 中位數絕對偏差。常態分佈下 $\sigma \approx 1.4826 \times \text{MAD}$。
  double get mad => _madOf(_samples);

  static double _madOf(List<double> xs) {
    if (xs.isEmpty) return 0;
    final sorted = [...xs]..sort();
    final m = sorted[xs.length ~/ 2];
    final deviations = xs.map((x) => (x - m).abs()).toList()..sort();
    return deviations[deviations.length ~/ 2];
  }

  /// 穩健的抖動估計 —— 裁決與建議窗寬皆以此為準。
  double get robustSigma => 1.4826 * mad;

  /// 第 95 百分位的偏差絕對值。單次最壞情況的參考。
  double get p95Abs {
    if (_samples.isEmpty) return 0;
    final abs = _samples.map((x) => x.abs()).toList()..sort();
    return abs[(abs.length * 0.95).floor().clamp(0, abs.length - 1)];
  }

  /// 完美窗的絕對下限（與 `ShutterParams.minPerfectWindowMs` 同值）。
  static const double windowFloorMs = 120;

  /// 樣本數下限 —— 低於此值不裁決。
  static const int minSamplesForVerdict = 30;

  /// 在當前抖動下，完美窗至少要多寬才算技巧而非抽獎。
  ///
  /// 以「窗寬至少涵蓋 ±1.5 個穩健標準差」反推，並不低於絕對下限。
  /// **這是本量測唯一可行動的輸出** —— 裁決只是它的摘要。
  double get recommendedWindowMs =>
      math.max(3 * robustSigma, windowFloorMs);

  /// 裁決分三段，不再是硬懸崖。
  ///
  /// 第一版在 `σ > 40` 放了二分，而 $3 \times 40 = 120$ 恰為絕對下限 ——
  /// 於是交界點必然是「下限剛好不夠用」，一越過就跳紅字，實際建議值卻只差
  /// 1 ms。那是我的儀器設計錯誤，不是裝置的問題。
  JitterVerdict verdictFor(double currentWindowMs) {
    if (count < minSamplesForVerdict) return JitterVerdict.insufficientData;
    final needed = recommendedWindowMs;
    if (currentWindowMs >= needed * 1.25) return JitterVerdict.comfortable;
    if (currentWindowMs >= needed) return JitterVerdict.marginal;
    return JitterVerdict.lottery;
  }
}

enum JitterVerdict {
  /// 樣本不足，尚無法裁決。
  insufficientData,

  /// 窗寬有 25% 以上的餘裕。
  comfortable,

  /// 窗寬剛好夠用，沒有餘裕 —— 換一台抖動大一點的裝置就會不夠。
  marginal,

  /// 窗寬低於抖動要求，判定被硬體主導。
  lottery,
}
