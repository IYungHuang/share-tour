import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/models/tour_time_of_day.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

/// 大世界漫步時頂部常駐的極簡 JRPG 生存指標 HUD
///
/// 顯示阿導 HP 體力條、當局預算餘額與腰包收納容量。
/// 自適應 360dp 螢幕寬度，高度 38dp，避免與大地圖和方向鍵產生視覺遮擋。
class CuratorFieldHud extends ConsumerWidget {
  const CuratorFieldHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runState = ref.watch(curatorRunControllerProvider);
    final resources = runState.resources;
    final inventory = runState.inventory;

    final hp = resources.hp;
    final maxHp = resources.maxHp;
    final hpRatio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;

    final Color hpColor = hpRatio > 0.5
        ? const Color(0xFF48BB78)
        : hpRatio > 0.2
            ? const Color(0xFFF6AD55)
            : const Color(0xFFE53E3E);

    final isDeficit = resources.isDeficit;
    final isBagFull = inventory.isFull;
    final timeOfDay = TourTimeOfDay.fromHpAndPhase(
      currentHp: hp,
      maxHp: maxHp,
      isNightEditing: runState.phase == CuratorRunPhase.nightEditing ||
          runState.phase == CuratorRunPhase.clientReview ||
          runState.phase == CuratorRunPhase.settled,
    );

    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2430),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, offset: Offset(2, 2)),
        ],
      ),
      child: Row(
        children: [
          // 1. HP 體力與血條 (Expanded 自適應)
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.favorite,
                  size: 13,
                  color: Color(0xFFFF4757),
                ),
                const SizedBox(width: 3),
                Text(
                  '$hp/$maxHp',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black87, width: 1),
                      color: Colors.black38,
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: hpRatio,
                      child: Container(color: hpColor),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 2. 預算餘額
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.monetization_on,
                size: 13,
                color: isDeficit
                    ? const Color(0xFFFC8181)
                    : const Color(0xFFECC94B),
              ),
              const SizedBox(width: 2),
              Text(
                '¥${resources.budget}',
                style: TextStyle(
                  color: isDeficit
                      ? const Color(0xFFFC8181)
                      : const Color(0xFFECC94B),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // 3. 腰包容量
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.backpack,
                size: 13,
                color: isBagFull
                    ? const Color(0xFFED8936)
                    : const Color(0xFF63B3ED),
              ),
              const SizedBox(width: 2),
              Text(
                '${inventory.count}/${inventory.capacity}',
                style: TextStyle(
                  color: isBagFull
                    ? const Color(0xFFED8936)
                    : const Color(0xFF63B3ED),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // 4. 當前四幕時段與光照標記 (晨曦 06:00 / 午後 11:00 / 黃昏 16:00 📷 / 深夜 19:00+)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: timeOfDay.hasCameraBonus
                  ? const Color(0xFF7C2D12) // 琥珀深紅背景強化相機 1.5x 加成
                  : Colors.black45,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: timeOfDay.hasCameraBonus
                    ? const Color(0xFFF59E0B)
                    : Colors.white24,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeOfDay == TourTimeOfDay.dawn
                      ? '🌅'
                      : timeOfDay == TourTimeOfDay.midday
                          ? '☀️'
                          : timeOfDay == TourTimeOfDay.dusk
                              ? '🌇'
                              : '🌙',
                  style: const TextStyle(fontSize: 9),
                ),
                const SizedBox(width: 2),
                Text(
                  timeOfDay.hasCameraBonus
                      ? '${timeOfDay.timeString} 📷'
                      : timeOfDay.timeString,
                  style: TextStyle(
                    color: timeOfDay.hasCameraBonus
                        ? const Color(0xFFFDE047)
                        : Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
