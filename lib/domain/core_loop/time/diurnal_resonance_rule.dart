import 'dart:math';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'tour_period.dart';

/// 時段順行採集體力共鳴規則 (純領域規則)
class DiurnalResonanceRule {
  /// 時段與契合標籤對照表
  static const Map<TourPeriod, Set<String>> preferredTagsByPeriod = {
    TourPeriod.dawn: {'#散步', '#早市', '#寺院', '#自然'},
    TourPeriod.midday: {'#名店', '#大眾名店', '#咖啡', '#文化', '#街區'},
    TourPeriod.dusk: {'#絕景', '#展望', '#古道', '#夕照'},
    TourPeriod.night: {'#深夜', '#居酒屋', '#夜櫻', '#酒吧', '#小酌'},
  };

  /// 契合時段標準體力減免值 (HP)
  static const int resonanceDiscountHp = 3;

  /// 最低體力消耗底線 (保證單次取材至少扣 1 HP，杜絕免費採集)
  static const int minHpCostFloor = 1;

  /// 檢查素材是否與當前時段產生共鳴
  static bool hasResonance({
    required TourPeriod currentPeriod,
    required TravelMaterial material,
  }) {
    final preferred = preferredTagsByPeriod[currentPeriod] ?? {};
    return material.tags.any(preferred.contains);
  }

  /// 計算時段體力折讓值 (有共鳴回傳 3，無共鳴回傳 0)
  static int calculateDiscount({
    required TourPeriod currentPeriod,
    required TravelMaterial material,
  }) {
    return hasResonance(currentPeriod: currentPeriod, material: material)
        ? resonanceDiscountHp
        : 0;
  }

  /// 計算折讓後的實際體力消耗
  static int calculateActualCost({
    required int baseHpCost,
    required TourPeriod currentPeriod,
    required TravelMaterial material,
  }) {
    final discount = calculateDiscount(
      currentPeriod: currentPeriod,
      material: material,
    );
    return max(minHpCostFloor, baseHpCost - discount);
  }
}
