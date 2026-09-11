import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';

import 'compact_slot_card.dart';

/// 四幕劇時間線軌道與連動光軌組件 (TimelineRail)
class TimelineRail extends ConsumerWidget {
  const TimelineRail({super.key, this.onSlotTap});

  final void Function(int slotIndex)? onSlotTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(itineraryStatsProvider);

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 頂部連動狀態提示軌 (Synergy Rail)
            _buildSynergyRail(stats),
            const SizedBox(height: 6),

            // 4 槽位橫向軌道 (自適應彈性排版，無溢出)
            Row(
              children: [
                CompactSlotCard(
                  slotIndex: 0,
                  onTap: () => onSlotTap != null
                      ? onSlotTap!(0)
                      : _defaultSlotTap(ref, 0),
                ),
                CompactSlotCard(
                  slotIndex: 1,
                  onTap: () => onSlotTap != null
                      ? onSlotTap!(1)
                      : _defaultSlotTap(ref, 1),
                ),
                CompactSlotCard(
                  slotIndex: 2,
                  onTap: () => onSlotTap != null
                      ? onSlotTap!(2)
                      : _defaultSlotTap(ref, 2),
                ),
                CompactSlotCard(
                  slotIndex: 3,
                  onTap: () => onSlotTap != null
                      ? onSlotTap!(3)
                      : _defaultSlotTap(ref, 3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _defaultSlotTap(WidgetRef ref, int index) {
    ref
        .read(curatorRunControllerProvider.notifier)
        .removeMaterialFromSlot(index);
  }

  Widget _buildSynergyRail(dynamic stats) {
    final indicators = <Widget>[];

    // 檢查相鄰配對 (0,1), (1,2), (2,3)
    for (var i = 0; i < 3; i++) {
      final next = i + 1;
      final isCombo = stats.comboActiveSlots.contains(next);
      final isFatigue = stats.fatiguePairs.contains(i);

      if (isCombo) {
        indicators.add(
          Container(
            key: Key('combo_indicator_${i}_$next'),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.amberAccent, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link, size: 11, color: Colors.black),
                const SizedBox(width: 2),
                Text(
                  '$i-$next +20% Combo',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (isFatigue) {
        indicators.add(
          Container(
            key: Key('fatigue_warning_${i}_$next'),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.redAccent, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$i-$next 💀 拉車疲勞',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (indicators.isEmpty) {
      return const SizedBox(
        height: 16,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '四幕行程軌道 · 點擊槽位可卸下素材',
            style: TextStyle(fontSize: 9, color: Colors.white54),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: indicators),
    );
  }
}
