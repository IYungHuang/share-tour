import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'game_time_driver.dart';
import 'game_time_snapshot.dart';
import 'tour_period.dart';

/// 大世界漫遊真實時鐘 / 24 分鐘縮時模擬驅動器
class RealtimeGpsDriver implements GameTimeDriver {
  const RealtimeGpsDriver({
    this.nowProvider,
    this.use24MinuteTimeLapse = false,
  });

  final DateTime Function()? nowProvider;
  final bool use24MinuteTimeLapse;

  @override
  GameTimeSnapshot computeSnapshot({
    required int currentHp,
    required int maxHp,
    required int gatheredCount,
    required int waistBagCapacity,
    required CuratorRunPhase phase,
  }) {
    final now = nowProvider?.call() ?? DateTime.now();

    double virtualHour;
    if (use24MinuteTimeLapse) {
      // 24 分鐘縮時展示模式: 1 分鐘真實時間 = 1 小時遊戲時間
      final totalSeconds = now.minute * 60 + now.second;
      final cycleSeconds = totalSeconds % (24 * 60);
      virtualHour = (cycleSeconds / 60.0);
    } else {
      // 真實本地時間
      virtualHour = now.hour + (now.minute / 60.0) + (now.second / 3600.0);
    }

    // 將 00:00 ~ 24:00 映射為以 06:00 為起點的 normalizedProgress (06:00 ~ 24:00)
    // 00:00 ~ 06:00 歸入深夜 (1.0)
    double progress;
    if (virtualHour >= 6.0) {
      progress = ((virtualHour - 6.0) / 18.0).clamp(0.0, 1.0);
    } else {
      progress = 1.0;
    }

    final period = TourPeriod.fromVirtualHour(virtualHour);
    final lighting = AmbientLightingProfile.evaluate(progress);

    return GameTimeSnapshot(
      normalizedProgress: progress,
      virtualHour: virtualHour,
      period: period,
      ambientColorArgb: lighting.colorArgb,
      lanternIntensity: lighting.lanternIntensity,
    );
  }
}
