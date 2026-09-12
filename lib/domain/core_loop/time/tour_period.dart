import 'package:share_tour/domain/core_loop/models/timeline_slot.dart';

/// 旅遊策展四幕時段枚舉 (與時間線 4 槽位完美對應)
enum TourPeriod {
  dawn(
    label: '晨曦',
    timeString: '06:00',
    startHour: 6.0,
    endHour: 10.0,
    correspondingSlot: TimelineSlotType.morning,
  ),
  midday(
    label: '午後',
    timeString: '11:00',
    startHour: 10.0,
    endHour: 15.0,
    correspondingSlot: TimelineSlotType.noon,
  ),
  dusk(
    label: '黃昏',
    timeString: '16:00',
    startHour: 15.0,
    endHour: 18.5,
    correspondingSlot: TimelineSlotType.golden,
    hasCameraBonus: true,
  ),
  night(
    label: '深夜',
    timeString: '19:00+',
    startHour: 18.5,
    endHour: 24.0,
    correspondingSlot: TimelineSlotType.midnight,
  );

  const TourPeriod({
    required this.label,
    required this.timeString,
    required this.startHour,
    required this.endHour,
    required this.correspondingSlot,
    this.hasCameraBonus = false,
  });

  final String label;
  final String timeString;
  final double startHour;
  final double endHour;
  final TimelineSlotType correspondingSlot;
  final bool hasCameraBonus;

  /// 依據虛擬小時數 (0.0 ~ 24.0) 判定所屬時段
  static TourPeriod fromVirtualHour(double hour) {
    if (hour < 6.0) return TourPeriod.night; // 00:00 ~ 05:59 深夜
    if (hour < 10.0) return TourPeriod.dawn; // 06:00 ~ 09:59 晨曦
    if (hour < 15.0) return TourPeriod.midday; // 10:00 ~ 14:59 午後
    if (hour < 18.5) return TourPeriod.dusk; // 15:00 ~ 18:29 黃昏
    return TourPeriod.night; // 18:30 ~ 24:00 深夜
  }
}
