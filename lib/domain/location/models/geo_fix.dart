import 'package:freezed_annotation/freezed_annotation.dart';

part 'geo_fix.freezed.dart';

/// 一筆位移的產生方式。不可由下游竄改。
enum SourceMode { gps, virtual }

/// 一筆定位讀數。
///
/// 經緯度刻意用 double 而非向量型別：vector_math 的 Vector2 是 Float32 儲存，
/// 在台灣的經度量級量化間隔約 0.77 公尺，會吃掉判定所需的精度。
@freezed
abstract class GeoFix with _$GeoFix {
  const factory GeoFix({
    required double latitude,
    required double longitude,
    required double accuracyMeters,

    /// 平台是否確實量測了精度。為 false 時 accuracyMeters 是 0.0 佔位值，
    /// 不是「零誤差」。
    required bool hasAccuracy,
    required double speedMetersPerSecond,

    /// 為 false 時 speedMetersPerSecond 是 0.0 佔位值，而 0.0 同時也是
    /// 合法的靜止讀數，兩者無法從值本身分辨。
    required bool hasSpeed,
    required double speedAccuracy,
    required bool hasSpeedAccuracy,
    required DateTime timestampUtc,
    required bool isMocked,
    required SourceMode sourceMode,
  }) = _GeoFix;
}
