import 'package:flutter/material.dart';
import 'tour_period.dart';

/// 日夜環境色溫平滑插值引擎
class AmbientLightingProfile {
  // 5 個關鍵錨點與其 ARGB 色值
  // t=0.00 -> 06:00 晨曦: 0x30A5C9E8 (冷青薄霧)
  // t=0.30 -> 11:24 午後: 0x05FFFDE8 (透亮暖白)
  // t=0.60 -> 16:48 黃昏: 0x55F59E0B (琥珀金橙)
  // t=0.75 -> 19:30 薄暮: 0x659333EA (逢魔紫金)
  // t=1.00 -> 24:00 深夜: 0x800B132B (黛藍深邃)

  static const List<({double t, Color color, double lantern})> _anchors = [
    (t: 0.00, color: Color(0x30A5C9E8), lantern: 0.0),
    (t: 0.30, color: Color(0x05FFFDE8), lantern: 0.0),
    (t: 0.60, color: Color(0x55F59E0B), lantern: 0.40),
    (t: 0.75, color: Color(0x659333EA), lantern: 0.85),
    (t: 1.00, color: Color(0x800B132B), lantern: 1.00),
  ];

  /// 依 normalized progress (0.0 ~ 1.0) 計算平滑插值後的色溫與燈籠輝光
  static ({Color color, double lanternIntensity}) evaluate(double progress) {
    final p = progress.clamp(0.0, 1.0);
    for (var i = 0; i < _anchors.length - 1; i++) {
      final a0 = _anchors[i];
      final a1 = _anchors[i + 1];
      if (p >= a0.t && p <= a1.t) {
        final span = a1.t - a0.t;
        final localRatio = span > 0 ? (p - a0.t) / span : 0.0;
        final color = Color.lerp(a0.color, a1.color, localRatio)!;
        final lantern = a0.lantern + (a1.lantern - a0.lantern) * localRatio;
        return (color: color, lanternIntensity: lantern);
      }
    }
    return (color: _anchors.last.color, lanternIntensity: _anchors.last.lantern);
  }
}

/// 遊戲時間核心數值快照 (不可變領域實體)
class GameTimeSnapshot {
  const GameTimeSnapshot({
    required this.normalizedProgress,
    required this.virtualHour,
    required this.period,
    required this.ambientColor,
    required this.lanternIntensity,
  });

  /// 進度純量 0.0 (06:00 晨曦) ~ 1.0 (24:00 深夜)
  final double normalizedProgress;

  /// 虛擬時鐘小時 6.0 ~ 24.0
  final double virtualHour;

  /// 當前四幕時段
  final TourPeriod period;

  /// 平滑插值環境濾鏡色
  final Color ambientColor;

  /// 景點燈籠輝光強度 (0.0 ~ 1.0)
  final double lanternIntensity;

  /// 格式化虛擬時刻字串 (例如 "06:00", "16:48")
  String get formattedTimeString {
    final h = virtualHour.floor();
    final m = ((virtualHour - h) * 60).round().clamp(0, 59);
    final hStr = h.toString().padLeft(2, '0');
    final mStr = m.toString().padLeft(2, '0');
    return '$hStr:$mStr';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameTimeSnapshot &&
          runtimeType == other.runtimeType &&
          normalizedProgress == other.normalizedProgress &&
          virtualHour == other.virtualHour &&
          period == other.period &&
          ambientColor == other.ambientColor &&
          lanternIntensity == other.lanternIntensity;

  @override
  int get hashCode => Object.hash(
        normalizedProgress,
        virtualHour,
        period,
        ambientColor,
        lanternIntensity,
      );

  @override
  String toString() =>
      'GameTimeSnapshot(progress: ${normalizedProgress.toStringAsFixed(2)}, time: $formattedTimeString, period: ${period.label})';
}
