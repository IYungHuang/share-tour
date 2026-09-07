import '../models/geo_fix.dart';
import '../models/rejection_reason.dart';
import 'geo_distance.dart';

sealed class GateResult {
  const GateResult();
}

class Accepted extends GateResult {
  const Accepted(this.fix);
  final GeoFix fix;
}

class Rejected extends GateResult {
  const Rejected(this.reason);
  final RejectionReason reason;
}

/// GPS 品質閘門。
///
/// 四道檢查，順序固定：平台是否確實量測、精度上限、時間、速度合理性。
///
/// 時間那一步的內部順序不可顛倒——先判時鐘異常，再判單調性。一筆「早兩天」的
/// 讀數同時滿足兩條規則：它早於前一筆（該丟棄），差距又超過一天（該重置並接受）。
/// 時鐘異常的語意是「基準本身不可信」，必須先於任何以基準為準的判定。
class QualityGate {
  QualityGate({
    required this.accuracyLimitMeters,
    required this.maxSpeedMetersPerSecond,
    required this.clockAnomalyThreshold,
    required this.consecutiveRejectLimit,
  });

  final double accuracyLimitMeters;
  final double maxSpeedMetersPerSecond;
  final Duration clockAnomalyThreshold;
  final int consecutiveRejectLimit;

  GeoFix? _baseline;
  int _consecutiveRejects = 0;

  /// 清除比較基準。下一筆視同首筆，不受速度規則約束。
  /// 換層與訊號恢復後使用，否則跨越的距離會被誤判為漂移。
  void resetBaseline() {
    _baseline = null;
    _consecutiveRejects = 0;
  }

  GateResult evaluate(GeoFix fix) {
    // 1. 已量測旗標。0.0 是佔位值，不是零誤差。
    if (!fix.hasAccuracy) return _reject(RejectionReason.unmeasuredAccuracy);

    // 2. 精度上限（門檻值本身視為合格）。
    if (fix.accuracyMeters > accuracyLimitMeters) {
      return _reject(RejectionReason.accuracy);
    }

    final baseline = _baseline;
    if (baseline == null) return _accept(fix);

    final delta = fix.timestampUtc.difference(baseline.timestampUtc);

    // 3a. 時鐘異常：重置基準並接受。必須先於單調性判定。
    if (delta.abs() > clockAnomalyThreshold) return _accept(fix);

    // 3b. 時戳單調性。
    if (delta <= Duration.zero) return _reject(RejectionReason.timestamp);

    // 4. 速度合理性。連續丟棄達上限時豁免此步，避免錯誤的基準永久卡死追蹤。
    final forced = _consecutiveRejects >= consecutiveRejectLimit;
    if (!forced && _exceedsSpeedLimit(baseline, fix, delta)) {
      return _reject(RejectionReason.speed);
    }
    return _accept(fix);
  }

  // 推算速度僅用兩點差分（修訂五，SPEC v6）。都卜勒解算與位置解算共用同一組
  // 衛星幾何，裝置回報速度不是獨立證據源：實測手機靜止時裝置回報速度中位數
  // 1.85 m/s、最大 14.08 m/s（F4）。取小值只會讓速度閘門更難丟棄——一個亂報
  // 低速的裝置可以整條關掉 350 km/h 閘門。`hasSpeed`/`hasSpeedAccuracy` 欄位
  // 保留於 GeoFix（診斷用），此處不再消費。
  bool _exceedsSpeedLimit(GeoFix baseline, GeoFix fix, Duration delta) {
    final meters = haversineMeters(
        baseline.latitude, baseline.longitude, fix.latitude, fix.longitude);
    final speed = meters / (delta.inMicroseconds / 1e6);
    return speed > maxSpeedMetersPerSecond;
  }

  GateResult _accept(GeoFix fix) {
    _baseline = fix;
    _consecutiveRejects = 0;
    return Accepted(fix);
  }

  GateResult _reject(RejectionReason reason) {
    _consecutiveRejects++;
    return Rejected(reason);
  }
}
