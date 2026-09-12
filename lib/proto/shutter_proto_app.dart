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
                    const Text('絕景（取景框跟手指）', style: TextStyle(fontSize: 12)),
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
            child: AnimatedBuilder(
              animation: _ring,
              builder: (context, _) => CustomPaint(
                painter: _StagePainter(
                  progress: _ring.isAnimating || _downStamp != null
                      ? _ring.value
                      : null,
                  targetRadius: _targetRadius,
                  startRadiusFactor: _startRadiusFactor,
                  matchFraction: _params.matchMs / _params.totalMs,
                  perfectFraction: _params.perfectWindowMs / _params.totalMs,
                  normalFraction: _params.normalWindowMs == null
                      ? null
                      : _params.normalWindowMs! / _params.totalMs,
                  framePos: _spotlightMode ? _framePos : null,
                  framingTolerance: _framingTolerance,
                  lastTier: _last?.tier,
                ),
                size: Size.infinite,
              ),
            ),
          );
        },
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
    required this.lastTier,
  });

  final double? progress;
  final double targetRadius;
  final double startRadiusFactor;
  final double matchFraction;
  final double perfectFraction;
  final double? normalFraction;
  final Offset? framePos;
  final double framingTolerance;
  final ShutterTier? lastTier;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 目標圈（標的）
    canvas.drawCircle(
      center,
      targetRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white38,
    );

    // 收縮帶的時間軸 —— 畫在畫面下緣，刻意**不繞標的**：
    // 取景框跟隨手指時，手指會壓在標的上，環若繞著標的就被遮住
    // （v4 REQ-M5-03.3）。
    _paintTimeline(canvas, size);

    // 收縮框（表現層，判定不看它）
    if (progress != null) {
      final r = targetRadius *
          (startRadiusFactor - (startRadiusFactor - 0) * progress!);
      canvas.drawRect(
        Rect.fromCircle(center: center, radius: r.clamp(2.0, double.infinity)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white,
      );
    }

    // 絕景的取景框
    if (framePos != null) {
      final ok = (framePos! - center).distance / targetRadius <= framingTolerance;
      canvas.drawRect(
        Rect.fromCenter(
          center: framePos!,
          width: targetRadius * 1.5,
          height: targetRadius * 1.1,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ok ? Colors.greenAccent : Colors.orangeAccent,
      );
      canvas.drawCircle(
        center,
        targetRadius * framingTolerance,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.greenAccent.withValues(alpha: 0.38),
      );
    }
  }

  void _paintTimeline(Canvas canvas, Size size) {
    const h = 26.0;
    final y = size.height - 40;
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
        Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.35),
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(left, y, w, h),
        Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.25),
      );
    }
    canvas.drawRect(
      band(matchFraction, perfectFraction),
      Paint()..color = Colors.amberAccent.withValues(alpha: 0.7),
    );
    if (progress != null) {
      final x = left + w * progress!;
      canvas.drawLine(
        Offset(x, y - 6),
        Offset(x, y + h + 6),
        Paint()
          ..strokeWidth = 3
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_StagePainter old) => true;
}
