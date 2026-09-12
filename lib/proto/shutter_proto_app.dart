/// M5 快門手感原型 —— **丟棄式**。
///
/// 目的是回答 v4 §6 待決 1 與五件只有實機能判斷的事，產出一組調校參數。
/// 不接第二層分數、不接計分、不寫文案、不碰存檔。
///
/// 跑法：`flutter run -t lib/proto/shutter_proto_app.dart -d <device>`
library;

import 'package:flutter/material.dart';

import 'latency_probe.dart';
import 'shutter_verdict.dart';

void main() => runApp(const ShutterProtoApp());

class ShutterProtoApp extends StatelessWidget {
  const ShutterProtoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'M5 快門手感原型',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const ShutterProtoPage(),
      );
}

/// 一次判定的紀錄。
class _Shot {
  _Shot({
    required this.tier,
    required this.offsetMs,
    required this.heldMs,
    required this.framingOk,
    required this.spotlight,
    required this.timedOut,
  });

  final ShutterTier tier;
  final int offsetMs;
  final int heldMs;
  final bool framingOk;
  final bool spotlight;
  final bool timedOut;
}

class ShutterProtoPage extends StatefulWidget {
  const ShutterProtoPage({super.key});

  @override
  State<ShutterProtoPage> createState() => _ShutterProtoPageState();
}

class _ShutterProtoPageState extends State<ShutterProtoPage>
    with SingleTickerProviderStateMixin {
  static const _targetRadius = 90.0;
  static const _startRadiusFactor = 1.6;

  var _difficulty = ShutterDifficulty.photographer;
  var _spotlightMode = false;

  /// 下緣時間軸：對調參有用，對玩家是雜訊 —— 預設關。
  var _showTimeline = false;

  late final AnimationController _ring;
  final _latency = LatencyStats();
  final _stopwatch = Stopwatch()..start();

  /// 按下瞬間的指標時戳（判定的唯一權威時間軸，v4 REQ-M5-01.3）。
  Duration? _downStamp;

  /// 取景框位置（絕景模式）。放開前 50 ms 的取樣用（v4 REQ-M5-03.4）。
  final List<(Duration, Offset)> _framingTrail = [];
  Offset? _framePos;

  final List<_Shot> _shots = [];
  _Shot? _last;
  var _sessionStartMs = 0;

  ShutterParams get _params => shutterParamTable[_difficulty]!;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this);
    _sessionStartMs = _stopwatch.elapsedMilliseconds;
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  void _onDown(PointerDownEvent e) {
    // 指標時戳的抖動量測：本地單調時鐘與事件時戳的差，其 σ 即輸入管線抖動。
    // 兩者 epoch 不同，故只取 σ，絕對值無意義。
    _latency.add(
      (_stopwatch.elapsed - e.timeStamp).inMicroseconds / 1000.0,
    );

    _downStamp = e.timeStamp;
    _framingTrail
      ..clear()
      ..add((e.timeStamp, e.localPosition));
    _framePos = e.localPosition;

    _ring
      ..duration = Duration(milliseconds: _params.totalMs)
      ..forward(from: 0);
    _ring.addStatusListener(_onRingDone);
    setState(() {});
  }

  void _onRingDone(AnimationStatus s) {
    if (s != AnimationStatus.completed || _downStamp == null) return;
    _ring.removeStatusListener(_onRingDone);
    _resolve(const TimedOut(), heldMs: _params.totalMs, timedOut: true);
  }

  void _onMove(PointerMoveEvent e) {
    if (_downStamp == null) return;
    _framingTrail.add((e.timeStamp, e.localPosition));
    setState(() => _framePos = e.localPosition);
  }

  void _onUp(PointerUpEvent e) {
    final down = _downStamp;
    if (down == null) return;
    _ring.removeStatusListener(_onRingDone);
    _ring.stop();

    final heldMs = (e.timeStamp - down).inMilliseconds;
    final offset = (heldMs - _params.matchMs).abs();
    _resolve(Pressed(offset), heldMs: heldMs, timedOut: false);
  }

  void _resolve(ShutterInput input, {required int heldMs, required bool timedOut}) {
    var tier = judgeShutter(_difficulty, input);
    var framingOk = true;

    if (_spotlightMode) {
      framingOk = _framingWithinTolerance();
      tier = applyFramingPenalty(tier, framingOk: framingOk);
    }

    final shot = _Shot(
      tier: tier,
      offsetMs: input is Pressed ? input.offsetMs : _params.totalMs,
      heldMs: heldMs,
      framingOk: framingOk,
      spotlight: _spotlightMode,
      timedOut: timedOut,
    );

    setState(() {
      _downStamp = null;
      _framePos = null;
      _last = shot;
      _shots.add(shot);
    });
  }

  /// 構圖偏差取**放開前約 50 ms** 的取樣（v4 REQ-M5-03.4）——
  /// 電容式觸控在 lift-off 時回報的座標通常漂移數 px。
  bool _framingWithinTolerance() {
    if (_framingTrail.isEmpty) return false;
    final lastStamp = _framingTrail.last.$1;
    final window = _framingTrail
        .where((s) => (lastStamp - s.$1).inMilliseconds >= 50)
        .toList();
    final sample = (window.isEmpty ? _framingTrail.first : window.last).$2;
    final center = _targetCenter;
    final d = (sample - center).distance / _targetRadius;
    return d <= _framingTolerance;
  }

  /// 構圖是二元判定，每難度一個門檻（v4 REQ-M5-03.5、§6 待決 2 的初始值）。
  double get _framingTolerance => switch (_difficulty) {
        ShutterDifficulty.tourist => 0.25,
        ShutterDifficulty.photographer => 0.18,
        ShutterDifficulty.decisiveMoment => 0.12,
      };

  Offset _targetCenter = Offset.zero;

  int get _sessionElapsedMs => _stopwatch.elapsedMilliseconds - _sessionStartMs;

  Map<ShutterTier, int> get _tally {
    final m = {for (final t in ShutterTier.values) t: 0};
    for (final s in _shots) {
      m[s.tier] = m[s.tier]! + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _controls(),
            Expanded(child: _stage()),
            _readout(),
          ],
        ),
      ),
    );
  }

  Widget _controls() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            SegmentedButton<ShutterDifficulty>(
              segments: const [
                ButtonSegment(
                  value: ShutterDifficulty.tourist,
                  label: Text('觀光客', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: ShutterDifficulty.photographer,
                  label: Text('攝影師', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: ShutterDifficulty.decisiveMoment,
                  label: Text('決定性瞬間', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {_difficulty},
              onSelectionChanged: (s) => setState(() => _difficulty = s.first),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Switch(
                      value: _spotlightMode,
                      onChanged: (v) => setState(() => _spotlightMode = v),
                    ),
                    const Text('絕景', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Switch(
                      value: _showTimeline,
                      onChanged: (v) => setState(() => _showTimeline = v),
                    ),
                    const Text('時間軸', style: TextStyle(fontSize: 12)),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _shots.clear();
                    _last = null;
                    _latency.clear();
                    _sessionStartMs = _stopwatch.elapsedMilliseconds;
                  }),
                  child: const Text('重設'),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _stage() => LayoutBuilder(
        builder: (context, box) {
          _targetCenter = Offset(box.maxWidth / 2, box.maxHeight / 2);
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _ring,
                  builder: (context, _) => CustomPaint(
                    painter: _StagePainter(
                      progress: _downStamp == null ? null : _ring.value,
                      targetRadius: _targetRadius,
                      startRadiusFactor: _startRadiusFactor,
                      matchFraction: _params.matchMs / _params.totalMs,
                      perfectFraction:
                          _params.perfectWindowMs / _params.totalMs,
                      normalFraction: _params.normalWindowMs == null
                          ? null
                          : _params.normalWindowMs! / _params.totalMs,
                      framePos: _spotlightMode ? _framePos : null,
                      framingTolerance: _framingTolerance,
                      showTimeline: _showTimeline,
                      freeze: _downStamp == null ? _last : null,
                      matchMs: _params.matchMs,
                    ),
                    size: Size.infinite,
                  ),
                ),
                if (_downStamp == null) _hint(),
              ],
            ),
          );
        },
      );

  /// 沒有提示的原型只是一塊會動的方塊 —— 玩家看不懂，就量不到手感。
  Widget _hint() => Align(
        alignment: const Alignment(0, 0.55),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _spotlightMode
                ? '按住畫面拖曳取景框對準中心，\n框線收合到與內圈重合的瞬間放開'
                : '按住畫面任何位置，\n外圈收縮到與內圈重合的瞬間放開',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
      );

  Widget _readout() {
    final t = _tally;
    final n = _shots.length;
    final v = _latency.verdict;
    final verdictText = switch (v) {
      LatencyVerdict.insufficientData =>
        '樣本不足（需 ${LatencyStats.minSamplesForVerdict}）',
      LatencyVerdict.trainable => '可練的技巧',
      LatencyVerdict.lottery => '★ 抽獎 —— 完美窗被裝置抖動主導',
    };
    final verdictColour = switch (v) {
      LatencyVerdict.insufficientData => Colors.white54,
      LatencyVerdict.trainable => Colors.greenAccent,
      LatencyVerdict.lottery => Colors.redAccent,
    };

    return Container(
      width: double.infinity,
      color: Colors.black54,
      padding: const EdgeInsets.all(10),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '參數  吻合 ${_params.matchMs}  完美窗 ${_params.perfectWindowMs}'
              '  普通窗 ${_params.normalWindowMs ?? '∞'}  全長 ${_params.totalMs} ms',
            ),
            if (_last != null)
              Text(
                '上次  ${_last!.tier.name.toUpperCase()}'
                '${_last!.timedOut ? ' (逾時)' : ''}'
                '  按住 ${_last!.heldMs} ms  偏差 ${_last!.offsetMs} ms'
                '${_last!.spotlight ? '  構圖 ${_last!.framingOk ? 'OK' : 'NG'}' : ''}',
                style: TextStyle(color: _tierColour(_last!.tier)),
              )
            else
              const Text('上次  —— 按住畫面，在環與目標吻合時放開'),
            Text(
              '累計  $n 次'
              '${n > 0 ? '  P ${t[ShutterTier.perfect]} / N ${t[ShutterTier.normal]} / F ${t[ShutterTier.failed]}' : ''}'
              '  總耗時 ${(_sessionElapsedMs / 1000).toStringAsFixed(1)} s'
              '${n > 0 ? '  每次 ${(_sessionElapsedMs / n / 1000).toStringAsFixed(1)} s' : ''}',
            ),
            Text(
              '抖動  σ ${_latency.sigma.toStringAsFixed(1)} ms'
              '  (n=${_latency.count}，上限 ${LatencyStats.jitterCeilingMs.toStringAsFixed(0)})'
              '  建議最小完美窗 ${_latency.recommendedMinWindowMs.toStringAsFixed(0)} ms',
            ),
            Text('裁決  $verdictText', style: TextStyle(color: verdictColour)),
          ],
        ),
      ),
    );
  }

  static Color _tierColour(ShutterTier t) => switch (t) {
        ShutterTier.perfect => Colors.amberAccent,
        ShutterTier.normal => Colors.lightBlueAccent,
        ShutterTier.failed => Colors.redAccent,
      };
}

class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.progress,
    required this.targetRadius,
    required this.startRadiusFactor,
    required this.matchFraction,
    required this.perfectFraction,
    required this.normalFraction,
    required this.framePos,
    required this.framingTolerance,
    required this.showTimeline,
    required this.freeze,
    required this.matchMs,
  });

  final double? progress;
  final double targetRadius;
  final double startRadiusFactor;
  final double matchFraction;
  final double perfectFraction;
  final double? normalFraction;
  final Offset? framePos;
  final double framingTolerance;
  final bool showTimeline;
  final _Shot? freeze;
  final int matchMs;

  /// 收縮半徑：progress 0 → 起始倍率，matchFraction → 恰好等於目標半徑，
  /// 1 → 0。**在吻合時刻兩圈真的重合**，這是整個動作唯一的視覺承諾。
  double _radiusAt(double t) {
    if (t <= matchFraction) {
      final k = t / matchFraction;
      return targetRadius * (startRadiusFactor - (startRadiusFactor - 1) * k);
    }
    final k = (t - matchFraction) / (1 - matchFraction);
    return targetRadius * (1 - k);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 目標圈 —— 固定不動，是「吻合」的那個對象。畫粗一點讓它是視覺主體。
    canvas.drawCircle(
      center,
      targetRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white54,
    );

    if (framePos == null) {
      // 非絕景：手指可以按在任何地方，所以收縮圈**繞著標的**畫沒有遮擋問題，
      // 而同心收縮是唯一能讓「吻合」看得出來的呈現。
      if (progress != null) {
        final r = _radiusAt(progress!);
        canvas.drawCircle(
          center,
          r.clamp(1.0, double.infinity),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white,
        );
      }
    } else {
      // 絕景：取景框跟手指，所以把收縮指示畫在**框自己的邊框**上 ——
      // 指示跟著視線走，既不被手指遮住，也不用分心看第二個地方。
      final ok = (framePos! - center).distance / targetRadius <=
          framingTolerance;
      final t = progress ?? 0;
      final scale = _radiusAt(t) / targetRadius;
      canvas.drawRect(
        Rect.fromCenter(
          center: framePos!,
          width: targetRadius * 1.5 * scale.clamp(0.02, 3.0),
          height: targetRadius * 1.1 * scale.clamp(0.02, 3.0),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = ok ? Colors.greenAccent : Colors.orangeAccent,
      );
      // 構圖容差圈：告訴玩家「框心要落在這裡面」。
      canvas.drawCircle(
        center,
        targetRadius * framingTolerance,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.greenAccent.withValues(alpha: 0.4),
      );
    }

    // 放開後凍結一瞬：把「你差了多少」畫出來，否則玩家學不到東西。
    if (freeze != null && progress == null) {
      _paintMiss(canvas, center, freeze!);
    }

    if (showTimeline) _paintTimeline(canvas, size);
  }

  /// 以半徑差呈現偏差 —— 虛線圈是你放開的那一刻收縮圈所在的位置。
  ///
  /// 放太早 → 圈還在目標外側；放太晚 → 已經縮進去了。
  void _paintMiss(Canvas canvas, Offset center, _Shot shot) {
    if (shot.timedOut) return;
    final colour = switch (shot.tier) {
      ShutterTier.perfect => Colors.amberAccent,
      ShutterTier.normal => Colors.lightBlueAccent,
      ShutterTier.failed => Colors.redAccent,
    };
    final early = shot.heldMs < matchMs;
    // 把毫秒偏差換成半徑偏差，比例與 _radiusAt 的斜率一致。
    final delta = targetRadius *
        (shot.offsetMs / matchMs) *
        (startRadiusFactor - 1);
    final r = early ? targetRadius + delta : targetRadius - delta;
    _dashedCircle(canvas, center, r.clamp(4.0, targetRadius * 2.5), colour);
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Color colour) {
    const segments = 48;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = colour;
    for (var i = 0; i < segments; i += 2) {
      final a0 = i / segments * 2 * 3.14159265;
      final a1 = (i + 1) / segments * 2 * 3.14159265;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a0,
        a1 - a0,
        false,
        paint,
      );
    }
  }

  void _paintTimeline(Canvas canvas, Size size) {
    const h = 20.0;
    final y = size.height - 32;
    final left = size.width * 0.08;
    final w = size.width * 0.84;
    Rect band(double centreFrac, double widthFrac) => Rect.fromLTWH(
          left + w * (centreFrac - widthFrac / 2),
          y,
          w * widthFrac,
          h,
        );

    canvas.drawRect(
      Rect.fromLTWH(left, y, w, h),
      Paint()..color = Colors.white10,
    );
    if (normalFraction != null) {
      canvas.drawRect(
        band(matchFraction, normalFraction!),
        Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.3),
      );
    }
    canvas.drawRect(
      band(matchFraction, perfectFraction),
      Paint()..color = Colors.amberAccent.withValues(alpha: 0.6),
    );
    if (progress != null) {
      final x = left + w * progress!;
      canvas.drawLine(
        Offset(x, y - 5),
        Offset(x, y + h + 5),
        Paint()
          ..strokeWidth = 2
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_StagePainter old) => true;
}
