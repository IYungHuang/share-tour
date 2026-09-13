import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'game_time_driver.dart';
import 'game_time_snapshot.dart';
import 'tour_period.dart';

/// 策展局內進程時鐘驅動器 (HP消耗 70% + 採集進度 30% 綜合平滑驅動)
class CuratorRunProgressionDriver implements GameTimeDriver {
  const CuratorRunProgressionDriver();

  @override
  GameTimeSnapshot computeSnapshot({
    required int currentHp,
    required int maxHp,
    required int gatheredCount,
    required int waistBagCapacity,
    required CuratorRunPhase phase,
  }) {
    // 若處於夜間剪輯、客戶審查或結算階段，鎖定深夜 24:00 (1.0)
    if (phase == CuratorRunPhase.nightEditing ||
        phase == CuratorRunPhase.clientReview ||
        phase == CuratorRunPhase.settled ||
        currentHp <= 0) {
      final lighting = AmbientLightingProfile.evaluate(1.0);
      return GameTimeSnapshot(
        normalizedProgress: 1.0,
        virtualHour: 24.0,
        period: TourPeriod.night,
        ambientColorArgb: lighting.colorArgb,
        lanternIntensity: lighting.lanternIntensity,
      );
    }

    final hpLossRatio = maxHp > 0
        ? ((maxHp - currentHp) / maxHp).clamp(0.0, 1.0)
        : 0.0;

    final bagFillRatio = waistBagCapacity > 0
        ? (gatheredCount / waistBagCapacity).clamp(0.0, 1.0)
        : 0.0;

    // 平滑加權公式: 70% 體力消耗 + 30% 採集進度
    final t = (0.70 * hpLossRatio + 0.30 * bagFillRatio).clamp(0.0, 1.0);
    final virtualHour = 6.0 + 18.0 * t;
    final period = TourPeriod.fromVirtualHour(virtualHour);
    final lighting = AmbientLightingProfile.evaluate(t);

    return GameTimeSnapshot(
      normalizedProgress: t,
      virtualHour: virtualHour,
      period: period,
      ambientColorArgb: lighting.colorArgb,
      lanternIntensity: lighting.lanternIntensity,
    );
  }
}
