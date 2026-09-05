import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math.dart';

import '../../../core/time/clock.dart';
import '../models/geo_fix.dart';
import '../models/location_status.dart';
import '../models/movement_event.dart';
import '../models/rejection_reason.dart';
import '../projection/map_manifest.dart';
import 'motion_tracker.dart';
import 'projection_stage.dart';
import 'quality_gate.dart';
import 'relocation_detector.dart';
import 'significance_gate.dart';

class PipelineOutput {
  const PipelineOutput({
    this.targetPixel,
    this.events = const [],
    this.rejection,
  });

  final Vector2? targetPixel;
  final List<MovementEvent> events;
  final RejectionReason? rejection;
}

/// 處理管線的全序編排。
///
/// 順序改變會改變結果，所以釘死在一處而非散落在十幾條規則裡。兩個順序最要緊：
/// 範圍檢查在投影之前，以及送進分桶的距離是投影【之前】量到的地理距離，
/// 而不是吸附後的像素差再換算回來——後者每一步都差到吸附上限的量級，且會累積。
class LocationPipeline {
  LocationPipeline({
    required OverworldMapManifest manifest,
    required Clock clock,
    QualityGate? qualityGate,
    SignificanceGate? significanceGate,
    MotionTracker? motionTracker,
    RelocationDetector? relocationDetector,
    MovementEventFactory? eventFactory,
  })  : _clock = clock,
        _projection = ProjectionStage(manifest),
        _quality = qualityGate ??
            QualityGate(
              accuracyLimitMeters: 100,
              maxSpeedMetersPerSecond: 350 * 1000 / 3600,
              clockAnomalyThreshold: const Duration(days: 1),
              consecutiveRejectLimit: 5,
            ),
        _significance = significanceGate ?? SignificanceGate(coefficient: 0.75),
        _motion = motionTracker ??
            MotionTracker(
              clock: clock,
              stillAfter: const Duration(seconds: 30),
              acquiringAfter: const Duration(seconds: 45),
            ),
        _relocation = relocationDetector ??
            const RelocationDetector(
              jumpLimitMeters: 2000,
              jumpSpeedLimitMps: 120 * 1000 / 3600,
            ),
        _events = eventFactory ?? MovementEventFactory(uuid: const Uuid());

  final Clock _clock;
  final ProjectionStage _projection;
  final QualityGate _quality;
  final SignificanceGate _significance;
  final MotionTracker _motion;
  final RelocationDetector _relocation;
  final MovementEventFactory _events;

  final Map<RejectionReason, int> _rejections = {};
  GeoFix? _lastAccepted;

  MotionState get motion => _motion.motion;
  AcquisitionState get acquisition => _motion.acquisition;
  Map<RejectionReason, int> get rejectionsByReason =>
      Map.unmodifiable(_rejections);

  /// 換層或訊號恢復後呼叫：清除兩道閘門的基準，否則跨越的距離會被誤判為漂移。
  void resetBaselines() {
    _quality.resetBaseline();
    _significance.reset();
    _lastAccepted = null;
  }

  PipelineOutput ingest(GeoFix fix) {
    // 第 3~5 步：品質閘門。虛擬 Fix 整段跳過——合成資料沒有量測誤差，
    // 而它的地理速度在大地圖尺度下必然超標兩個數量級。
    if (fix.sourceMode == SourceMode.gps) {
      final gate = _quality.evaluate(fix);
      if (gate is Rejected) {
        _rejections.update(gate.reason, (n) => n + 1, ifAbsent: () => 1);
        return PipelineOutput(rejection: gate.reason);
      }
    }
    _motion.onAcceptedFix();

    // 第 6 步：顯著位移閘門（基準凍結）。
    final movedMeters = _significance.evaluate(fix);
    if (movedMeters == null) return const PipelineOutput();

    // 第 7 步：範圍檢查（在投影之前）。第 8~9 步：投影與吸附。
    final projected = _projection.project(fix.latitude, fix.longitude);
    if (projected is OutsideCoverage) {
      _lastAccepted = fix;
      return const PipelineOutput();
    }
    final pixel = (projected as Projected).pixel;

    _motion.onSignificantMove();

    // 第 10 步：大跨距判定，用第 7 步之前的地理距離。
    final events = <MovementEvent>[];
    final previous = _lastAccepted;
    if (previous != null) {
      final decision = _relocation.evaluate(
        previousLat: previous.latitude,
        previousLng: previous.longitude,
        currentLat: fix.latitude,
        currentLng: fix.longitude,
        interval: fix.timestampUtc.difference(previous.timestampUtc),
        subscriptionWasContinuous: true,
        note: RelocationNote.realMovement,
      );
      if (decision != null) {
        events.add(_events.relocation(
          decision: decision,
          sourceMode: fix.sourceMode,
          fromPixelX: 0,
          fromPixelY: 0,
          toPixelX: pixel.x,
          toPixelY: pixel.y,
          distancePixels: 0,
          timestampUtc: _clock.nowUtc(),
        ));
      }
    }

    // 第 12 步：分桶距離，同樣用投影前的地理距離。
    events.add(_events.displacement(
      distanceMeters: movedMeters,
      sourceMode: fix.sourceMode,
      coverage: CoverageState.inside,
      timestampUtc: _clock.nowUtc(),
    ));

    _lastAccepted = fix;
    return PipelineOutput(targetPixel: pixel, events: events);
  }
}
