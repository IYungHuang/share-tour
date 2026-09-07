import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/location_status.dart';

void main() {
  test('初始狀態符合規格（AC-14.10）', () {
    const s = LocationStatus.initial;
    expect(s.permission, PermissionState.unavailable);
    expect(s.mode, SourceMode.gps);
    expect(s.coverage, CoverageState.inside);
    expect(s.acquisition, AcquisitionState.acquiring);
    expect(s.motion, MotionState.still);
  });

  test('五個維度互相獨立（AC-14.1、AC-14.2）', () {
    const s = LocationStatus.initial;
    final t = s.copyWith(
      permission: PermissionState.ready,
      coverage: CoverageState.outside,
      mode: SourceMode.virtual,
    );
    expect(t.permission, PermissionState.ready);
    expect(t.coverage, CoverageState.outside);
    expect(t.mode, SourceMode.virtual);
    expect(t.acquisition, s.acquisition, reason: '未指定的維度不得被連動');
  });

  test('HUD 優先序唯一決定（AC-14.3）', () {
    const base = LocationStatus(
      permission: PermissionState.ready,
      mode: SourceMode.gps,
      coverage: CoverageState.inside,
      acquisition: AcquisitionState.acquired,
      motion: MotionState.moving,
    );
    expect(hudPriorityOf(base), HudPriority.normal);
    expect(hudPriorityOf(base.copyWith(acquisition: AcquisitionState.acquiring)),
        HudPriority.acquiring);
    expect(hudPriorityOf(base.copyWith(coverage: CoverageState.outside)),
        HudPriority.outsideCoverage);
    expect(hudPriorityOf(base.copyWith(mode: SourceMode.virtual)),
        HudPriority.virtualMode);
    expect(
      hudPriorityOf(base.copyWith(
        permission: PermissionState.denied,
        mode: SourceMode.virtual,
        coverage: CoverageState.outside,
        acquisition: AcquisitionState.acquiring,
      )),
      HudPriority.permissionProblem,
    );
  });

  test('AC-14.7 診斷快照序列化不含座標鍵', () {
    final json = const LocationDiagnostics(
      activeSubscriptionCount: 1,
      powerMode: PowerMode.active,
      acceptedFixCount: 3,
      rejectedFixCount: 1,
      rejectionsByReason: {},
      currentAccuracyMeters: 20,
      realDistanceMeters: 500,
      virtualDistanceMeters: 0,
      secondsSinceLastSignificantMove: 4,
      accuracyGatedFixCount: 0,
    ).toJson();
    for (final k in ['lat', 'lng', 'latitude', 'longitude']) {
      expect(json.keys.map((e) => e.toLowerCase()), isNot(contains(k)));
    }
  });
}
