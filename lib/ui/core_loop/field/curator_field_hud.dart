import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/domain/core_loop/time/tour_period.dart';
import 'package:share_tour/domain/core_loop/review/best_four_estimate.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/core_loop/game_time_controller.dart';

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

    final client = runState.client;
    final bestEstimate = bestFourSecondLayerEstimate(
      inventory.materials,
      clientType: client.type,
      difficulty: runState.shutterDifficulty,
    );
    final isHypeClient = client.type == ClientType.hypeInfluencer;

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
    final timeSnapshot = ref.watch(gameTimeProvider);
    final period = timeSnapshot.period;

    return Container(
      height: 34,
      margin: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2430),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, offset: Offset(2, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. HP 體力（移除長條量表，僅保留精簡數值，佔比極小化）
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, size: 13, color: hpColor),
              const SizedBox(width: 3),
              Text(
                '$hp/$maxHp',
                style: TextStyle(
                  color: hpColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(width: 6),

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

          const SizedBox(width: 6),

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

          const SizedBox(width: 4),

          // 4. 野外即時預估：對現有素材窮舉 C(n,4) 取該客戶第二層公式真
          // argmax（REQ-M5-11.5），不含 c 折算——顯示的是 reach／CP 本身。
          Text(
            key: const Key('field_hud_best_four_estimate'),
            isHypeClient
                ? '🎯${bestEstimate.round()}'
                : '💹${bestEstimate.round()}',
            style: const TextStyle(
              color: Color(0xFF9AE6B4),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(width: 4),

          // 5. 當前四幕時段與光照標記 (晨曦 06:00 / 午後 11:00 / 黃昏 16:00 📷 / 深夜 19:00+)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: period.hasCameraBonus
                  ? const Color(0xFF7C2D12) // 琥珀深紅背景強化相機 1.5x 加成
                  : Colors.black45,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: period.hasCameraBonus
                    ? const Color(0xFFF59E0B)
                    : Colors.white24,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(switch (period) {
                  TourPeriod.dawn => '🌅',
                  TourPeriod.midday => '☀️',
                  TourPeriod.dusk => '🌇',
                  TourPeriod.night => '🌙',
                }, style: const TextStyle(fontSize: 9)),
                const SizedBox(width: 2),
                Text(
                  period.hasCameraBonus
                      ? '${timeSnapshot.formattedTimeString} 📷'
                      : timeSnapshot.formattedTimeString,
                  style: TextStyle(
                    color: period.hasCameraBonus
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
