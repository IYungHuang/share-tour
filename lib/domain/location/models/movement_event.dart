import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../pipeline/relocation_detector.dart';
import 'geo_fix.dart';
import 'location_status.dart';

part 'movement_event.freezed.dart';
part 'movement_event.g.dart';

/// 本 SPEC 產生的持久化事件。
///
/// 每一類都帶上位約束要求的五個欄位（UUID、類型、UTC 時戳、單調序號、來源模式），
/// 且不含任何原始座標——位移只記公尺數，不記起訖點；傳送事件的起訖點是像素。
///
/// 分桶距離是這些事件重播的衍生結果而非獨立累加：一旦有後端，客戶端自報的最終
/// 數字沒有任何可驗證的依據，而那是事後補不回來的。
@freezed
sealed class MovementEvent with _$MovementEvent {
  const factory MovementEvent.displacement({
    required String eventId,
    required DateTime timestampUtc,
    required int sequence,
    required SourceMode sourceMode,
    required double distanceMeters,
    required CoverageState coverage,
  }) = DisplacementEvent;

  const factory MovementEvent.modeChanged({
    required String eventId,
    required DateTime timestampUtc,
    required int sequence,
    required SourceMode sourceMode,
    required SourceMode previousMode,
    required bool automatic,
    required String reason,
  }) = ModeChangedEvent;

  const factory MovementEvent.relocation({
    required String eventId,
    required DateTime timestampUtc,
    required int sequence,
    required SourceMode sourceMode,
    required double fromPixelX,
    required double fromPixelY,
    required double toPixelX,
    required double toPixelY,
    required double distanceMeters,
    required double distancePixels,
    required double speedMetersPerSecond,
    required RelocationCause cause,
    required RelocationNote note,
  }) = RelocationEvent;

  factory MovementEvent.fromJson(Map<String, dynamic> json) =>
      _$MovementEventFromJson(json);
}

/// 事件的唯一建立點。
///
/// 集中在此是為了讓 UUID 與單調序號有單一來源：散在各呼叫端會產生重複序號，
/// 而序號的用途正是排序與去重。
class MovementEventFactory {
  MovementEventFactory({required Uuid uuid}) : _uuid = uuid;

  final Uuid _uuid;
  int _sequence = 0;

  DisplacementEvent displacement({
    required double distanceMeters,
    required SourceMode sourceMode,
    required CoverageState coverage,
    required DateTime timestampUtc,
  }) =>
      MovementEvent.displacement(
        eventId: _uuid.v4(),
        timestampUtc: timestampUtc.toUtc(),
        sequence: _sequence++,
        sourceMode: sourceMode,
        distanceMeters: distanceMeters,
        coverage: coverage,
      ) as DisplacementEvent;

  ModeChangedEvent modeChanged({
    required SourceMode from,
    required SourceMode to,
    required bool automatic,
    required String reason,
    required DateTime timestampUtc,
  }) =>
      MovementEvent.modeChanged(
        eventId: _uuid.v4(),
        timestampUtc: timestampUtc.toUtc(),
        sequence: _sequence++,
        sourceMode: to,
        previousMode: from,
        automatic: automatic,
        reason: reason,
      ) as ModeChangedEvent;

  RelocationEvent relocation({
    required RelocationDecision decision,
    required SourceMode sourceMode,
    required double fromPixelX,
    required double fromPixelY,
    required double toPixelX,
    required double toPixelY,
    required double distancePixels,
    required DateTime timestampUtc,
  }) =>
      MovementEvent.relocation(
        eventId: _uuid.v4(),
        timestampUtc: timestampUtc.toUtc(),
        sequence: _sequence++,
        sourceMode: sourceMode,
        fromPixelX: fromPixelX,
        fromPixelY: fromPixelY,
        toPixelX: toPixelX,
        toPixelY: toPixelY,
        distanceMeters: decision.distanceMeters,
        distancePixels: distancePixels,
        speedMetersPerSecond: decision.speedMetersPerSecond,
        cause: decision.cause,
        note: decision.note,
      ) as RelocationEvent;
}
