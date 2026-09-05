import '../models/geo_fix.dart';
import '../models/location_status.dart';
import '../models/movement_event.dart';

/// 依來源模式分桶的累計距離。
class BucketedDistance {
  const BucketedDistance(this.real, this.virtual);
  final double real;
  final double virtual;
}

/// 由事件序列重播得出分桶距離。
///
/// 寫成無狀態的 static 函式是重播決定性的結構保證：它不可能依賴當下時間、
/// 亂數或外部狀態，因此同一組事件在任何裝置、任何時區重播都得到相同結果。
class DistanceBuckets {
  const DistanceBuckets._();

  static BucketedDistance replay(Iterable<MovementEvent> events) {
    var real = 0.0;
    var virtual = 0.0;
    for (final e in events) {
      if (e is! DisplacementEvent) continue;
      // 範圍外的位移不計入任何桶：投影不可信，距離也就不可信。
      if (e.coverage == CoverageState.outside) continue;
      switch (e.sourceMode) {
        case SourceMode.gps:
          real += e.distanceMeters;
        case SourceMode.virtual:
          virtual += e.distanceMeters;
      }
    }
    return BucketedDistance(real, virtual);
  }
}
