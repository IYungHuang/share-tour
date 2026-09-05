import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math.dart';

import '../../core/build_flags.dart';
import '../../core/time/clock.dart';
import '../../domain/location/models/geo_fix.dart';
import '../../domain/location/models/location_status.dart';
import '../../domain/location/models/movement_event.dart';
import '../../domain/location/models/rejection_reason.dart';
import '../../domain/location/pipeline/distance_buckets.dart';
import '../../domain/location/pipeline/location_pipeline.dart';
import '../../domain/location/projection/map_manifest.dart';
import '../../domain/location/smoothing/position_smoother.dart';

/// 控制器的聚合狀態。
///
/// 不用單一的 LocationStatus 當 state：多條驗收條件要斷言診斷計數與分桶距離，
/// 那些放不進五維度裡。
class LocationControllerState {
  const LocationControllerState({
    required this.status,
    required this.diagnostics,
    required this.renderedPixel,
    required this.targetPixel,
    required this.realDistanceMeters,
    required this.virtualDistanceMeters,
  });

  final LocationStatus status;
  final LocationDiagnostics diagnostics;
  final Vector2 renderedPixel;
  final Vector2? targetPixel;
  final double realDistanceMeters;
  final double virtualDistanceMeters;
}

/// 定位狀態的唯一寫入點。
///
/// 它組裝純函式模組，自身不含判定邏輯；對外只暴露語意化的方法，不暴露 setter，
/// 這樣遊戲數值就只有一條進入路徑。Flame 元件與 HUD 只讀。
class LocationController {
  LocationController.forTest({
    required OverworldMapManifest manifest,
    required Clock clock,
    required BuildFlags flags,
    bool ignoreMockedFlag = false,
  })  : _manifest = manifest,
        _clock = clock,
        _flags = flags,
        _ignoreMocked = ignoreMockedFlag,
        _pipeline = LocationPipeline(manifest: manifest, clock: clock),
        _events = MovementEventFactory(uuid: const Uuid()),
        _smoother = PositionSmoother(
          manifest: manifest,
          halfLife: const Duration(seconds: 1),
          arrivalMeters: 2,
          headingMeters: 5,
        ) {
    _smoother.jumpTo(manifest.defaultSpawnPixel);
  }

  final OverworldMapManifest _manifest;
  final Clock _clock;
  final BuildFlags _flags;
  final bool _ignoreMocked;
  final LocationPipeline _pipeline;
  final MovementEventFactory _events;
  final PositionSmoother _smoother;

  final List<MovementEvent> _log = [];
  LocationStatus _status = LocationStatus.initial.copyWith(
    permission: PermissionState.ready,
  );
  Vector2? _targetPixel;
  int _acceptedFixCount = 0;
  int _rejectedFixCount = 0;
  final Map<RejectionReason, int> _rejections = {};
  double _currentAccuracy = 0;
  bool lastSwitchWasAutomatic = false;

  BuildFlags get flags => _flags;
  List<MovementEvent> get events => List.unmodifiable(_log);

  LocationControllerState get state {
    final buckets = DistanceBuckets.replay(_log);
    return LocationControllerState(
      status: _status.copyWith(
        motion: _pipeline.motion,
        acquisition: _pipeline.acquisition,
      ),
      diagnostics: LocationDiagnostics(
        activeSubscriptionCount: 0,
        powerMode: PowerMode.active,
        acceptedFixCount: _acceptedFixCount,
        rejectedFixCount: _rejectedFixCount,
        rejectionsByReason: Map.unmodifiable(_rejections),
        currentAccuracyMeters: _currentAccuracy,
        realDistanceMeters: buckets.real,
        virtualDistanceMeters: buckets.virtual,
        secondsSinceLastSignificantMove: 0,
      ),
      renderedPixel: _smoother.rendered,
      targetPixel: _targetPixel,
      realDistanceMeters: buckets.real,
      virtualDistanceMeters: buckets.virtual,
    );
  }

  void switchMode(SourceMode mode, {required bool automatic}) {
    if (_status.mode == mode) return;
    _log.add(_events.modeChanged(
      from: _status.mode,
      to: mode,
      automatic: automatic,
      reason: automatic ? 'locationUnavailable' : 'manual',
      timestampUtc: _clock.nowUtc(),
    ));
    lastSwitchWasAutomatic = automatic;
    _status = _status.copyWith(mode: mode);
  }

  void onPermissionChanged(PermissionState permission) {
    _status = _status.copyWith(permission: permission);
    const unusable = {
      PermissionState.denied,
      PermissionState.deniedForever,
      PermissionState.serviceDisabled,
      PermissionState.approximate,
      PermissionState.unavailable,
    };
    // 定位不可用時自動切方向鍵；恢復可用時【不】自動切回，由玩家決定。
    if (unusable.contains(permission)) {
      switchMode(SourceMode.virtual, automatic: true);
    }
  }

  void ingest(GeoFix fix) {
    _currentAccuracy = fix.accuracyMeters;

    // 模擬定位標記為 virtual。這不是完備防護——Android 需 API 18、iOS 需 15
    // 且只涵蓋軟體模擬，平台不可用時預設 false——只是讓歸屬誠實。
    // 除錯旗標可覆寫，否則模擬器與 GPX 除錯期間無法驗證 gps 模式。
    final attributed = (fix.isMocked && !_ignoreMocked)
        ? fix.copyWith(sourceMode: SourceMode.virtual)
        : fix;

    final out = _pipeline.ingest(attributed);

    if (!_flags.isRelease) {
      debugPrint('[TRACK] lat=${fix.latitude.toStringAsFixed(6)} '
          'lng=${fix.longitude.toStringAsFixed(6)} '
          'acc=${fix.accuracyMeters} hasAcc=${fix.hasAccuracy} '
          'mocked=${fix.isMocked} mode=${attributed.sourceMode.name} '
          'rej=${out.rejection?.name} target=${out.targetPixel} '
          'events=${out.events.length} cov=${_manifest.containsGeo(fix.latitude, fix.longitude)}');
    }

    if (out.rejection != null) {
      _rejectedFixCount++;
      _rejections.update(out.rejection!, (n) => n + 1, ifAbsent: () => 1);
      return;
    }
    _acceptedFixCount++;

    if (out.targetPixel == null) {
      // 通過品質閘門但未顯著移動，或落在圖資範圍外。
      _status = _status.copyWith(
        coverage: _manifest.containsGeo(fix.latitude, fix.longitude)
            ? CoverageState.inside
            : CoverageState.outside,
      );
      return;
    }

    _status = _status.copyWith(coverage: CoverageState.inside);
    _targetPixel = out.targetPixel;
    _smoother.setTarget(out.targetPixel!);
    _log.addAll(out.events);
  }

  /// 由 GameLoop 每幀呼叫，推進平滑。
  void tick(double dt) => _smoother.update(dt);
}
