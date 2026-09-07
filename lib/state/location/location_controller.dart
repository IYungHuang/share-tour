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
import '../../domain/location/pipeline/relocation_detector.dart';
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

  OverworldMapManifest _manifest;
  final Clock _clock;
  final BuildFlags _flags;
  final bool _ignoreMocked;

  /// 是否輸出逐筆追蹤。真機診斷時開啟；測試中關閉以免淹沒輸出。
  bool traceIngestion = false;
  LocationPipeline _pipeline;
  final MovementEventFactory _events;
  PositionSmoother _smoother;

  /// 最後一筆被接受的地理位置。換層時用它以新模組重新投影。
  GeoFix? _lastGeo;

  final List<MovementEvent> _log = [];
  LocationStatus _status = LocationStatus.initial.copyWith(
    permission: PermissionState.ready,
  );
  Vector2? _targetPixel;
  int _acceptedFixCount = 0;
  int _rejectedFixCount = 0;
  int _accuracyGatedFixCount = 0;
  final Map<RejectionReason, int> _rejections = {};
  double _currentAccuracy = 0;
  bool lastSwitchWasAutomatic = false;

  /// 訂閱與省電的實況，由接線層寫入。
  ///
  /// 控制器不自己管訂閱：那是 data 層的職責，而它需要平台的生命週期事件。
  /// 但診斷快照是對外的單一窗口（REQ-C-14 規則 5），所以值要送進來，
  /// 不能像先前那樣寫死 0 與 active——那讓 AC-2.5 變成恆真的假綠燈。
  int subscriptionCount = 0;
  PowerMode powerMode = PowerMode.active;

  BuildFlags get flags => _flags;
  List<MovementEvent> get events => List.unmodifiable(_log);
  OverworldMapManifest get activeManifest => _manifest;
  double get arrivalThresholdPixels => _smoother.arrivalThresholdPixels;

  /// 執行期更換投影層。
  ///
  /// 走獨立路徑：重置兩道閘門的基準、以新模組重新投影當前地理位置、直接指定
  /// 顯示點。**不經大跨距判定，也不發傳送事件**——判準已改為地理位移，而換層
  /// 時地理位置完全不變，位移必為零，那條路徑在建構上就不可達。
  ///
  /// 位置若落在新模組範圍外，換層仍然成功、只是標記為範圍外。拒絕換層會把
  /// 玩家困在他正想離開的那一層。
  ///
  /// 分桶距離以公尺計、與圖層無關，故不清零：里程是玩家走出來的，
  /// 不會因為換了一張圖就不算數。
  void switchLayer(OverworldMapManifest next) {
    _manifest = next;
    _pipeline = LocationPipeline(manifest: next, clock: _clock);
    _smoother = PositionSmoother(
      manifest: next,
      halfLife: const Duration(seconds: 1),
      arrivalMeters: 2,
      headingMeters: 5,
    );

    final last = _lastGeo;
    if (last != null && next.containsGeo(last.latitude, last.longitude)) {
      _smoother.jumpTo(next.snapToRoad(
          next.projectToPixel(last.latitude, last.longitude)));
    } else {
      _smoother.jumpTo(next.defaultSpawnPixel);
    }
    _targetPixel = null;
  }

  LocationControllerState get state {
    final buckets = DistanceBuckets.replay(_log);
    return LocationControllerState(
      status: _status.copyWith(
        motion: _pipeline.motion,
        acquisition: _pipeline.acquisition,
      ),
      diagnostics: LocationDiagnostics(
        activeSubscriptionCount: subscriptionCount,
        powerMode: powerMode,
        acceptedFixCount: _acceptedFixCount,
        rejectedFixCount: _rejectedFixCount,
        rejectionsByReason: Map.unmodifiable(_rejections),
        currentAccuracyMeters: _currentAccuracy,
        realDistanceMeters: buckets.real,
        virtualDistanceMeters: buckets.virtual,
        secondsSinceLastSignificantMove:
            _pipeline.secondsSinceLastSignificantMove,
        accuracyGatedFixCount: _accuracyGatedFixCount,
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

    // 兩種來源的位置毫無關係：方向鍵可以把小人開到台北，而人在台中。
    // 不標記不連續的話，首筆新來源的 Fix 會拿舊來源的基準比出一段從未有人
    // 走過的距離，並記進里程。真機實測灌進 13 萬公尺。
    _pipeline.markDiscontinuity(RelocationNote.modeSwitch);
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

  /// 標記下一筆 Fix 為不連續。背景恢復、服務恢復等路徑由接線層呼叫；
  /// 模式切換與範圍恢復在內部自行標記。
  void markDiscontinuity(RelocationNote note) =>
      _pipeline.markDiscontinuity(note);

  void ingest(GeoFix fix) {
    _currentAccuracy = fix.accuracyMeters;

    // 模擬定位標記為 virtual。這不是完備防護——Android 需 API 18、iOS 需 15
    // 且只涵蓋軟體模擬，平台不可用時預設 false——只是讓歸屬誠實。
    // 除錯旗標可覆寫，否則模擬器與 GPX 除錯期間無法驗證 gps 模式。
    final attributed = (fix.isMocked && !_ignoreMocked)
        ? fix.copyWith(sourceMode: SourceMode.virtual)
        : fix;

    _lastGeo = fix;
    final out = _pipeline.ingest(attributed);

    // 逐筆追蹤。只在明確開啟時輸出——它在真機診斷時不可或缺，
    // 但會淹沒測試輸出，而測試本來就有更精確的斷言。
    if (traceIngestion && !_flags.isRelease) {
      debugPrint('[TRACK] lat=${fix.latitude.toStringAsFixed(6)} '
          'lng=${fix.longitude.toStringAsFixed(6)} '
          'acc=${fix.accuracyMeters} hasAcc=${fix.hasAccuracy} '
          'spd=${fix.speedMetersPerSecond.toStringAsFixed(2)} '
          'hasSpd=${fix.hasSpeed} spdAcc=${fix.speedAccuracy.toStringAsFixed(2)} '
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
    if (out.qualityGated) _accuracyGatedFixCount++;

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

    // 大跨距不平滑：以 1 秒半衰期趨近數十公里，小人會在地圖上飄很久。
    // 規格要求直接指定顯示點，過場由畫面層負責。
    if (out.events.whereType<RelocationEvent>().isNotEmpty) {
      _smoother.jumpTo(out.targetPixel!);
    } else {
      _smoother.setTarget(out.targetPixel!);
    }
    _log.addAll(out.events);
  }

  /// 由 GameLoop 每幀呼叫，推進平滑。
  void tick(double dt) => _smoother.update(dt);
}
