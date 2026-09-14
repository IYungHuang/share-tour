import 'package:flutter/material.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/domain/core_loop/shutter/held_ms.dart';
import 'package:share_tour/domain/core_loop/shutter/indicator_state.dart';
import 'package:share_tour/domain/core_loop/shutter/shutter_input.dart';
import 'package:share_tour/domain/core_loop/shutter/shutter_params.dart';
import 'package:share_tour/domain/core_loop/shutter/shutter_result.dart';
import 'package:share_tour/domain/core_loop/shutter/visual_elapsed_ms.dart';

import '../components/shutter_result_badge.dart';

/// 取景框邊長的估計像素值（REQ-M5-03.4 的 $d_c$ 分母），純呈現層近似值，
/// 不影響判定契約——真正的門檻比較（`framingOk`）吃的是比例，只要分子分母
/// 用同一把尺，門檻表（`kFramingMaxOffset`）就仍然成立。
const double _kFrameBoxSidePixels = 160.0;
const double _kFrameTargetSidePixels = 112.0;
const double _kRingStartSizePixels = 96.0;
const double _kRingTargetSizePixels = 48.0;

/// 「送達餘裕」的長度（REQ-M5-01.7）：動畫全長到達後，仍再等這麼久才真正
/// 判定 [TimedOut]，讓遲到的 [PointerUpEvent] 有機會被以指標時戳重算。
const int _kGraceMs = 100;

/// 快門 QTE 覆蓋層（REQ-M5-01、REQ-M5-03、REQ-M5-04.2、REQ-M5-11）。
///
/// 判定用時長只認指標時戳（[HeldMs] 只吃兩個 [Duration]），視覺收縮吃
/// [AnimationController] 的 dt 包成 [VisualElapsedMs]——兩條時間軸型別
/// 不相容（AC-M5-1.13），杜絕視覺 dt 被順手餵進判定路徑。
class ShutterQteOverlay extends StatefulWidget {
  const ShutterQteOverlay({
    super.key,
    required this.difficulty,
    required this.isSpotlight,
    required this.onResolved,
    required this.onInterrupted,
  });

  final ShutterDifficulty difficulty;
  final bool isSpotlight;

  /// 判定結果就緒時呼叫，含中斷路徑（中斷仍會算出一個真正的三態，資源
  /// 照常扣除——REQ-M5-04.2 規則 2）。
  final void Function(ShotTier result) onResolved;

  /// 中斷發生時額外呼叫一次，供呼叫端疊加本局 ×0.9 折扣
  /// （`CuratorRunController.recordShutterInterruption`）。與 [onResolved]
  /// 都會被呼叫——本回呼只是「這次是中斷」的旗標，不是另一條判定結果。
  final VoidCallback onInterrupted;

  @override
  State<ShutterQteOverlay> createState() => _ShutterQteOverlayState();
}

class _ShutterQteOverlayState extends State<ShutterQteOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final DifficultyTiming _timing;

  Duration? _downTimeStamp;
  Duration? _cancelTimeStamp;
  int? _activePointer;
  final List<(Duration timeStamp, Offset offset)> _dragSamples = [];
  Offset? _framePosition;
  Offset _targetCenter = Offset.zero;

  bool _settled = false;
  ShotTier? _resultTier;
  bool? _resultIsEarly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timing = kDifficultyTimings[widget.difficulty]!;
    // 動畫全長之外多跑一段送達餘裕（REQ-M5-01.7）：controller 走完全長時
    // 只是「還沒放開時的視覺提示」切到逾時態，真正判定 `TimedOut` 要等
    // controller 整個跑完（含餘裕）才落地——期間任何時刻收到 up/cancel
    // 一律以指標時戳重算，不被這段落地時機搶先（AC-M5-1.12）。
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _timing.animationLengthMs + _kGraceMs),
    )..addStatusListener(_onAnimationStatus);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// 動畫（含餘裕）全部跑完仍未收到終止指標事件，才真正判定逾時
  /// （REQ-M5-01.7：逾時界線量在指標軸上——這裡只負責「沒人按」的後備，
  /// 任何真正按過的 Δt 一律走 [_resolveFromTerminal] 的指標時戳路徑）。
  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed ||
        _settled ||
        _downTimeStamp == null) {
      return;
    }
    _settle(const TimedOut(), compositionOffset: null, isEarly: null);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_settled || _downTimeStamp != null) return;
    _activePointer = event.pointer;
    _downTimeStamp = event.timeStamp;
    _framePosition = event.localPosition;
    _dragSamples
      ..clear()
      ..add((event.timeStamp, event.localPosition));
    _controller.forward(from: 0);
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.isSpotlight || event.pointer != _activePointer) return;
    _dragSamples.add((event.timeStamp, event.localPosition));
    setState(() => _framePosition = event.localPosition);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _resolveFromTerminal(event.timeStamp);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_settled || event.pointer != _activePointer) return;
    _cancelTimeStamp = event.timeStamp;
  }

  void _resolveFromTerminal(Duration terminalTimeStamp) {
    if (_settled || _downTimeStamp == null) return;
    _controller.stop();
    final heldMs = HeldMs(
      downTimeStamp: _downTimeStamp!,
      upTimeStamp: terminalTimeStamp,
    );
    if (heldMs.toInt() > _timing.animationLengthMs) {
      _settle(const TimedOut(), compositionOffset: null, isEarly: null);
      return;
    }
    final signedDeltaMs = heldMs.toInt() - _timing.tMatchMs;
    final compositionOffset = widget.isSpotlight
        ? _compositionOffsetNear(terminalTimeStamp)
        : null;
    _settle(
      Pressed(heldMs),
      compositionOffset: compositionOffset,
      isEarly: signedDeltaMs < 0,
    );
  }

  void _resolveInterruption(Duration terminalTimeStamp) {
    if (_settled || _downTimeStamp == null) return;
    _controller.stop();
    final heldMs = HeldMs(
      downTimeStamp: _downTimeStamp!,
      upTimeStamp: terminalTimeStamp,
    );
    if (heldMs.toInt() > _timing.animationLengthMs) {
      _settle(const TimedOut(), compositionOffset: null, isEarly: null);
      widget.onInterrupted();
      return;
    }
    final signedDeltaMs = heldMs.toInt() - _timing.tMatchMs;
    _settle(
      Pressed(heldMs),
      compositionOffset: null,
      isEarly: signedDeltaMs < 0,
    );
    widget.onInterrupted();
  }

  /// REQ-M5-03.4：$d_c$ 取自放開前約 50 ms 的取樣，不取 lift-off 當下座標
  /// （電容式觸控在 lift-off 時回報的座標通常漂移數 px）。
  double _compositionOffsetNear(Duration terminalTimeStamp) {
    if (_dragSamples.isEmpty) return 0.0;
    final target = terminalTimeStamp - const Duration(milliseconds: 50);
    var best = _dragSamples.first;
    for (final sample in _dragSamples) {
      if (sample.$1.compareTo(target) <= 0 &&
          sample.$1.compareTo(best.$1) >= 0) {
        best = sample;
      }
    }
    return (best.$2 - _targetCenter).distance / _kFrameBoxSidePixels;
  }

  void _settle(
    ShutterInput input, {
    required double? compositionOffset,
    required bool? isEarly,
  }) {
    if (_settled) return;
    final result = resolveShotTier(
      input: input,
      difficulty: widget.difficulty,
      isSpotlight: widget.isSpotlight,
      compositionOffset: compositionOffset,
    );
    setState(() {
      _settled = true;
      _resultTier = result;
      _resultIsEarly = input is TimedOut ? null : isEarly;
    });
    widget.onResolved(result);
  }

  /// REQ-M5-04.2：App 離開 `resumed`（含 `inactive`）觸發中斷。正常情況下
  /// 引擎已對仍在追蹤的指標送出 [PointerCancelEvent]，`_onPointerCancel`
  /// 已處理過；這裡是「生命週期通知先於任何終止指標事件送達」的後備路徑
  /// ——僅在此後備路徑才允許使用非指標時鐘（單調的當前系統影格時戳，與
  /// 指標事件同軸）。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_settled || state == AppLifecycleState.resumed) return;
    if (_downTimeStamp == null) return;
    final terminalTimeStamp =
        _cancelTimeStamp ?? WidgetsBinding.instance.currentSystemFrameTimeStamp;
    _resolveInterruption(terminalTimeStamp);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // 判定就緒後立刻放行輸入——不阻塞下層點擊（AC-M5-11.1）。
      ignoring: _settled,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: AbsorbPointer(
          // 視覺子樹本身無互動元件；明確標註「QTE 進行中不接受下層互動」
          // （REQ-M5-01.4），獨佔輸入的實際機制是本 Listener 的 opaque 行為。
          absorbing: true,
          child: _settled ? _buildResult() : _buildIndicator(),
        ),
      ),
    );
  }

  Widget _buildIndicator() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _targetCenter = constraints.biggest.center(Offset.zero);
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final visualElapsedMs =
                (_controller.value * (_timing.animationLengthMs + _kGraceMs))
                    .round();
            final state = indicatorState(
              VisualElapsedMs(visualElapsedMs),
              widget.difficulty,
            );
            final framePosition = _framePosition ?? _targetCenter;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (widget.isSpotlight) ...[
                  Center(
                    child: Container(
                      key: const Key('shutterIndicator.framingTarget'),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.greenAccent, width: 2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: framePosition.dx - _kFrameBoxSidePixels / 2,
                    top: framePosition.dy - _kFrameBoxSidePixels / 2,
                    child: _FramingBoxIndicator(
                      state: state,
                      size: _shrinkingExtent(
                        elapsedMs: visualElapsedMs,
                        matchMs: _timing.tMatchMs,
                        lengthMs: _timing.animationLengthMs,
                        startSize: _kFrameBoxSidePixels,
                        targetSize: _kFrameTargetSidePixels,
                      ),
                    ),
                  ),
                ] else
                  Center(
                    child: _ConcentricRingIndicator(
                      state: state,
                      size: _shrinkingExtent(
                        elapsedMs: visualElapsedMs,
                        matchMs: _timing.tMatchMs,
                        lengthMs: _timing.animationLengthMs,
                        startSize: _kRingStartSizePixels,
                        targetSize: _kRingTargetSizePixels,
                      ),
                    ),
                  ),
                Align(
                  alignment: const Alignment(0, 0.55),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      key: const Key('shutterInstruction'),
                      widget.isSpotlight
                          ? '按住畫面拖曳取景框對準中心，\n框線收合到與內框重合時放開'
                          : '按住畫面任何位置，\n外圈收縮到與目標圈重合時放開\n（圈變色＝已過頭，縮到 0 就逾時）',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildResult() {
    final tier = _resultTier!;
    final key = _resultIsEarly == null
        ? const Key('shutterResult.timedOut')
        : Key(
            'shutterResult.${tier.name}.${_resultIsEarly! ? 'early' : 'late'}',
          );
    final text = _resultIsEarly == null
        ? '逾時'
        : '${_tierLabel(tier)}・${_resultIsEarly! ? '早了' : '晚了'}';
    return Center(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShutterResultBadge(tier: tier),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static String _tierLabel(ShotTier tier) => switch (tier) {
    ShotTier.perfect => '完美',
    ShotTier.normal => '普通',
    ShotTier.failed => '失手',
  };
}

double _shrinkingExtent({
  required int elapsedMs,
  required int matchMs,
  required int lengthMs,
  required double startSize,
  required double targetSize,
}) {
  if (elapsedMs <= matchMs) {
    final progress = (elapsedMs / matchMs).clamp(0.0, 1.0);
    return startSize + (targetSize - startSize) * progress;
  }
  final progress = ((elapsedMs - matchMs) / (lengthMs - matchMs)).clamp(
    0.0,
    1.0,
  );
  return targetSize * (1 - progress);
}

/// 非絕景收縮指示：同心圓收縮，吻合時刻恰好等於兩者半徑相等的時刻
/// （REQ-M5-03.3——這是整個動作唯一的視覺承諾，不得移除或搬離）。
class _ConcentricRingIndicator extends StatelessWidget {
  const _ConcentricRingIndicator({required this.state, required this.size});

  final IndicatorState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (color, symbol) = _encode(state);
    return SizedBox(
      key: const Key('shutterIndicator.ring'),
      width: _kRingStartSizePixels,
      height: _kRingStartSizePixels,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            key: const Key('shutterIndicator.target'),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 3),
            ),
          ),
          Container(
            key: const Key('shutterIndicator.ringDynamic'),
            width: size.clamp(0.0, _kRingStartSizePixels),
            height: size.clamp(0.0, _kRingStartSizePixels),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
            ),
          ),
          Text(
            symbol,
            style: TextStyle(
              fontSize: 20,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static (Color, String) _encode(IndicatorState state) => switch (state) {
    // 狀態改變非單一色彩編碼（REQ-M5-01.13）：色彩＋符號＋動態三重都變。
    IndicatorState.beforeMatch => (const Color(0xFF3182CE), '◎'),
    IndicatorState.pastMatch => (const Color(0xFFDD6B20), '△'),
    IndicatorState.timedOut => (const Color(0xFF718096), '✕'),
  };
}

/// 絕景收縮指示：畫在取景框自己的邊框上，邊框收束到基準框線（REQ-M5-03.3）
/// ——框跟著手指走（拖曳由外層 `Listener` 取樣），指示就跟著視線走。
class _FramingBoxIndicator extends StatelessWidget {
  const _FramingBoxIndicator({required this.state, required this.size});

  final IndicatorState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (color, symbol) = _ConcentricRingIndicator._encode(state);
    return SizedBox(
      key: const Key('shutterIndicator.frame'),
      width: _kFrameBoxSidePixels,
      height: _kFrameBoxSidePixels,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            key: const Key('shutterIndicator.frameBaseline'),
            width: _kFrameTargetSidePixels,
            height: _kFrameTargetSidePixels,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white54, width: 2),
            ),
          ),
          Container(
            key: const Key('shutterIndicator.frameDynamic'),
            width: size.clamp(0.0, _kFrameBoxSidePixels),
            height: size.clamp(0.0, _kFrameBoxSidePixels),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 3),
            ),
          ),
          Text(
            symbol,
            style: TextStyle(
              fontSize: 20,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
