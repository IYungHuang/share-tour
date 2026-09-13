import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/time/game_time_snapshot.dart';
import 'package:share_tour/domain/core_loop/time/curator_run_progression_driver.dart';
import 'package:share_tour/domain/core_loop/time/realtime_gps_driver.dart';
import 'package:share_tour/domain/core_loop/time/tour_period.dart';

void main() {
  group('Task 1: TourPeriod 與虛擬時鐘映射測試', () {
    test('虛擬小時數正確映射至四幕時段', () {
      expect(TourPeriod.fromVirtualHour(2.0), TourPeriod.night);
      expect(TourPeriod.fromVirtualHour(5.99), TourPeriod.night);
      expect(TourPeriod.fromVirtualHour(6.0), TourPeriod.dawn);
      expect(TourPeriod.fromVirtualHour(9.99), TourPeriod.dawn);
      expect(TourPeriod.fromVirtualHour(10.0), TourPeriod.midday);
      expect(TourPeriod.fromVirtualHour(14.99), TourPeriod.midday);
      expect(TourPeriod.fromVirtualHour(15.0), TourPeriod.dusk);
      expect(TourPeriod.fromVirtualHour(18.49), TourPeriod.dusk);
      expect(TourPeriod.fromVirtualHour(18.5), TourPeriod.night);
      expect(TourPeriod.fromVirtualHour(24.0), TourPeriod.night);
    });

    test('只有黃昏 (dusk) 具備 hasCameraBonus 標記', () {
      expect(TourPeriod.dawn.hasCameraBonus, isFalse);
      expect(TourPeriod.midday.hasCameraBonus, isFalse);
      expect(TourPeriod.dusk.hasCameraBonus, isTrue);
      expect(TourPeriod.night.hasCameraBonus, isFalse);
    });
  });

  group('Task 1: AmbientLightingProfile 色溫連續漸變測試', () {
    test('錨點數值與預設值完全一致', () {
      final dawn = AmbientLightingProfile.evaluate(0.0);
      expect(dawn.colorArgb, 0x30A5C9E8);
      expect(dawn.lanternIntensity, 0.0);

      final dusk = AmbientLightingProfile.evaluate(0.60);
      expect(dusk.colorArgb, 0x55F59E0B);
      expect(dusk.lanternIntensity, closeTo(0.40, 0.001));

      final night = AmbientLightingProfile.evaluate(1.00);
      expect(night.colorArgb, 0x800B132B);
      expect(night.lanternIntensity, 1.0);
    });

    test('進度在 0.0 至 1.0 之間平滑漸變，任意相鄰 0.01 步進無色碼突變', () {
      var prevAlpha = -1;
      for (var i = 0; i <= 100; i++) {
        final t = i / 100.0;
        final res = AmbientLightingProfile.evaluate(t);
        final alpha = (res.colorArgb >> 24) & 0xFF;
        if (prevAlpha != -1) {
          // 相鄰步進 Alpha 差異不超過 10 (平滑過渡)
          expect((alpha - prevAlpha).abs(), lessThanOrEqualTo(10));
        }
        prevAlpha = alpha;
      }
    });
  });

  group('Task 1: CuratorRunProgressionDriver 策展進程推移測試', () {
    const driver = CuratorRunProgressionDriver();

    test('初始狀態 (滿體力 100/100, 0 卡) 映射至 06:00 晨曦', () {
      final snap = driver.computeSnapshot(
        currentHp: 100,
        maxHp: 100,
        gatheredCount: 0,
        waistBagCapacity: 6,
        phase: CuratorRunPhase.fieldTrip,
      );

      expect(snap.normalizedProgress, closeTo(0.0, 0.001));
      expect(snap.virtualHour, closeTo(6.0, 0.001));
      expect(snap.period, TourPeriod.dawn);
      expect(snap.formattedTimeString, '06:00');
      expect(snap.lanternIntensity, 0.0);
    });

    test('半程狀態 (50/100 HP, 3/6 卡) 平滑推進至 15:00 黃昏起點', () {
      final snap = driver.computeSnapshot(
        currentHp: 50,
        maxHp: 100,
        gatheredCount: 3,
        waistBagCapacity: 6,
        phase: CuratorRunPhase.fieldTrip,
      );

      // t = 0.70 * 0.5 + 0.30 * 0.5 = 0.50
      // virtualHour = 6.0 + 18.0 * 0.5 = 15.0
      expect(snap.normalizedProgress, closeTo(0.50, 0.001));
      expect(snap.virtualHour, closeTo(15.0, 0.001));
      expect(snap.period, TourPeriod.dusk);
      expect(snap.formattedTimeString, '15:00');
      expect(snap.period.hasCameraBonus, isTrue);
    });

    test('體力歸零或進入夜間剪輯期強制鎖定 24:00 深夜', () {
      final snapExhausted = driver.computeSnapshot(
        currentHp: 0,
        maxHp: 100,
        gatheredCount: 4,
        waistBagCapacity: 6,
        phase: CuratorRunPhase.fieldTrip,
      );
      expect(snapExhausted.normalizedProgress, 1.0);
      expect(snapExhausted.virtualHour, 24.0);
      expect(snapExhausted.period, TourPeriod.night);
      expect(snapExhausted.formattedTimeString, '24:00');
      expect(snapExhausted.lanternIntensity, 1.0);

      final snapNightEditing = driver.computeSnapshot(
        currentHp: 60,
        maxHp: 100,
        gatheredCount: 6,
        waistBagCapacity: 6,
        phase: CuratorRunPhase.nightEditing,
      );
      expect(snapNightEditing.normalizedProgress, 1.0);
      expect(snapNightEditing.period, TourPeriod.night);
    });

    test('進程單調性：隨 HP 下降與卡片收集，時間嚴格單調向前流動', () {
      var prevT = -1.0;
      for (var hp = 100; hp >= 0; hp -= 10) {
        final cards = ((100 - hp) / 100 * 6).floor();
        final snap = driver.computeSnapshot(
          currentHp: hp,
          maxHp: 100,
          gatheredCount: cards,
          waistBagCapacity: 6,
          phase: CuratorRunPhase.fieldTrip,
        );
        expect(snap.normalizedProgress, greaterThanOrEqualTo(prevT));
        prevT = snap.normalizedProgress;
      }
    });
  });

  group('Task 1: RealtimeGpsDriver 真實與縮時時鐘測試', () {
    test('依特定本地時戳精確計算虛擬時鐘與時段', () {
      final driverDawn = RealtimeGpsDriver(
        nowProvider: () => DateTime(2026, 9, 12, 7, 30), // 07:30
      );
      final snapDawn = driverDawn.computeSnapshot(
        currentHp: 100,
        maxHp: 100,
        gatheredCount: 0,
        waistBagCapacity: 6,
        phase: CuratorRunPhase.philosophizing,
      );
      expect(snapDawn.period, TourPeriod.dawn);
      expect(snapDawn.virtualHour, closeTo(7.5, 0.01));

      final driverDusk = RealtimeGpsDriver(
        nowProvider: () => DateTime(2026, 9, 12, 17, 0), // 17:00
      );
      final snapDusk = driverDusk.computeSnapshot(
        currentHp: 100,
        maxHp: 100,
        gatheredCount: 0,
        waistBagCapacity: 6,
        phase: CuratorRunPhase.philosophizing,
      );
      expect(snapDusk.period, TourPeriod.dusk);
      expect(snapDusk.period.hasCameraBonus, isTrue);

      final driverNight = RealtimeGpsDriver(
        nowProvider: () => DateTime(2026, 9, 12, 22, 0), // 22:00
      );
      final snapNight = driverNight.computeSnapshot(
        currentHp: 100,
        maxHp: 100,
        gatheredCount: 0,
        waistBagCapacity: 6,
        phase: CuratorRunPhase.philosophizing,
      );
      expect(snapNight.period, TourPeriod.night);
    });

    test('凌晨 00:00 ~ 06:00 歸入深夜 (progress = 1.0)', () {
      final driverLate = RealtimeGpsDriver(
        nowProvider: () => DateTime(2026, 9, 12, 2, 0), // 02:00
      );
      final snapLate = driverLate.computeSnapshot(
        currentHp: 100,
        maxHp: 100,
        gatheredCount: 0,
        waistBagCapacity: 6,
        phase: CuratorRunPhase.philosophizing,
      );
      expect(snapLate.period, TourPeriod.night);
      expect(snapLate.normalizedProgress, 1.0);
    });
  });
}
