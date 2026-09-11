import 'travel_material.dart';

/// 4 大時間線槽位語義定義
enum TimelineSlotType {
  morning(timeLabel: '08:00', name: '晨曦啟程'),
  noon(timeLabel: '12:00', name: '午後漫遊'),
  golden(timeLabel: '17:00', name: '黃昏高潮'),
  midnight(timeLabel: '22:00', name: '深夜餘韻');

  const TimelineSlotType({required this.timeLabel, required this.name});

  final String timeLabel;
  final String name;

  /// 計算該槽位放入特定素材時所觸發的專屬加成 Theme
  int evaluateSlotBonus(TravelMaterial material) {
    switch (this) {
      case TimelineSlotType.morning:
        // Slot 0: 條件需同時滿足 low risk 且帶有 #散步 或 #早餐
        final isLowRisk = material.riskLevel <= 2;
        final hasMorningTag = material.hasTag('#散步') || material.hasTag('#早餐');
        return (isLowRisk && hasMorningTag) ? 5 : 0;

      case TimelineSlotType.noon:
        // Slot 1: 條件需滿足 low risk 且帶有 #美食 或 #老街 或 #銅板美食
        final isLowRisk = material.riskLevel <= 2;
        final hasNoonTag =
            material.hasTag('#美食') ||
            material.hasTag('#老街') ||
            material.hasTag('#銅板美食');
        return (isLowRisk && hasNoonTag) ? 5 : 0;

      case TimelineSlotType.golden:
        // Slot 2: 為 Hype 亮點倍率槽位，不直接提供固定 Theme 加分
        return 0;

      case TimelineSlotType.midnight:
        // Slot 3: 滿足 high risk (>=3) 或帶有 #深夜, #小酌 標籤，獎勵 +5 Theme (上限 +5)
        final isHighRisk = material.riskLevel >= 3;
        final hasNightTag = material.hasTag('#深夜') || material.hasTag('#小酌');
        return (isHighRisk || hasNightTag) ? 5 : 0;
    }
  }
}
