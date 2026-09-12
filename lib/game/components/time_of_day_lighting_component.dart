import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:share_tour/domain/core_loop/models/tour_time_of_day.dart';
import 'package:share_tour/domain/core_loop/time/game_time_snapshot.dart';

/// 大世界動態四幕光照與環境燈火組件
///
/// 支援連續平滑插值 (Continuous Ambient Lerp) 與 0.5Hz 暖黃燈籠呼吸微動 (Lantern Breathing)，
/// 依據遊戲時間快照在世界畫布上渲染相應的環境色溫濾鏡，並在黃昏至深夜為景點石燈籠與玩家提燈渲染 JRPG 暖光。
class TimeOfDayLightingComponent extends Component {
  TimeOfDayLightingComponent({
    required Vector2 mapSize,
    this.timeSnapshotGetter,
    this.timeOfDayGetter,
    this.playerPositionGetter,
    this.lightPositionsGetter,
    int priority = 15,
  })  : assert(
          timeSnapshotGetter != null || timeOfDayGetter != null,
          'Either timeSnapshotGetter or timeOfDayGetter must be provided',
        ),
        _mapSize = mapSize,
        super(priority: priority);

  Vector2 _mapSize;
  Vector2 get mapSize => _mapSize;
  final GameTimeSnapshot Function()? timeSnapshotGetter;
  final TourTimeOfDay Function()? timeOfDayGetter;
  final Vector2 Function()? playerPositionGetter;
  final List<Vector2> Function()? lightPositionsGetter;
  List<Vector2>? _overrideLightPositions;

  double _elapsedTime = 0.0;
  double _flickerScale = 1.0;

  final Paint _ambientPaint = Paint()..filterQuality = FilterQuality.none;
  final Paint _lanternPaint = Paint()..blendMode = BlendMode.screen;
  final Paint _playerLanternPaint = Paint()..blendMode = BlendMode.screen;

  void switchMap({
    required Vector2 mapSize,
    required List<Vector2> lightPositions,
  }) {
    _mapSize = mapSize;
    _overrideLightPositions = lightPositions;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsedTime += dt;
    // 0.5Hz 溫和呼吸光效 (週期 2.0s，波動幅度 ±12%)
    _flickerScale = 1.0 + 0.12 * math.sin(_elapsedTime * math.pi);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final snapshot = timeSnapshotGetter?.call();
    Color ambientColor;
    double lanternIntensity;

    if (snapshot != null) {
      ambientColor = snapshot.ambientColor;
      lanternIntensity = snapshot.lanternIntensity;
    } else {
      final tod = timeOfDayGetter!();
      ambientColor = Color(tod.ambientColorArgb);
      lanternIntensity = (tod == TourTimeOfDay.dusk)
          ? 0.40
          : (tod == TourTimeOfDay.night ? 1.00 : 0.00);
    }

    // 1. 繪製全圖環境色溫濾鏡
    _ambientPaint.color = ambientColor;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, mapSize.x, mapSize.y),
      _ambientPaint,
    );

    // 2. 當燈籠強度 > 0 時，渲染暖黃燈火光暈 (疊加呼吸微動)
    if (lanternIntensity > 0.01) {
      _renderWarmLanterns(canvas, lanternIntensity);
    }
  }

  void _renderWarmLanterns(Canvas canvas, double lanternIntensity) {
    final double effectiveIntensity =
        (lanternIntensity * _flickerScale).clamp(0.0, 1.5);
    final isNight = lanternIntensity >= 0.70;

    // A. 景點街區石燈籠 / 暖簾燈火
    final positions = _overrideLightPositions ?? lightPositionsGetter?.call();
    if (positions != null && positions.isNotEmpty) {
      final double baseRadius = isNight ? 26.0 : 16.0;
      final double glowRadius = baseRadius * effectiveIntensity;
      final Color glowColor = isNight
          ? Color.fromRGBO(251, 191, 36, (0.40 * effectiveIntensity).clamp(0.0, 0.8))
          : Color.fromRGBO(245, 158, 11, (0.25 * effectiveIntensity).clamp(0.0, 0.6));

      for (final pos in positions) {
        final center = Offset(pos.x, pos.y);
        _lanternPaint.shader = ui.Gradient.radial(
          center,
          glowRadius,
          [glowColor, Colors.transparent],
        );
        canvas.drawCircle(center, glowRadius, _lanternPaint);
      }
    }

    // B. 玩家策展人冒險光環 (隨身提燈)
    final playerPos = playerPositionGetter?.call();
    if (playerPos != null) {
      final double baseRadius = isNight ? 42.0 : 28.0;
      final double playerRadius = baseRadius * effectiveIntensity;
      final Color playerGlowColor = isNight
          ? Color.fromRGBO(254, 240, 138, (0.35 * effectiveIntensity).clamp(0.0, 0.7))
          : Color.fromRGBO(254, 240, 138, (0.20 * effectiveIntensity).clamp(0.0, 0.5));

      final center = Offset(playerPos.x, playerPos.y);
      _playerLanternPaint.shader = ui.Gradient.radial(
        center,
        playerRadius,
        [playerGlowColor, Colors.transparent],
      );
      canvas.drawCircle(center, playerRadius, _playerLanternPaint);
    }
  }
}
