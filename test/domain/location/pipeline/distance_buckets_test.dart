import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/domain/location/models/movement_event.dart';
import 'package:share_tour/domain/location/pipeline/distance_buckets.dart';
import 'package:share_tour/domain/location/pipeline/relocation_detector.dart';

MovementEvent disp(double m, SourceMode mode,
        {int seq = 0, CoverageState coverage = CoverageState.inside}) =>
    MovementEvent.displacement(
      eventId: 'e$seq',
      timestampUtc: DateTime.utc(2026, 1, 1),
      sequence: seq,
      sourceMode: mode,
      distanceMeters: m,
      coverage: coverage,
    );

void main() {
  test('AC-13.4 virtual 移動 1 公里 → 只進 virtual 桶', () {
    final r = DistanceBuckets.replay([disp(1000, SourceMode.virtual)]);
    expect(r.virtual, closeTo(1000, 1));
    expect(r.real, 0);
  });

  test('AC-13.7 範圍外的位移兩桶皆不變', () {
    final r = DistanceBuckets.replay(
        [disp(500, SourceMode.gps, coverage: CoverageState.outside)]);
    expect(r.real, 0);
    expect(r.virtual, 0);
  });

  test('AC-13.13 重播具決定性', () {
    final events = [
      disp(100, SourceMode.gps, seq: 0),
      disp(200, SourceMode.virtual, seq: 1),
      disp(300, SourceMode.gps, seq: 2),
    ];
    final a = DistanceBuckets.replay(events);
    final b = DistanceBuckets.replay(events);
    expect(a.real, b.real);
    expect(a.virtual, b.virtual);
    expect(a.real, closeTo(400, 1));
  });

  test('AC-13.11 位移事件帶齊 CC-3 要求的五個欄位', () {
    final e = disp(100, SourceMode.gps, seq: 7) as DisplacementEvent;
    expect(e.eventId, isNotEmpty);
    expect(e.timestampUtc.isUtc, isTrue);
    expect(e.sequence, 7);
    expect(e.sourceMode, SourceMode.gps);
  });

  test('AC-13.12 三類事件的序列化結果皆不含經緯度鍵', () {
    final events = <MovementEvent>[
      disp(100, SourceMode.gps),
      MovementEvent.modeChanged(
        eventId: 'm1',
        timestampUtc: DateTime.utc(2026),
        sequence: 1,
        sourceMode: SourceMode.virtual,
        previousMode: SourceMode.gps,
        automatic: true,
        reason: 'permissionDenied',
      ),
      MovementEvent.relocation(
        eventId: 'r1',
        timestampUtc: DateTime.utc(2026),
        sequence: 2,
        sourceMode: SourceMode.gps,
        fromPixelX: 10,
        fromPixelY: 20,
        toPixelX: 300,
        toPixelY: 400,
        distanceMeters: 5000,
        distancePixels: 13.5,
        speedMetersPerSecond: 83.3,
        cause: RelocationCause.continuousTracking,
        note: RelocationNote.realMovement,
      ),
    ];
    for (final e in events) {
      final keys = e.toJson().keys.map((k) => k.toLowerCase()).toList();
      for (final banned in ['lat', 'lng', 'latitude', 'longitude']) {
        expect(keys, isNot(contains(banned)), reason: '$e 夾帶了座標鍵 $banned');
      }
    }
  });

  test('AC-CC-1.1 事件 UUID 互不相同且序號遞增', () {
    final factory = MovementEventFactory(uuid: const Uuid());
    final a = factory.displacement(
        distanceMeters: 1,
        sourceMode: SourceMode.gps,
        coverage: CoverageState.inside,
        timestampUtc: DateTime.utc(2026));
    final b = factory.displacement(
        distanceMeters: 1,
        sourceMode: SourceMode.gps,
        coverage: CoverageState.inside,
        timestampUtc: DateTime.utc(2026));
    expect(a.eventId, isNot(equals(b.eventId)));
    expect(b.sequence, greaterThan(a.sequence));
  });
}
