import 'package:freezed_annotation/freezed_annotation.dart';

import 'geo_fix.dart';

part 'location_snapshot_dto.freezed.dart';
part 'location_snapshot_dto.g.dart';

/// 可持久化的定位快照。
///
/// 依隱私規則，只允許已投影的像素座標與分桶距離，不得含任何原始經緯度。
/// 這條靠序列化結果的鍵來斷言，不靠人工複查。
@freezed
abstract class LocationSnapshotDto with _$LocationSnapshotDto {
  const factory LocationSnapshotDto({
    required double renderedPixelX,
    required double renderedPixelY,
    required double realDistanceMeters,
    required double virtualDistanceMeters,
    required SourceMode mode,
    required DateTime savedAtUtc,
  }) = _LocationSnapshotDto;

  factory LocationSnapshotDto.fromJson(Map<String, dynamic> json) =>
      _$LocationSnapshotDtoFromJson(json);
}
