import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:share_tour/domain/core_loop/models/tour_time_of_day.dart';

/// 大世界動態四幕光照與環境燈火組件
///
/// 依據遊戲時段（晨曦、午後、黃昏、深夜）在世界畫布上渲染相應的環境色溫濾鏡，
/// 並在黃昏入夜時為景點地標與策展人渲染 JRPG 暖黃燈火光暈 (Lantern Halos)。
class TimeOfDayLightingComponent extends Component {
  TimeOfDayLightingComponent({
    required Vector2 mapSize,
    required this.timeOfDayGetter,
    this.playerPositionGetter,
    this.lightPositionsGetter,
    int priority = 15,
  })  : _mapSize = mapSize,
        super(priority: priority);

  Vector2 _mapSize;
  Vector2 get mapSize => _mapSize;
  final TourTimeOfDay Function() timeOfDayGetter;
  final Vector2 Function()? playerPositionGetter;
  final List<Vector2> Function()? lightPositionsGetter;
  List<Vector2>? _overrideLightPositions;

  final Paint _ambientPaint = Paint()..filterQuality = FilterQuality.none;

  void switchMap({
    required Vector2 mapSize,
    required List<Vector2> lightPositions,
  }) {
    _mapSize = mapSize;
    _overrideLightPositions = lightPositions;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final timeOfDay = timeOfDayGetter();

    // 1. 繪製全圖環境色溫濾鏡
    _ambientPaint.color = Color(timeOfDay.ambientColorArgb);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, mapSize.x, mapSize.y),
      _ambientPaint,
    );

    // 2. 在黃昏與深夜時段點亮暖黃燈籠與探險提燈
    if (timeOfDay == TourTimeOfDay.dusk || timeOfDay == TourTimeOfDay.night) {
      _renderWarmLanterns(canvas, timeOfDay);
    }
  }

  void _renderWarmLanterns(Canvas canvas, TourTimeOfDay timeOfDay) {
    final isNight = timeOfDay == TourTimeOfDay.night;

    // A. 景點街區石燈籠 / 暖簾燈火
    final positions = _overrideLightPositions ?? lightPositionsGetter?.call();
    if (positions != null && positions.isNotEmpty) {
      final double glowRadius = isNight ? 26.0 : 16.0;
      final Color glowColor =
          isNight ? const Color(0x66FBBF24) : const Color(0x3BF59E0B);

      for (final pos in positions) {
        final center = Offset(pos.x, pos.y);
        final paint = Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(
            center,
            glowRadius,
            [glowColor, Colors.transparent],
          );
        canvas.drawCircle(center, glowRadius, paint);
      }
    }

    // B. 玩家策展人冒險光環 (隨身提燈)
    final playerPos = playerPositionGetter?.call();
    if (playerPos != null) {
      final double playerRadius = isNight ? 42.0 : 28.0;
      final Color playerGlowColor =
          isNight ? const Color(0x55FEF08A) : const Color(0x2EFEF08A);

      final center = Offset(playerPos.x, playerPos.y);
      final playerPaint = Paint()
        ..blendMode = BlendMode.screen
        ..shader = ui.Gradient.radial(
          center,
          playerRadius,
          [playerGlowColor, Colors.transparent],
        );
      canvas.drawCircle(center, playerRadius, playerPaint);
    }
  }
}
