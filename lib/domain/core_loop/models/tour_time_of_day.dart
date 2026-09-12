import 'timeline_slot.dart';

/// 旅遊策展四幕時間與光照時段領域模型
enum TourTimeOfDay {
  /// 06:00 晨曦 (100% ~ 76% HP)
  dawn(
    label: '晨曦',
    timeString: '06:00',
    description: '冷調朝陽與薄霧',
    ambientColorArgb: 0x26BBE1FA, // 冷調淡青薄霧濾鏡
    correspondingSlot: TimelineSlotType.morning,
  ),

  /// 11:00 午後 (75% ~ 51% HP)
  midday(
    label: '午後',
    timeString: '11:00',
    description: '明亮通透全日照',
    ambientColorArgb: 0x08FFFBEB, // 清朗微金暖光
    correspondingSlot: TimelineSlotType.noon,
  ),

  /// 16:00 黃昏 (50% ~ 26% HP, 📷 相機 1.5x 黃金時刻)
  dusk(
    label: '黃昏',
    timeString: '16:00',
    description: '魔幻琥珀黃金時刻',
    ambientColorArgb: 0x4DF59E0B, // 琥珀金橙斜陽
    correspondingSlot: TimelineSlotType.golden,
    hasCameraBonus: true,
  ),

  /// 19:00+ 深夜 (25% ~ 0% HP 或進入編排期)
  night(
    label: '深夜',
    timeString: '19:00+',
    description: '沉浸暗夜與暖黃燈火',
    ambientColorArgb: 0x730A0F1D, // 深藍暗夜
    correspondingSlot: TimelineSlotType.midnight,
  );

  const TourTimeOfDay({
    required this.label,
    required this.timeString,
    required this.description,
    required this.ambientColorArgb,
    required this.correspondingSlot,
    this.hasCameraBonus = false,
  });

  final String label;
  final String timeString;
  final String description;
  final int ambientColorArgb;
  final TimelineSlotType correspondingSlot;
  final bool hasCameraBonus;

  /// 依當前 HP 與階段狀態決定對應時段
  static TourTimeOfDay fromHpAndPhase({
    required int currentHp,
    required int maxHp,
    bool isNightEditing = false,
  }) {
    if (isNightEditing || currentHp <= 0) {
      return TourTimeOfDay.night;
    }
    final ratio = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
    if (ratio > 0.75) {
      return TourTimeOfDay.dawn;
    } else if (ratio > 0.50) {
      return TourTimeOfDay.midday;
    } else if (ratio > 0.25) {
      return TourTimeOfDay.dusk;
    } else {
      return TourTimeOfDay.night;
    }
  }
}
