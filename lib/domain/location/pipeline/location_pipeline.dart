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

  /// 最後一筆【顯著】位移的 Fix。大跨距判定的比較對象。
  GeoFix? _lastAccepted;

  /// 最後一筆【通過品質閘門】的 Fix，含判定為靜止者。
  ///
  /// 與 _lastAccepted 分開：不連續發生時，玩家最後已知的位置是這一筆，而不是
  /// 上一次顯著移動的那一筆——站著不動十分鐘再切模式，後者已是十分鐘前的舊值。
  GeoFix? _lastKnown;

  /// 最後一次更新的目標像素。傳送事件的起點（REQ-C-13 規則 14 要求像素座標）。
  Vector2? _lastPixel;

  /// 待處理的不連續標記。非空代表下一筆被接受的 Fix 走獨立路徑。
  RelocationNote? _pendingDiscontinuity;

  MotionState get motion => _motion.motion;
  AcquisitionState get acquisition => _motion.acquisition;
  int get secondsSinceLastSignificantMove =>
      _motion.secondsSinceLastSignificantMove;
  Map<RejectionReason, int> get rejectionsByReason =>
      Map.unmodifiable(_rejections);

  /// 換層或訊號恢復後呼叫：清除兩道閘門的基準，否則跨越的距離會被誤判為漂移。
  void resetBaselines() {
    _quality.resetBaseline();
    _significance.reset();
    _lastAccepted = null;
  }

  /// 標記下一筆被接受的 Fix 為不連續（REQ-C-13 規則 5 → REQ-C-07）。
  ///
  /// 切換移動模式時必須呼叫。虛擬來源的位置與真實位置毫無關係——玩家可以用
  /// 方向鍵把小人開到台北而人在台中——若不重置基準，首筆真實 Fix 會拿虛擬
  /// 基準來比，那段從未有人走過的距離就被記進 realDistanceMeters。
  ///
  /// 與 resetBaselines 的差別：這裡保留最後已知位置與像素，好讓下一筆能發出
  /// 帶起訖點的傳送事件。純粹的基準重置（換層）不需要，因為換層時地理位置
  /// 不變，本來就不該發事件。
  void markDiscontinuity(RelocationNote note) {
    _pendingDiscontinuity = note;
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

    final previousKnown = _lastKnown;
    _lastKnown = fix;

    final pending = _pendingDiscontinuity;
    if (pending != null) {
      _pendingDiscontinuity = null;
      return _ingestDiscontinuous(fix, pending, previousKnown);
    }

    // 第 6 步：顯著位移閘門（基準凍結）。
    final movedMeters = _significance.evaluate(fix);
    if (movedMeters == null) return const PipelineOutput();

    // 第 7 步：範圍檢查（在投影之前）。第 8~9 步：投影與吸附。
    final projected = _projection.project(fix.latitude, fix.longitude);
    if (projected is OutsideCoverage) {
      _lastAccepted = fix;
      // 回到範圍內時走獨立路徑。範圍檢查排在顯著性閘門之後，基準此刻已被推到
      // 境外那一點；不標記的話，回國的第一筆會把整段跨海行程算成里程。
      _pendingDiscontinuity = RelocationNote.coverageRecovered;
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
        events.add(_relocationEvent(decision, fix, pixel));
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
    _lastPixel = pixel;
    return PipelineOutput(targetPixel: pixel, events: events);
  }

  /// 不連續的獨立路徑：重新投影後直接指定目標點。
  ///
  /// 不經顯著位移閘門，也不發位移事件——這段距離沒有人走過，計入任何一個桶
  /// 都是假里程。跨距若達 REQ-C-07 的門檻則發傳送事件，成因必為 discontinuity：
  /// 訂閱在切換的當下就斷了，不可能是連續追蹤。
  PipelineOutput _ingestDiscontinuous(
    GeoFix fix,
    RelocationNote note,
    GeoFix? previous,
  ) {
    // 設定新基準。首筆必然回傳 null，此處不需要它的回傳值。
    _significance.evaluate(fix);

    final projected = _projection.project(fix.latitude, fix.longitude);
    if (projected is OutsideCoverage) {
      _lastAccepted = fix;
      return const PipelineOutput();
    }
    final pixel = (projected as Projected).pixel;

    final events = <MovementEvent>[];
    if (previous != null) {
      final decision = _relocation.evaluate(
        previousLat: previous.latitude,
        previousLng: previous.longitude,
        currentLat: fix.latitude,
        currentLng: fix.longitude,
        interval: fix.timestampUtc.difference(previous.timestampUtc),
        subscriptionWasContinuous: false,
        note: note,
      );
      if (decision != null) {
        events.add(_relocationEvent(decision, fix, pixel));
      }
    }

    _lastAccepted = fix;
    _lastPixel = pixel;
    return PipelineOutput(targetPixel: pixel, events: events);
  }

  MovementEvent _relocationEvent(
      RelocationDecision decision, GeoFix fix, Vector2 pixel) {
    final from = _lastPixel ?? pixel;
    return _events.relocation(
      decision: decision,
      sourceMode: fix.sourceMode,
      fromPixelX: from.x,
      fromPixelY: from.y,
      toPixelX: pixel.x,
      toPixelY: pixel.y,
      distancePixels: (pixel - from).length,
      timestampUtc: _clock.nowUtc(),
    );
  }
}
