import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/timeline_slot.dart';
import 'package:share_tour/domain/core_loop/models/tour_time_of_day.dart';

void main() {
  group('TourTimeOfDay 領域模型與四幕時間演化測試', () {
    test('HP 區間對應四幕時段正確', () {
      // 晨曦 100 ~ 76 HP
      expect(
        TourTimeOfDay.fromHpAndPhase(currentHp: 100, maxHp: 100),
        equals(TourTimeOfDay.dawn),
      );
      expect(
        TourTimeOfDay.fromHpAndPhase(currentHp: 76, maxHp: 100),
        equals(TourTimeOfDay.dawn),
      );

      // 午後 75 ~ 51 HP
      expect(
        TourTimeOfDay.fromHpAndPhase(currentHp: 75, maxHp: 100),
        equals(TourTimeOfDay.midday),
      );
      expect(
        TourTimeOfDay.fromHpAndPhase(currentHp: 51, maxHp: 100),
        equals(TourTimeOfDay.midday),
      );

      // 黃昏 50 ~ 26 HP (📷 相機 1.5x 加成時刻)
      expect(
        TourTimeOfDay.fromHpAndPhase(currentHp: 50, maxHp: 100),
        equals(TourTimeOfDay.dusk),
      );
      expect(
        TourTimeOfDay.fromHpAndPhase(currentHp: 26, maxHp: 100),
        equals(TourTimeOfDay.dusk),
      );
      expect(TourTimeOfDay.dusk.hasCameraBonus, isTrue);

      // 深夜 25 ~ 0 HP
      expect(
        TourTimeOfDay.fromHpAndPhase(currentHp: 25, maxHp: 100),
        equals(TourTimeOfDay.night),
      );
      expect(
        TourTimeOfDay.fromHpAndPhase(currentHp: 0, maxHp: 100),
        equals(TourTimeOfDay.night),
      );
    });

    test('nightEditing 階段強制進入深夜', () {
      expect(
        TourTimeOfDay.fromHpAndPhase(
          currentHp: 100,
          maxHp: 100,
          isNightEditing: true,
        ),
        equals(TourTimeOfDay.night),
      );
    });

    test('四幕時段與四個時間線槽位 (TimelineSlotType) 映射一致', () {
      expect(TourTimeOfDay.dawn.correspondingSlot, equals(TimelineSlotType.morning));
      expect(TourTimeOfDay.midday.correspondingSlot, equals(TimelineSlotType.noon));
      expect(TourTimeOfDay.dusk.correspondingSlot, equals(TimelineSlotType.golden));
      expect(TourTimeOfDay.night.correspondingSlot, equals(TimelineSlotType.midnight));
    });
  });
}
