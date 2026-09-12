import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 16-Bit 復古馬賽克／蒙太奇地圖切換轉場控制器
class MosaicTransitionController extends ChangeNotifier {
  bool _isTransitioning = false;
  double _progress = 0.0;
  String _targetTitle = '';
  VoidCallback? _onMidpoint;
  VoidCallback? _onComplete;

  bool get isTransitioning => _isTransitioning;
  double get progress => _progress;
  String get targetTitle => _targetTitle;

  void triggerTransition({
    required String targetTitle,
    required VoidCallback onMidpoint,
    VoidCallback? onComplete,
  }) {
    if (_isTransitioning) return;
    _isTransitioning = true;
    _progress = 0.0;
    _targetTitle = targetTitle;
    _onMidpoint = onMidpoint;
    _onComplete = onComplete;
    notifyListeners();
  }

  void _finish() {
    _isTransitioning = false;
    _progress = 0.0;
    _onComplete?.call();
    notifyListeners();
  }
}

/// 16-Bit 復古馬賽克蒙太奇轉場覆蓋層 (JRPG Screen Wipe)
class MosaicTransitionOverlay extends StatefulWidget {
  const MosaicTransitionOverlay({
    super.key,
    required this.controller,
  });

  final MosaicTransitionController controller;

  @override
  State<MosaicTransitionOverlay> createState() =>
      _MosaicTransitionOverlayState();
}

class _MosaicTransitionOverlayState extends State<MosaicTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  bool _midpointCalled = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        if (_anim.value >= 0.5 && !_midpointCalled) {
          _midpointCalled = true;
          widget.controller._onMidpoint?.call();
        }
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.controller._finish();
        }
      });

    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (widget.controller.isTransitioning && !_anim.isAnimating) {
      _midpointCalled = false;
      _anim.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_anim, widget.controller]),
      builder: (context, _) {
        if (!widget.controller.isTransitioning) {
          return const SizedBox.shrink();
        }

        // 計算轉場強度：0.0 -> 0.5 漸密，0.5 -> 1.0 漸散
        final t = _anim.value;
        final intensity = t < 0.5 ? (t / 0.5) : ((1.0 - t) / 0.5);

        return SizedBox.expand(
          child: IgnorePointer(
            ignoring: false, // 轉場期間阻擋玩家操作底層
            child: CustomPaint(
              painter: _MosaicPainter(
                intensity: intensity,
                progress: t,
              ),
              child: intensity > 0.45
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          border: Border.all(
                            color: const Color(0xFFF59E0B),
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(4, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '⛩️ ',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              widget.controller.targetTitle,
                              style: const TextStyle(
                                color: Color(0xFFFCD34D),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class _MosaicPainter extends CustomPainter {
  const _MosaicPainter({
    required this.intensity,
    required this.progress,
  });

  final double intensity;
  final double progress;

  static const List<Color> _palette = [
    Color(0xFF0F172A), // 深夜靛青
    Color(0xFF1E293B), // 町家深灰
    Color(0xFF2D1E12), // 木造板色
    Color(0xFF831843), // 緋紅暮色
    Color(0xFFB45309), // 暖簾古銅
    Color(0xFFF59E0B), // 金黃燈火
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0.01) return;

    // 1. 半透明暗化底色
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: (intensity * 0.85).clamp(0.0, 0.95));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. 16-Bit 粗顆粒馬賽克格柵 (顆粒隨 intensity 從 8px 膨脹至 40px)
    final blockSize = 8.0 + intensity * 32.0;
    final cols = (size.width / blockSize).ceil();
    final rows = (size.height / blockSize).ceil();

    final blockPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: intensity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // 偽隨機散布與階段消融判定
        final hash = (math.sin(r * 12.9898 + c * 78.233) * 43758.5453).abs() % 1.0;
        if (hash > intensity * 1.25) continue;

        final colorIndex = ((r + c + (hash * 10).toInt()) % _palette.length);
        blockPaint.color = _palette[colorIndex].withValues(
          alpha: (intensity * 0.9).clamp(0.0, 1.0),
        );

        final rect = Rect.fromLTWH(
          c * blockSize,
          r * blockSize,
          blockSize,
          blockSize,
        );
        canvas.drawRect(rect, blockPaint);
        canvas.drawRect(rect, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MosaicPainter oldDelegate) {
    return oldDelegate.intensity != intensity || oldDelegate.progress != progress;
  }
}
