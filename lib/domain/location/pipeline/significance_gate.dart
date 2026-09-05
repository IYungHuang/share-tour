import '../models/geo_fix.dart';
import 'geo_distance.dart';

/// 顯著位移閘門。
///
/// 靜坐時 GPS 會在精度半徑內來回跳，每一筆都通過精度、速度與時戳三道閘門，
/// 於是小人原地繞圈並持續累積假里程。這道閘門改問「位移相對於量測誤差是否
/// 夠大」，門檻因此隨精度浮動。
///
/// 基準必須凍結：未達門檻時不更新基準。若基準隨每筆前移，都市步行的每筆位移
/// 10~15 公尺全部小於 30 公尺門檻，里程會永遠是 0——散步、逛街、塞車全部歸零。
/// 這兩種實作在只餵兩筆的測試下無法分辨，故有一條刻意餵五筆的驗收條件。
class SignificanceGate {
  SignificanceGate({required this.coefficient});

  final double coefficient;

  GeoFix? _baseline;

  /// 清除基準。換層或訊號恢復後使用。
  void reset() => _baseline = null;

  /// 回傳本次的顯著位移公尺數；未達門檻回傳 null 且**不更新基準**。
  double? evaluate(GeoFix fix) {
    final baseline = _baseline;
    if (baseline == null) {
      _baseline = fix;
      return null;
    }

    final meters = haversineMeters(
        baseline.latitude, baseline.longitude, fix.latitude, fix.longitude);
    final threshold =
        coefficient * (baseline.accuracyMeters + fix.accuracyMeters);

    if (meters <= threshold) return null; // 基準維持不變

    _baseline = fix;
    return meters;
  }
}
